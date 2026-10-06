import logging
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.embedding_provider import EmbeddingProvider, get_embedding_provider
from app.ai.embedding_service import embedding_source_hash

logger = logging.getLogger(__name__)


def private_knowledge_text(title: str, data: dict[str, Any]) -> str:
    parts = [title.strip()]
    for key in ("body", "answer"):
        value = data.get(key)
        if isinstance(value, str) and value.strip():
            parts.append(value.strip())
    return "\n\n".join(parts)


async def sync_private_knowledge_embedding(
    session: AsyncSession,
    item: Any,
    *,
    provider: EmbeddingProvider | None = None,
) -> bool:
    item.knowledge_embedding = None
    item.embedding_model = None
    item.embedding_source_hash = None
    try:
        provider = provider or get_embedding_provider()
    except Exception:
        logger.exception("Private Knowledge embeddings are unavailable")
        await session.commit()
        return False
    if provider.model_name.startswith("deterministic-fake-"):
        await session.commit()
        return False
    text = private_knowledge_text(item.title, item.data)
    source_hash = embedding_source_hash(text, provider.model_name)
    try:
        vector = await provider.embed_text(text)
        if len(vector) != provider.dimensions or len(vector) != 1536:
            raise ValueError("Embedding dimensions do not match stored vectors")
    except Exception:
        logger.exception("Failed to generate private Knowledge embedding")
        await session.commit()
        return False
    item.knowledge_embedding = vector
    item.embedding_model = provider.model_name
    item.embedding_source_hash = source_hash
    await session.commit()
    return True


def knowledge_match(
    query: str, title: str, data: dict[str, Any]
) -> tuple[float, str | None, str | None]:
    words = [word.casefold() for word in query.split() if word.strip()]
    title_folded = title.casefold()
    body = " ".join(
        value.casefold()
        for key in ("body", "answer")
        if isinstance((value := data.get(key)), str)
    )
    if not words:
        return 0.0, None, None
    title_hits = [word for word in words if word in title_folded]
    body_hits = [word for word in words if word in body]
    if not title_hits and not body_hits:
        return 0.0, None, None
    if title_folded == query.casefold().strip():
        return 2.0, "title", title
    if len(title_hits) == len(words):
        return 1.6, "title", title
    if title_hits:
        return 1.3, "title", title
    if body_hits:
        source = next(
            (
                value
                for key in ("body", "answer")
                if isinstance((value := data.get(key)), str)
                and any(word in value.casefold() for word in body_hits)
            ),
            "",
        )
        return 0.9, "content", source[:240]
    return 0.0, None, None
