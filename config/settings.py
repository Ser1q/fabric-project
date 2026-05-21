from __future__ import annotations

from functools import lru_cache
from pydantic import Field, computed_field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",          
    )

    fabric_workspace_id: str = Field(default="", description="Fabric workspace GUID")
    lakehouse_bronze_id: str = Field(default="")
    lakehouse_silver_id: str = Field(default="")
    lakehouse_gold_id:   str = Field(default="")
    fabric_warehouse_conn: str = Field(default="")

    openaq_api_key:          str = Field(default="")
    openweathermap_api_key:  str = Field(default="")

    weather_city: str  = Field(default="New York")
    weather_lat:  float = Field(default=40.7128)
    weather_lon:  float = Field(default=-74.0060)

    timescale_host:     str = Field(default="localhost")
    timescale_port:     int = Field(default=5432)
    timescale_db:       str = Field(default="weather_ts")
    timescale_user:     str = Field(default="tsdb_user")
    timescale_password: str = Field(default="")

    telegram_bot_token: str = Field(default="")
    telegram_chat_id:   str = Field(default="")

    local_data_dir:   str = Field(default="./data")
    ge_data_docs_dir: str = Field(default="./ge_data_docs")

    @computed_field
    @property
    def timescale_dsn(self) -> str:
        return (
            f"postgresql+psycopg2://{self.timescale_user}:"
            f"{self.timescale_password}@{self.timescale_host}:"
            f"{self.timescale_port}/{self.timescale_db}"
        )

    @computed_field
    @property
    def timescale_psycopg2_kwargs(self) -> dict:
        return {
            "host":     self.timescale_host,
            "port":     self.timescale_port,
            "dbname":   self.timescale_db,
            "user":     self.timescale_user,
            "password": self.timescale_password,
        }


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()

settings = get_settings()

if __name__ == "__main__":
    import json

    safe_fields = {
        k: v for k, v in settings.model_dump().items()
        if "password" not in k and "token" not in k and "key" not in k
    }
    print(json.dumps(safe_fields, indent=2))
