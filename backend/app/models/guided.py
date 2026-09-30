import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    ForeignKeyConstraint,
    Integer,
    String,
    Text,
    UniqueConstraint,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


def enum_values(values: type[enum.Enum]) -> list[str]:
    return [item.value for item in values]


class GuidedTemplateStatus(str, enum.Enum):
    ACTIVE = "active"
    ARCHIVED = "archived"


class GuidedSessionStatus(str, enum.Enum):
    DRAFT = "draft"
    ACTIVE = "active"
    COMPLETED = "completed"
    ARCHIVED = "archived"


class GuidedSessionVisibility(str, enum.Enum):
    PRIVATE = "private"
    DEPARTMENT = "department"
    TEAM = "team"
    ORGANISATION = "organisation"


class GuidedQuestionScope(str, enum.Enum):
    SHARED = "shared"
    PARTICIPANT = "participant"


class GuidedQuestionSource(str, enum.Enum):
    TEMPLATE = "template"
    MANUAL = "manual"
    FOLLOW_UP = "follow_up"


class KnowledgeProposalStatus(str, enum.Enum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    REJECTED = "rejected"
    DUPLICATE = "duplicate"


class GuidedTemplate(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "guided_templates"
    __table_args__ = (
        UniqueConstraint("id", "organisation_id", name="uq_guided_templates_id_org"),
        UniqueConstraint(
            "organisation_id", "created_by", "name", name="uq_guided_templates_owner_name"
        ),
        ForeignKeyConstraint(
            ["department_id", "organisation_id"],
            ["departments.id", "departments.organisation_id"],
            name="fk_guided_templates_department_org",
        ),
        ForeignKeyConstraint(
            ["team_id", "organisation_id"],
            ["teams.id", "teams.organisation_id"],
            name="fk_guided_templates_team_org",
        ),
    )

    organisation_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("organisations.id", ondelete="CASCADE"), index=True
    )
    created_by: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    name: Mapped[str] = mapped_column(String(255))
    description: Mapped[str | None] = mapped_column(Text)
    department_id: Mapped[uuid.UUID | None] = mapped_column(Uuid(as_uuid=True), index=True)
    team_id: Mapped[uuid.UUID | None] = mapped_column(Uuid(as_uuid=True), index=True)
    status: Mapped[GuidedTemplateStatus] = mapped_column(
        Enum(GuidedTemplateStatus, name="guided_template_status", values_callable=enum_values),
        default=GuidedTemplateStatus.ACTIVE,
    )
    current_version: Mapped[int] = mapped_column(Integer, default=1)


class GuidedTemplateVersion(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "guided_template_versions"
    __table_args__ = (
        UniqueConstraint("id", "organisation_id", name="uq_guided_template_versions_id_org"),
        UniqueConstraint("template_id", "version_number", name="uq_guided_template_version"),
        ForeignKeyConstraint(
            ["template_id", "organisation_id"],
            ["guided_templates.id", "guided_templates.organisation_id"],
            name="fk_guided_template_versions_template_org",
            ondelete="CASCADE",
        ),
    )

    organisation_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("organisations.id", ondelete="CASCADE"), index=True
    )
    template_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), index=True)
    version_number: Mapped[int] = mapped_column(Integer)
    created_by: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT")
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class GuidedTemplateQuestion(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "guided_template_questions"
    __table_args__ = (
        UniqueConstraint("id", "organisation_id", name="uq_guided_template_questions_id_org"),
        ForeignKeyConstraint(
            ["template_version_id", "organisation_id"],
            ["guided_template_versions.id", "guided_template_versions.organisation_id"],
            name="fk_guided_template_questions_version_org",
            ondelete="CASCADE",
        ),
        ForeignKeyConstraint(
            ["parent_template_question_id", "organisation_id"],
            ["guided_template_questions.id", "guided_template_questions.organisation_id"],
            name="fk_guided_template_questions_parent_org",
            ondelete="CASCADE",
        ),
    )

    organisation_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("organisations.id", ondelete="CASCADE"), index=True
    )
    template_version_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), index=True)
    text: Mapped[str] = mapped_column(Text)
    scope: Mapped[GuidedQuestionScope] = mapped_column(
        Enum(GuidedQuestionScope, name="guided_question_scope", values_callable=enum_values)
    )
    participant_reference: Mapped[str | None] = mapped_column(String(255))
    order_index: Mapped[int] = mapped_column(Integer)
    parent_template_question_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True), index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class GuidedSession(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "guided_sessions"
    __table_args__ = (
        UniqueConstraint("id", "organisation_id", name="uq_guided_sessions_id_org"),
        ForeignKeyConstraint(
            ["department_id", "organisation_id"],
            ["departments.id", "departments.organisation_id"],
            name="fk_guided_sessions_department_org",
        ),
        ForeignKeyConstraint(
            ["team_id", "organisation_id"],
            ["teams.id", "teams.organisation_id"],
            name="fk_guided_sessions_team_org",
        ),
        ForeignKeyConstraint(
            ["template_id", "organisation_id"],
            ["guided_templates.id", "guided_templates.organisation_id"],
            name="fk_guided_sessions_template_org",
        ),
        ForeignKeyConstraint(
            ["template_version_id", "organisation_id"],
            ["guided_template_versions.id", "guided_template_versions.organisation_id"],
            name="fk_guided_sessions_template_version_org",
        ),
    )

    organisation_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("organisations.id", ondelete="CASCADE"), index=True
    )
    created_by: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    template_id: Mapped[uuid.UUID | None] = mapped_column(Uuid(as_uuid=True), index=True)
    template_version_id: Mapped[uuid.UUID | None] = mapped_column(Uuid(as_uuid=True))
    title: Mapped[str] = mapped_column(String(500))
    owner_text: Mapped[str | None] = mapped_column(String(255))
    context_reference: Mapped[str | None] = mapped_column(Text)
    department_id: Mapped[uuid.UUID | None] = mapped_column(Uuid(as_uuid=True), index=True)
    team_id: Mapped[uuid.UUID | None] = mapped_column(Uuid(as_uuid=True), index=True)
    visibility: Mapped[GuidedSessionVisibility] = mapped_column(
        Enum(
            GuidedSessionVisibility,
            name="guided_session_visibility",
            values_callable=enum_values,
        ),
        default=GuidedSessionVisibility.PRIVATE,
    )
    status: Mapped[GuidedSessionStatus] = mapped_column(
        Enum(GuidedSessionStatus, name="guided_session_status", values_callable=enum_values),
        default=GuidedSessionStatus.DRAFT,
    )
    revision: Mapped[int] = mapped_column(Integer, default=1)
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class GuidedParticipant(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "guided_participants"
    __table_args__ = (
        UniqueConstraint("id", "organisation_id", name="uq_guided_participants_id_org"),
        ForeignKeyConstraint(
            ["session_id", "organisation_id"],
            ["guided_sessions.id", "guided_sessions.organisation_id"],
            name="fk_guided_participants_session_org",
            ondelete="CASCADE",
        ),
        ForeignKeyConstraint(
            ["linked_user_id", "organisation_id"],
            ["users.id", "users.organisation_id"],
            name="fk_guided_participants_user_org",
        ),
    )

    organisation_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("organisations.id", ondelete="CASCADE"), index=True
    )
    session_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), index=True)
    name: Mapped[str] = mapped_column(String(255))
    role_label: Mapped[str | None] = mapped_column(String(255))
    linked_user_id: Mapped[uuid.UUID | None] = mapped_column(Uuid(as_uuid=True))
    notes: Mapped[str | None] = mapped_column(Text)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)


class GuidedQuestion(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "guided_questions"
    __table_args__ = (
        UniqueConstraint("id", "organisation_id", name="uq_guided_questions_id_org"),
        ForeignKeyConstraint(
            ["session_id", "organisation_id"],
            ["guided_sessions.id", "guided_sessions.organisation_id"],
            name="fk_guided_questions_session_org",
            ondelete="CASCADE",
        ),
        ForeignKeyConstraint(
            ["target_participant_id", "organisation_id"],
            ["guided_participants.id", "guided_participants.organisation_id"],
            name="fk_guided_questions_participant_org",
        ),
        ForeignKeyConstraint(
            ["triggering_answer_id", "organisation_id"],
            ["guided_answers.id", "guided_answers.organisation_id"],
            name="fk_guided_questions_triggering_answer_org",
            use_alter=True,
        ),
    )

    organisation_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("organisations.id", ondelete="CASCADE"), index=True
    )
    session_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), index=True)
    template_question_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("guided_template_questions.id", ondelete="SET NULL")
    )
    created_by: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT")
    )
    text: Mapped[str] = mapped_column(Text)
    scope: Mapped[GuidedQuestionScope] = mapped_column(
        Enum(GuidedQuestionScope, name="guided_question_scope", values_callable=enum_values)
    )
    target_participant_id: Mapped[uuid.UUID | None] = mapped_column(Uuid(as_uuid=True), index=True)
    source: Mapped[GuidedQuestionSource] = mapped_column(
        Enum(GuidedQuestionSource, name="guided_question_source", values_callable=enum_values)
    )
    main_order_index: Mapped[int | None] = mapped_column(Integer)
    branch_order_index: Mapped[int | None] = mapped_column(Integer)
    triggering_answer_id: Mapped[uuid.UUID | None] = mapped_column(Uuid(as_uuid=True), index=True)
    knowledge_question_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("questions.id", ondelete="SET NULL"), index=True
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)


class GuidedAnswer(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "guided_answers"
    __table_args__ = (
        UniqueConstraint("id", "organisation_id", name="uq_guided_answers_id_org"),
        UniqueConstraint("question_id", "participant_id", name="uq_guided_answer_question_participant"),
        ForeignKeyConstraint(
            ["session_id", "organisation_id"],
            ["guided_sessions.id", "guided_sessions.organisation_id"],
            name="fk_guided_answers_session_org",
            ondelete="CASCADE",
        ),
        ForeignKeyConstraint(
            ["question_id", "organisation_id"],
            ["guided_questions.id", "guided_questions.organisation_id"],
            name="fk_guided_answers_question_org",
            ondelete="CASCADE",
            use_alter=True,
        ),
        ForeignKeyConstraint(
            ["participant_id", "organisation_id"],
            ["guided_participants.id", "guided_participants.organisation_id"],
            name="fk_guided_answers_participant_org",
        ),
    )

    organisation_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("organisations.id", ondelete="CASCADE"), index=True
    )
    session_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), index=True)
    question_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), index=True)
    participant_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), index=True)
    answered_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL")
    )
    body: Mapped[str] = mapped_column(Text, default="")
    branches_collapsed: Mapped[bool] = mapped_column(Boolean, default=False)


class GuidedSessionRevision(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "guided_session_revisions"
    __table_args__ = (
        UniqueConstraint("session_id", "revision_number", name="uq_guided_session_revision"),
        ForeignKeyConstraint(
            ["session_id", "organisation_id"],
            ["guided_sessions.id", "guided_sessions.organisation_id"],
            name="fk_guided_session_revisions_session_org",
            ondelete="CASCADE",
        ),
    )

    organisation_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("organisations.id", ondelete="CASCADE"), index=True
    )
    session_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), index=True)
    revision_number: Mapped[int] = mapped_column(Integer)
    saved_by: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT")
    )
    summary: Mapped[dict] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class KnowledgeProposal(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "knowledge_proposals"
    __table_args__ = (
        ForeignKeyConstraint(
            ["guided_session_id", "organisation_id"],
            ["guided_sessions.id", "guided_sessions.organisation_id"],
            name="fk_knowledge_proposals_session_org",
        ),
        ForeignKeyConstraint(
            ["guided_question_id", "organisation_id"],
            ["guided_questions.id", "guided_questions.organisation_id"],
            name="fk_knowledge_proposals_question_org",
        ),
        ForeignKeyConstraint(
            ["guided_answer_id", "organisation_id"],
            ["guided_answers.id", "guided_answers.organisation_id"],
            name="fk_knowledge_proposals_answer_org",
        ),
        ForeignKeyConstraint(
            ["department_id", "organisation_id"],
            ["departments.id", "departments.organisation_id"],
            name="fk_knowledge_proposals_department_org",
        ),
        ForeignKeyConstraint(
            ["team_id", "organisation_id"],
            ["teams.id", "teams.organisation_id"],
            name="fk_knowledge_proposals_team_org",
        ),
    )

    organisation_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("organisations.id", ondelete="CASCADE"), index=True
    )
    guided_session_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), index=True)
    guided_question_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), index=True)
    guided_answer_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), index=True)
    proposed_by: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    proposed_question_text: Mapped[str] = mapped_column(Text)
    proposed_answer_text: Mapped[str] = mapped_column(Text)
    department_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True)
    )
    team_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True)
    )
    status: Mapped[KnowledgeProposalStatus] = mapped_column(
        Enum(
            KnowledgeProposalStatus,
            name="knowledge_proposal_status",
            values_callable=enum_values,
        ),
        default=KnowledgeProposalStatus.PENDING,
        index=True,
    )
    reviewed_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL")
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_question_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("questions.id", ondelete="SET NULL")
    )
    linked_question_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("questions.id", ondelete="SET NULL")
    )