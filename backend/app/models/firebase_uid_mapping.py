from sqlalchemy import ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class FirebaseUidMapping(TimestampMixin, Base):
    __tablename__ = "firebase_uid_mappings"
    __table_args__ = (
        UniqueConstraint("user_id", name="uq_firebase_uid_mappings_user"),
    )

    firebase_uid: Mapped[str] = mapped_column(String(128), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
