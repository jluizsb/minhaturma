import uuid
from datetime import datetime
from sqlalchemy import Column, Float, DateTime, ForeignKey, String, Boolean, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.core.database import Base


class Location(Base):
    __tablename__ = "locations"

    id         = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id    = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    latitude   = Column(Float, nullable=False)
    longitude  = Column(Float, nullable=False)
    accuracy   = Column(Float, nullable=True)   # metros
    speed      = Column(Float, nullable=True)   # m/s
    heading    = Column(Float, nullable=True)   # graus
    altitude   = Column(Float, nullable=True)
    address    = Column(String(500), nullable=True)
    recorded_at = Column(DateTime, default=datetime.utcnow, index=True)

    user = relationship("User", back_populates="locations")


class Geofence(Base):
    __tablename__ = "geofences"

    id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    group_id    = Column(UUID(as_uuid=True), ForeignKey("groups.id"), nullable=False)
    name        = Column(String(100), nullable=False)
    latitude    = Column(Float, nullable=False)
    longitude   = Column(Float, nullable=False)
    radius_meters = Column(Integer, default=200)
    is_active   = Column(Boolean, default=True)
    created_at  = Column(DateTime, default=datetime.utcnow)

    group = relationship("Group", back_populates="geofences")
