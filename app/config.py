from functools import lru_cache
from typing import Literal
from pydantic_settings import BaseSettings, SettingsConfigDict

# we use this file to read and set the basic settings for the application, 
# like app name, version, environment, host, port, and log level. 
# We use pydantic settings to read the settings from the environment variables 
# or .env file.

class Settings(BaseSettings):
    app_name: str = "FastAPI Demo With Task Management API"
    app_description: str = "A FastAPI Demo with Task Management API to learn DevOps"
    app_version: str = "1.0.0"
    environment: Literal["local","development", "test","production"] = "local"
    debug: bool = False

    host: str = "0.0.0.0"
    port: int = 8000

    log_level: Literal["debug", "info", "warning", "error", "critical"] = "info"

    model_config = SettingsConfigDict(
        env_file=".env", 
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

@lru_cache()
def get_settings() -> Settings:
    return Settings()