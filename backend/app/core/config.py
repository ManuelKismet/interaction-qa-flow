from functools import lru_cache

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = Field(
        default="postgresql+asyncpg://postgres:postgres@localhost:5432/smart_qa"
    )
    app_env: str = "development"
    debug: bool = False
    embedding_provider: str = "openai_compatible"
    embedding_model: str = "text-embedding-3-small"
    embedding_dimensions: int = 1536
    embedding_api_key: str | None = None
    embedding_base_url: str = "https://api.openai.com/v1"
    high_match_threshold: float = 0.82
    related_match_threshold: float = 0.68
    default_review_days: int = Field(default=180, ge=1)
    review_due_soon_days: int = Field(default=30, ge=1)

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @model_validator(mode="after")
    def validate_search_settings(self) -> "Settings":
        if self.embedding_dimensions != 1536:
            raise ValueError(
                "EMBEDDING_DIMENSIONS must match the 1536-dimension database column"
            )
        if not (
            0
            <= self.related_match_threshold
            <= self.high_match_threshold
            <= 1
        ):
            raise ValueError(
                "Search thresholds must satisfy 0 <= related <= high <= 1"
            )
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()