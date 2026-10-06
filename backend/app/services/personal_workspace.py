from __future__ import annotations

from typing import Any
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as postgres_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.personal_workspace import PersonalWorkspaceItem
from app.schemas.personal_workspace import PersonalWorkspaceItemInput


def _item_result(item: PersonalWorkspaceItem) -> dict[str, Any]:
    return {
        "id": item.id,
        "kind": item.kind,
        "source_key": item.source_key,
        "title": item.title,
        "data": item.data,
        "revision": item.revision,
        "created_at": item.created_at.isoformat(),
        "updated_at": item.updated_at.isoformat(),
    }


class PersonalWorkspaceService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list_items(self, firebase_uid: str) -> list[dict[str, Any]]:
        result = await self.session.scalars(
            select(PersonalWorkspaceItem)
            .where(PersonalWorkspaceItem.firebase_uid == firebase_uid)
            .order_by(PersonalWorkspaceItem.created_at, PersonalWorkspaceItem.id)
        )
        return [_item_result(item) for item in result]

    async def import_items(
        self,
        firebase_uid: str,
        items: list[PersonalWorkspaceItemInput],
    ) -> dict[str, Any]:
        bind = self.session.get_bind()
        insert = {
            "sqlite": sqlite_insert,
            "postgresql": postgres_insert,
        }.get(bind.dialect.name)
        if insert is None:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Personal workspace storage is unavailable.",
            )

        stored: list[dict[str, Any]] = []
        created: list[bool] = []
        for payload in items:
            statement = (
                insert(PersonalWorkspaceItem)
                .values(
                    firebase_uid=firebase_uid,
                    source_key=payload.source_key,
                    kind=payload.kind,
                    title=payload.title,
                    data=payload.data,
                    revision=1,
                )
                .on_conflict_do_nothing(
                    index_elements=[
                        PersonalWorkspaceItem.firebase_uid,
                        PersonalWorkspaceItem.source_key,
                    ]
                )
                .returning(PersonalWorkspaceItem)
            )
            item = (await self.session.scalars(statement)).one_or_none()
            was_created = item is not None
            if item is None:
                item = await self.session.scalar(
                    select(PersonalWorkspaceItem).where(
                        PersonalWorkspaceItem.firebase_uid == firebase_uid,
                        PersonalWorkspaceItem.source_key == payload.source_key,
                    )
                )
            if item is None:
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="The personal import could not be confirmed. Retry safely.",
                )
            stored.append(_item_result(item))
            created.append(was_created)
        await self.session.commit()
        return {"items": stored, "created": created}

    async def update_item(
        self,
        firebase_uid: str,
        item_id: UUID,
        *,
        expected_revision: int,
        title: str,
        data: dict[str, Any],
    ) -> dict[str, Any]:
        item = await self.session.scalar(
            select(PersonalWorkspaceItem)
            .where(
                PersonalWorkspaceItem.id == item_id,
                PersonalWorkspaceItem.firebase_uid == firebase_uid,
            )
            .with_for_update()
        )
        if item is None:
            raise HTTPException(status_code=404, detail="Personal item not found.")
        if item.revision != expected_revision:
            if (
                item.revision == expected_revision + 1
                and item.title == title
                and item.data == data
            ):
                return _item_result(item)
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This personal item changed elsewhere. Reload it and retry.",
            )
        item.title = title
        item.data = data
        item.revision += 1
        await self.session.commit()
        await self.session.refresh(item)
        return _item_result(item)

    async def delete_item(self, firebase_uid: str, item_id: UUID) -> None:
        item = await self.session.scalar(
            select(PersonalWorkspaceItem)
            .where(
                PersonalWorkspaceItem.id == item_id,
                PersonalWorkspaceItem.firebase_uid == firebase_uid,
            )
            .with_for_update()
        )
        if item is None:
            return
        await self.session.delete(item)
        await self.session.commit()
