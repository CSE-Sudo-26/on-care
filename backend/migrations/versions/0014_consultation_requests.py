"""회원 상담 요청 테이블

회원이 헬스장 또는 트레이너에게 보내는 상담 요청을 저장한다. 대상별 pending
요청은 partial unique index 로 한 건만 허용해 동시 요청에서도 중복 생성을 막는다.

Revision ID: 0014_consultation_requests
Revises: 0013_trainer_active_coach_uq
Create Date: 2026-07-29
"""
from __future__ import annotations

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "0014_consultation_requests"
down_revision: str | Sequence[str] | None = "0013_trainer_active_coach_uq"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "consultation_requests",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column(
            "member_id", sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False,
        ),
        sa.Column("target_type", sa.String(20), nullable=False),
        sa.Column(
            "gym_id", sa.String(64),
            sa.ForeignKey("places.id", ondelete="SET NULL"), nullable=True,
        ),
        sa.Column(
            "trainer_id", sa.String(64),
            sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True,
        ),
        sa.Column("exercise_goal", sa.String(30), nullable=False),
        sa.Column("health_purpose_type", sa.String(30), nullable=False),
        sa.Column("health_purpose_detail", sa.Text(), nullable=True),
        sa.Column("preferred_date", sa.String(10), nullable=False),
        sa.Column("preferred_time_slot", sa.String(20), nullable=False),
        sa.Column("message", sa.Text(), nullable=True),
        sa.Column(
            "status", sa.String(20), nullable=False, server_default="pending",
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_consultation_requests_member_id",
        "consultation_requests",
        ["member_id"],
    )
    op.create_index(
        "ix_consultation_requests_member_created_at",
        "consultation_requests",
        ["member_id", "created_at"],
    )
    op.create_index(
        "uq_consultation_requests_pending_gym",
        "consultation_requests",
        ["member_id", "gym_id"],
        unique=True,
        postgresql_where=sa.text("target_type = 'gym' AND status = 'pending'"),
    )
    op.create_index(
        "uq_consultation_requests_pending_trainer",
        "consultation_requests",
        ["member_id", "trainer_id"],
        unique=True,
        postgresql_where=sa.text("target_type = 'trainer' AND status = 'pending'"),
    )


def downgrade() -> None:
    op.drop_table("consultation_requests")
