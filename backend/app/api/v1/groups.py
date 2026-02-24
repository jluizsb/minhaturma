import secrets
import uuid
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.dependencies import get_current_user
from app.core.database import get_db
from app.models.group import Group, GroupMember, GroupRole
from app.models.user import User

router = APIRouter()


# ── Schemas ──────────────────────────────────────────────────────────────────

class GroupCreate(BaseModel):
    name: str
    description: str | None = None


class GroupMemberOut(BaseModel):
    user_id: str
    name: str
    role: str


class GroupOut(BaseModel):
    id: str
    name: str
    description: str | None
    invite_code: str
    member_count: int
    members: List[GroupMemberOut]


class JoinGroupRequest(BaseModel):
    invite_code: str


# ── Helper ───────────────────────────────────────────────────────────────────

def _generate_invite_code() -> str:
    """Gera código de convite de 8 caracteres alfanumérico maiúsculo."""
    return secrets.token_urlsafe(6).upper()[:8]


def _group_to_out(group: Group) -> dict:
    members = [
        {
            "user_id": str(gm.user_id),
            "name": gm.user.name if gm.user else "",
            "role": gm.role.value,
        }
        for gm in group.members
    ]
    return {
        "id": str(group.id),
        "name": group.name,
        "description": group.description,
        "invite_code": group.invite_code,
        "member_count": len(group.members),
        "members": members,
    }


# ── Endpoints ────────────────────────────────────────────────────────────────

@router.post("/", status_code=201)
async def create_group(
    data: GroupCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Criar um grupo; o criador vira admin automaticamente."""
    # Gera código único
    invite_code = _generate_invite_code()
    while True:
        result = await db.execute(
            select(Group).where(Group.invite_code == invite_code)
        )
        if result.scalar_one_or_none() is None:
            break
        invite_code = _generate_invite_code()

    group = Group(
        name=data.name,
        description=data.description,
        invite_code=invite_code,
    )
    db.add(group)
    await db.flush()

    member = GroupMember(
        group_id=group.id,
        user_id=current_user.id,
        role=GroupRole.admin,
    )
    db.add(member)
    await db.flush()

    result = await db.execute(
        select(Group)
        .where(Group.id == group.id)
        .options(selectinload(Group.members).selectinload(GroupMember.user))
    )
    group = result.scalar_one()
    return _group_to_out(group)


@router.get("/", status_code=200)
async def list_groups(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Listar grupos do usuário autenticado."""
    result = await db.execute(
        select(Group)
        .join(GroupMember, GroupMember.group_id == Group.id)
        .where(GroupMember.user_id == current_user.id, Group.is_active == True)
        .options(selectinload(Group.members).selectinload(GroupMember.user))
    )
    groups = result.scalars().all()
    return [_group_to_out(g) for g in groups]


@router.post("/join", status_code=200)
async def join_group(
    data: JoinGroupRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Entrar em um grupo pelo código de convite."""
    result = await db.execute(
        select(Group)
        .where(Group.invite_code == data.invite_code, Group.is_active == True)
        .options(selectinload(Group.members).selectinload(GroupMember.user))
    )
    group = result.scalar_one_or_none()
    if group is None:
        raise HTTPException(status_code=404, detail="Grupo não encontrado")

    for gm in group.members:
        if gm.user_id == current_user.id:
            raise HTTPException(
                status_code=400, detail="Você já é membro deste grupo"
            )

    member = GroupMember(
        group_id=group.id,
        user_id=current_user.id,
        role=GroupRole.member,
    )
    db.add(member)
    await db.flush()

    result = await db.execute(
        select(Group)
        .where(Group.id == group.id)
        .options(selectinload(Group.members).selectinload(GroupMember.user))
        .execution_options(populate_existing=True)
    )
    group = result.scalar_one()
    return _group_to_out(group)


@router.delete("/{group_id}/leave", status_code=204)
async def leave_group(
    group_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Sair de um grupo."""
    try:
        gid = uuid.UUID(group_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="ID de grupo inválido")

    result = await db.execute(
        select(GroupMember).where(
            GroupMember.group_id == gid,
            GroupMember.user_id == current_user.id,
        )
    )
    member = result.scalar_one_or_none()
    if member is None:
        raise HTTPException(
            status_code=404, detail="Você não é membro deste grupo"
        )

    await db.delete(member)
