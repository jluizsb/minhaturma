import json
import math
import uuid
from datetime import datetime, UTC

from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user
from app.core.database import get_db
from app.core.redis_client import get_redis
from app.core.security import decode_token
from app.models.group import GroupMember
from app.models.location import Location
from app.models.user import User

router = APIRouter()


# ── Haversine ────────────────────────────────────────────────────────────────

def haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Distância em metros entre dois pontos geográficos (fórmula de Haversine)."""
    R = 6371000.0  # raio da Terra em metros
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


# ── WebSocket Manager ────────────────────────────────────────────────────────

class ConnectionManager:
    def __init__(self):
        self.active: dict[str, list[WebSocket]] = {}

    async def connect(self, group_id: str, ws: WebSocket):
        await ws.accept()
        self.active.setdefault(group_id, []).append(ws)

    def disconnect(self, group_id: str, ws: WebSocket):
        connections = self.active.get(group_id, [])
        if ws in connections:
            connections.remove(ws)

    async def broadcast(self, group_id: str, data: dict):
        dead = []
        for ws in self.active.get(group_id, []):
            try:
                await ws.send_json(data)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(group_id, ws)


manager = ConnectionManager()


# ── WebSocket de localização ─────────────────────────────────────────────────

@router.websocket("/ws")
async def location_ws(
    ws: WebSocket,
    token: str = Query(...),
    group_id: str = Query(...),
    db: AsyncSession = Depends(get_db),
):
    """
    WebSocket de localização em tempo real.
    Auth via query param: ?token=<access_token>&group_id=<uuid>
    Payload recebido: {"lat": float, "lng": float, "ts": float (epoch seconds)}
    Payload broadcast: {"type": "location_update", "user_id": str, "user_name": str,
                        "lat": float, "lng": float, "ts": float}
    """
    # Autenticar via token no query param
    try:
        payload = decode_token(token)
    except HTTPException:
        await ws.close(code=4001)
        return

    user_id_str = payload.get("sub")
    if not user_id_str:
        await ws.close(code=4001)
        return

    # Verificar usuário
    try:
        uid = uuid.UUID(user_id_str)
    except ValueError:
        await ws.close(code=4001)
        return

    result = await db.execute(select(User).where(User.id == uid))
    user = result.scalar_one_or_none()
    if user is None or not user.is_active:
        await ws.close(code=4001)
        return

    # Verificar membership no grupo
    try:
        gid = uuid.UUID(group_id)
    except ValueError:
        await ws.close(code=4003)
        return

    result = await db.execute(
        select(GroupMember).where(
            GroupMember.group_id == gid,
            GroupMember.user_id == user.id,
        )
    )
    if result.scalar_one_or_none() is None:
        await ws.close(code=4003)
        return

    await manager.connect(group_id, ws)
    redis = await get_redis()

    try:
        while True:
            data = await ws.receive_json()
            lat = float(data["lat"])
            lng = float(data["lng"])
            now = datetime.now(UTC).replace(tzinfo=None)

            # Throttle: persiste se moveu ≥ 10m ou Δt ≥ 30s
            redis_key = f"loc:last:{user_id_str}"
            last_raw = await redis.get(redis_key)
            should_persist = True

            if last_raw:
                last = json.loads(last_raw)
                dist = haversine(last["lat"], last["lng"], lat, lng)
                dt = now.timestamp() - last.get("ts", 0)
                should_persist = dist >= 10 or dt >= 30

            if should_persist:
                location = Location(
                    user_id=user.id,
                    latitude=lat,
                    longitude=lng,
                    recorded_at=now,
                )
                db.add(location)
                await db.flush()

            # Atualiza Redis com posição atual (sempre)
            loc_data = {
                "user_id": user_id_str,
                "user_name": user.name,
                "lat": lat,
                "lng": lng,
                "ts": now.timestamp(),
            }
            await redis.set(redis_key, json.dumps(loc_data), ex=3600)

            # Broadcast para o grupo
            await manager.broadcast(group_id, {"type": "location_update", **loc_data})

    except WebSocketDisconnect:
        manager.disconnect(group_id, ws)
    except Exception:
        manager.disconnect(group_id, ws)


# ── REST endpoints ───────────────────────────────────────────────────────────

@router.get("/history/{user_id}")
async def get_location_history(
    user_id: str,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Histórico de localização de um usuário (últimos N registros)."""
    try:
        uid = uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="ID de usuário inválido")

    result = await db.execute(
        select(Location)
        .where(Location.user_id == uid)
        .order_by(desc(Location.recorded_at))
        .limit(limit)
    )
    locations = result.scalars().all()
    return [
        {
            "lat": loc.latitude,
            "lng": loc.longitude,
            "ts": loc.recorded_at.timestamp() if loc.recorded_at else None,
        }
        for loc in locations
    ]


@router.get("/group/{group_id}/last")
async def get_group_last_locations(
    group_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Última posição de cada membro do grupo (via Redis)."""
    try:
        gid = uuid.UUID(group_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="ID de grupo inválido")

    result = await db.execute(
        select(GroupMember).where(GroupMember.group_id == gid)
    )
    members = result.scalars().all()

    redis = await get_redis()
    positions = []
    for member in members:
        raw = await redis.get(f"loc:last:{member.user_id}")
        if raw:
            positions.append(json.loads(raw))

    return {"group_id": group_id, "members": positions}
