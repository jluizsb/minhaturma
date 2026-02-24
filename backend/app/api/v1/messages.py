from fastapi import APIRouter, Depends, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel

from app.core.database import get_db

router = APIRouter()


class SendMessageRequest(BaseModel):
    group_id:  str
    sender_id: str
    content:   str
    type:      str = "text"  # text | image | video


@router.post("/")
async def send_message(data: SendMessageRequest, db: AsyncSession = Depends(get_db)):
    # TODO: salvar mensagem no banco e fazer broadcast via WebSocket
    return {"message": "Mensagem enviada"}


@router.post("/upload")
async def upload_media(group_id: str, file: UploadFile = File(...)):
    """
    Upload de foto ou vídeo para o S3.
    Retorna a URL pública para uso na mensagem.
    """
    # TODO: validar tipo e tamanho (MAX 50MB)
    # TODO: fazer upload para AWS S3 com chave: grupos/{group_id}/{uuid}.{ext}
    # TODO: retornar URL pré-assinada ou URL pública do S3
    return {"url": "https://s3.amazonaws.com/bucket/placeholder.jpg"}


@router.get("/{group_id}")
async def get_messages(group_id: str, page: int = 1, limit: int = 50, db: AsyncSession = Depends(get_db)):
    # TODO: buscar mensagens paginadas do grupo
    return {"group_id": group_id, "messages": [], "page": page}
