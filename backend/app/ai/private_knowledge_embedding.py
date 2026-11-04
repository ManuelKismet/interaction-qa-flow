import logging
import re
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
    words = re.findall(r"[a-z0-9]+", query.casefold())
    title_folded = title.casefold()
    title_words = re.findall(r"[a-z0-9]+", title_folded)
    body = " ".join(
        value.casefold()
        for key in ("body", "answer")
        if isinstance((value := data.get(key)), str)
    )
    body_words = re.findall(r"[a-z0-9]+", body)
    if not words:
        return 0.0, None, None
    title_hits = [word for word in words if _matches_word(word, title_words)]
    body_hits = [word for word in words if _matches_word(word, body_words)]
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
                and any(
                    _matches_word(word, re.findall(r"[a-z0-9]+", value.casefold()))
                    for word in body_hits
                )
            ),
            "",
        )
        normalized_query = " ".join(words)
        normalized_source = " ".join(re.findall(r"[a-z0-9]+", source.casefold()))
        relevance = (
            1.15
            if normalized_query in normalized_source
            else 1.1
            if len(body_hits) == len(words)
            else 0.9
        )
        return relevance, "content", source[:240]
    return 0.0, None, None


def _matches_word(query_word: str, candidates: list[str]) -> bool:
    return any(
        candidate == query_word
        or (len(query_word) >= 3 and candidate.startswith(query_word))
        or (
            len(query_word) >= 4
            and abs(len(candidate) - len(query_word)) <= 1
            and _one_edit_apart(candidate, query_word)
        )
        for candidate in candidates
    )


def _one_edit_apart(left: str, right: str) -> bool:
    if abs(len(left) - len(right)) > 1:
        return False
    previous = list(range(len(right) + 1))
    for index, left_char in enumerate(left, start=1):
        current = [index]
        for column, right_char in enumerate(right, start=1):
            current.append(
                min(
                    current[-1] + 1,
                    previous[column] + 1,
                    previous[column - 1] + (left_char != right_char),
                )
            )
        if min(current) > 1:
            return False
        previous = current
    return previous[-1] <= 1
