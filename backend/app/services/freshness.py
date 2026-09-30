from datetime import UTC, datetime, timedelta

from app.models.answer import Answer, AnswerStatus
from app.schemas.governance import FreshnessStatus


def answer_freshness(
    answer: Answer,
    *,
    has_open_challenge: bool,
    now: datetime | None = None,
    due_soon_days: int = 30,
) -> FreshnessStatus | None:
    if answer.status == AnswerStatus.SUPERSEDED:
        return FreshnessStatus.SUPERSEDED
    if has_open_challenge:
        return FreshnessStatus.CHALLENGED
    if answer.status != AnswerStatus.VERIFIED:
        return None
    if answer.review_due_at is None:
        return FreshnessStatus.CURRENT

    current_time = now or datetime.now(UTC)
    review_due_at = answer.review_due_at
    if review_due_at.tzinfo is None:
        review_due_at = review_due_at.replace(tzinfo=UTC)
    if review_due_at <= current_time:
        return FreshnessStatus.OVERDUE
    if review_due_at <= current_time + timedelta(days=due_soon_days):
        return FreshnessStatus.REVIEW_DUE_SOON
    return FreshnessStatus.CURRENT