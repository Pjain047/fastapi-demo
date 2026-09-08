from functools import lru_cache
from typing import Literal
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# Read application settings from environment variables or the .env file.

class Settings(BaseSettings):
    app_name: str = "FastAPI Demo With Task Management API"
    app_description: str = "A FastAPI Demo with Task Management API to learn DevOps"
    app_version: str = "1.0.0"
    environment: Literal["local", "development", "test", "production","minikube"] = "local"
    debug: bool = False

    host: str = "0.0.0.0"
    port: int = 8000

    log_level: Literal["debug", "info", "warning", "error", "critical"] = "info"
   
    metrics_enabled: bool = True

    demo_api_key: str | None = None
    demo_username: str | None = None

    @field_validator("log_level", mode="before")
    @classmethod
    def normalize_log_level(cls, value: str) -> str:
        return value.lower()

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

@lru_cache()
def get_settings() -> Settings:
    return Settings()