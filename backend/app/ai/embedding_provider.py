import hashlib
import math
import re
from typing import Protocol

import httpx

from app.core.config import Settings, get_settings


class EmbeddingProviderError(Exception):
    pass


class EmbeddingProvider(Protocol):
    @property
    def model_name(self) -> str: ...

    @property
    def dimensions(self) -> int: ...

    async def embed_text(self, text: str) -> list[float]: ...


class OpenAICompatibleEmbeddingProvider:
    def __init__(self, settings: Settings) -> None:
        self._api_key = settings.embedding_api_key
        self._base_url = settings.embedding_base_url.rstrip("/")
        self._model_name = settings.embedding_model
        self._dimensions = settings.embedding_dimensions

    @property
    def model_name(self) -> str:
        return self._model_name

    @property
    def dimensions(self) -> int:
        return self._dimensions

    async def embed_text(self, text: str) -> list[float]:
        if not self._api_key:
            raise EmbeddingProviderError("EMBEDDING_API_KEY is not configured")
        try:
            async with httpx.AsyncClient(timeout=30) as client:
                response = await client.post(
                    f"{self._base_url}/embeddings",
                    headers={"Authorization": f"Bearer {self._api_key}"},
                    json={
                        "input": text,
                        "model": self.model_name,
                        "dimensions": self.dimensions,
                    },
                )
                response.raise_for_status()
                embedding = response.json()["data"][0]["embedding"]
        except (httpx.HTTPError, KeyError, IndexError, TypeError) as error:
            raise EmbeddingProviderError("Embedding provider request failed") from error

        try:
            values = [float(value) for value in embedding]
        except (TypeError, ValueError) as error:
            raise EmbeddingProviderError(
                "Embedding provider returned invalid values"
            ) from error
        if len(values) != self.dimensions:
            raise EmbeddingProviderError("Embedding provider returned wrong dimensions")
        return values


class DeterministicFakeEmbeddingProvider:
    def __init__(self, dimensions: int = 1536) -> None:
        self._dimensions = dimensions

    @property
    def model_name(self) -> str:
        return "deterministic-fake-v1"

    @property
    def dimensions(self) -> int:
        return self._dimensions

    async def embed_text(self, text: str) -> list[float]:
        vector = [0.0] * self.dimensions
        tokens = re.findall(r"[a-z0-9]+", text.lower())
        for token in tokens:
            digest = hashlib.sha256(token.encode("utf-8")).digest()
            index = int.from_bytes(digest[:4], "big") % self.dimensions
            vector[index] += 1.0 if digest[4] % 2 == 0 else -1.0
        magnitude = math.sqrt(sum(value * value for value in vector))
        if magnitude == 0:
            return vector
        return [value / magnitude for value in vector]


def get_embedding_provider(
    settings: Settings | None = None,
) -> EmbeddingProvider:
    configured = settings or get_settings()
    if configured.embedding_provider == "fake":
        return DeterministicFakeEmbeddingProvider(configured.embedding_dimensions)
    if configured.embedding_provider == "openai_compatible":
        return OpenAICompatibleEmbeddingProvider(configured)
    raise EmbeddingProviderError(
        f"Unsupported embedding provider: {configured.embedding_provider}"
    )