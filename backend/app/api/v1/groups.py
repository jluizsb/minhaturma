from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel

from app.core.database import get_db

router = APIRouter()


class CreateGroupRequest(BaseModel):
    name: str
    description: str | None = None


@router.post("/", status_code=201)
async def create_group(data: CreateGroupRequest, db: AsyncSession = Depends(get_db)):
    # TODO: criar grupo, gerar invite_code único, adicionar criador como admin
    return {"message": "Grupo criado"}


@router.get("/{group_id}")
async def get_group(group_id: str, db: AsyncSession = Depends(get_db)):
    # TODO: retornar grupo com membros
    return {"group_id": group_id}


@router.post("/join/{invite_code}")
async def join_group(invite_code: str, db: AsyncSession = Depends(get_db)):
    # TODO: adicionar usuário autenticado ao grupo pelo código de convite
    return {"message": "Entrou no grupo"}


@router.delete("/{group_id}/members/{user_id}")
async def remove_member(group_id: str, user_id: str, db: AsyncSession = Depends(get_db)):
    # TODO: remover membro (apenas admin pode)
    return {"message": "Membro removido"}
