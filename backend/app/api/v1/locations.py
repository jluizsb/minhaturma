from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from typing import List
from datetime import datetime

from app.core.database import get_db

router = APIRouter()

# Gerenciador de conexões WebSocket por grupo
class ConnectionManager:
    def __init__(self):
        self.active: dict[str, list[WebSocket]] = {}

    async def connect(self, group_id: str, ws: WebSocket):
        await ws.accept()
        self.active.setdefault(group_id, []).append(ws)

    def disconnect(self, group_id: str, ws: WebSocket):
        self.active.get(group_id, []).remove(ws)

    async def broadcast(self, group_id: str, data: dict):
        for ws in self.active.get(group_id, []):
            await ws.send_json(data)

manager = ConnectionManager()


class LocationUpdate(BaseModel):
    latitude:  float
    longitude: float
    accuracy:  float | None = None
    speed:     float | None = None
    heading:   float | None = None


@router.websocket("/ws/{group_id}/{user_id}")
async def location_ws(group_id: str, user_id: str, ws: WebSocket):
    """WebSocket de localização em tempo real por grupo."""
    await manager.connect(group_id, ws)
    try:
        while True:
            data = await ws.receive_json()
            payload = {
                "user_id": user_id,
                "latitude":  data["latitude"],
                "longitude": data["longitude"],
                "timestamp": datetime.utcnow().isoformat(),
            }
            # TODO: salvar no banco (Location model)
            # TODO: verificar geofences e disparar alertas
            await manager.broadcast(group_id, payload)
    except WebSocketDisconnect:
        manager.disconnect(group_id, ws)


@router.get("/history/{user_id}")
async def get_location_history(user_id: str, days: int = 1, db: AsyncSession = Depends(get_db)):
    """Histórico de localização dos últimos N dias."""
    # TODO: buscar do banco filtrado por user_id e data
    return {"user_id": user_id, "history": []}


@router.get("/group/{group_id}/last")
async def get_group_last_locations(group_id: str, db: AsyncSession = Depends(get_db)):
    """Última localização de cada membro do grupo."""
    # TODO: buscar última localização de cada membro
    return {"group_id": group_id, "members": []}
