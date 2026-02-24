import uuid
from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.core.database import Base


class User(Base):
    __tablename__ = "users"

    id         = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email      = Column(String(255), unique=True, index=True, nullable=False)
    name       = Column(String(255), nullable=False)
    avatar_url = Column(Text, nullable=True)
    phone      = Column(String(20), nullable=True)

    # Autenticação local (opcional — pode usar só OAuth)
    hashed_password = Column(String(255), nullable=True)

    # OAuth / Social Login
    google_id    = Column(String(255), unique=True, nullable=True)
    facebook_id  = Column(String(255), unique=True, nullable=True)
    apple_id     = Column(String(255), unique=True, nullable=True)
    microsoft_id = Column(String(255), unique=True, nullable=True)
    aws_cognito_id = Column(String(255), unique=True, nullable=True)

    # Status
    is_active    = Column(Boolean, default=True)
    is_verified  = Column(Boolean, default=False)
    last_seen_at = Column(DateTime, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relacionamentos
    group_memberships = relationship("GroupMember", back_populates="user")
    locations         = relationship("Location",    back_populates="user")
    messages          = relationship("Message",     back_populates="sender")
    sos_events        = relationship("SOSEvent",    back_populates="user")
