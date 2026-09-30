from dataclasses import dataclass
from uuid import UUID

from fastapi import Header


@dataclass(frozen=True)
class DevelopmentIdentity:
    organisation_id: UUID
    user_id: UUID


async def get_development_identity(
    # TODO(auth): replace these headers with validated authentication token claims.
    organisation_id: UUID = Header(alias="X-Organisation-ID"),
    user_id: UUID = Header(alias="X-User-ID"),
) -> DevelopmentIdentity:
    return DevelopmentIdentity(organisation_id=organisation_id, user_id=user_id)