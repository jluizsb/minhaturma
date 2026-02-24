import uuid
from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey, Text, Enum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import enum

from app.core.database import Base


class GroupRole(str, enum.Enum):
    admin  = "admin"
    member = "member"


class Group(Base):
    __tablename__ = "groups"

    id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name        = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    avatar_url  = Column(Text, nullable=True)
    invite_code = Column(String(12), unique=True, index=True)
    is_active   = Column(Boolean, default=True)
    created_at  = Column(DateTime, default=datetime.utcnow)
    updated_at  = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    members   = relationship("GroupMember", back_populates="group")
    messages  = relationship("Message",     back_populates="group")
    geofences = relationship("Geofence",    back_populates="group")


class GroupMember(Base):
    __tablename__ = "group_members"

    id         = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    group_id   = Column(UUID(as_uuid=True), ForeignKey("groups.id"), nullable=False)
    user_id    = Column(UUID(as_uuid=True), ForeignKey("users.id"),  nullable=False)
    role       = Column(Enum(GroupRole), default=GroupRole.member)
    joined_at  = Column(DateTime, default=datetime.utcnow)

    group = relationship("Group", back_populates="members")
    user  = relationship("User",  back_populates="group_memberships")
