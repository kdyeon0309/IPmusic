from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://ipmusic:ipmusic@localhost:5432/ipmusic"

    # presence 판정 파라미터 (클라이언트는 30초 주기 재보고)
    presence_ttl_seconds: float = 90.0
    presence_sweep_interval_seconds: float = 15.0

    model_config = {"env_file": ".env", "env_prefix": "IPMUSIC_"}


settings = Settings()
