import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, ForeignKey, Text, Enum, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import enum

from app.core.database import Base


class MessageType(str, enum.Enum):
    text  = "text"
    image = "image"
    video = "video"
    sos   = "sos"
    system = "system"


class Message(Base):
    __tablename__ = "messages"

    id         = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    group_id   = Column(UUID(as_uuid=True), ForeignKey("groups.id"), nullable=False)
    sender_id  = Column(UUID(as_uuid=True), ForeignKey("users.id"),  nullable=False)
    type       = Column(Enum(MessageType), default=MessageType.text)
    content    = Column(Text, nullable=True)       # texto ou URL da mídia (S3)
    media_key  = Column(String(500), nullable=True) # chave no S3
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    group  = relationship("Group", back_populates="messages")
    sender = relationship("User",  back_populates="messages")


class SOSEvent(Base):
    __tablename__ = "sos_events"

    id         = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id    = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    latitude   = Column(Float,  nullable=False)
    longitude  = Column(Float,  nullable=False)
    message    = Column(Text,   nullable=True)
    resolved   = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="sos_events")
