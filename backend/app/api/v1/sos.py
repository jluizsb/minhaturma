from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel

from app.core.database import get_db

router = APIRouter()


class SOSRequest(BaseModel):
    user_id:   str
    group_id:  str
    latitude:  float
    longitude: float
    message:   str | None = None


@router.post("/trigger")
async def trigger_sos(data: SOSRequest, db: AsyncSession = Depends(get_db)):
    """
    Aciona o SOS:
    1. Salva evento no banco
    2. Envia push notification a todos do grupo via Firebase FCM
    3. Transmite pelo WebSocket de localização
    """
    # TODO: salvar SOSEvent no banco
    # TODO: buscar tokens FCM dos membros do grupo
    # TODO: enviar push via Firebase Admin SDK
    # TODO: broadcast via WebSocket
    return {"status": "SOS acionado", "notified": 0}


@router.post("/resolve/{sos_id}")
async def resolve_sos(sos_id: str, db: AsyncSession = Depends(get_db)):
    """Marca o evento SOS como resolvido."""
    # TODO: atualizar campo resolved no banco
    return {"status": "SOS resolvido"}


@router.get("/history/{group_id}")
async def get_sos_history(group_id: str, db: AsyncSession = Depends(get_db)):
    """Histórico de eventos SOS do grupo."""
    return {"group_id": group_id, "events": []}
