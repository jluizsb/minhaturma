from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    # Projeto
    PROJECT_NAME: str = "MinhaTurma API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = "development"  # development | staging | production

    # Segurança
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Banco de Dados (AWS RDS PostgreSQL)
    DATABASE_URL: str
    DB_POOL_SIZE: int = 10
    DB_MAX_OVERFLOW: int = 20

    # Redis (AWS ElastiCache)
    REDIS_URL: str = "redis://localhost:6379"

    # AWS
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    AWS_REGION: str = "us-east-1"
    AWS_S3_BUCKET: str = ""
    AWS_COGNITO_USER_POOL_ID: str = ""
    AWS_COGNITO_APP_CLIENT_ID: str = ""
    AWS_COGNITO_REGION: str = "us-east-1"

    # Provedores OAuth (via AWS Cognito ou direto)
    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""

    FACEBOOK_APP_ID: str = ""
    FACEBOOK_APP_SECRET: str = ""

    MICROSOFT_CLIENT_ID: str = ""
    MICROSOFT_CLIENT_SECRET: str = ""
    MICROSOFT_TENANT_ID: str = "common"

    APPLE_CLIENT_ID: str = ""
    APPLE_TEAM_ID: str = ""
    APPLE_KEY_ID: str = ""
    APPLE_PRIVATE_KEY: str = ""

    # Firebase (Push Notifications)
    FIREBASE_PROJECT_ID: str = ""
    FIREBASE_CREDENTIALS_PATH: str = "firebase-credentials.json"

    # Google Maps
    GOOGLE_MAPS_API_KEY: str = ""

    # CORS e Hosts permitidos
    ALLOWED_ORIGINS: List[str] = ["http://localhost:3000"]
    ALLOWED_HOSTS: List[str] = ["*"]

    # Localização
    LOCATION_UPDATE_INTERVAL_SECONDS: int = 30
    LOCATION_HISTORY_DAYS: int = 7

    # Mídia
    MAX_UPLOAD_SIZE_MB: int = 50
    ALLOWED_MEDIA_TYPES: List[str] = ["image/jpeg", "image/png", "video/mp4"]

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
