"""Keep the trainer's in-progress report feedback instead of losing it on navigation.

리포트 탭의 `트레이너 피드백` 은 입력은 되지만 저장할 곳이 없었다(#821).
트레이너가 주간 리포트를 읽으며 코멘트를 쓰다가 다른 고객으로 옮기면 그대로
사라진다. 화면 옆의 `초안으로 되돌리기` 도 되돌릴 저장본이 없어 짝이 맞지
않았다.

전송된 리포트(`chat_messages`)와 따로 두는 까닭: 전송은 "회원에게 무엇이
나갔나" 의 기록이고, 이 표는 "트레이너가 무엇을 쓰다 말았나" 다. 같은 곳에
두면 아직 보내지 않은 문구가 회원 대화에 섞인다.

(trainer, member, week_start) 유니크 — 주차별로 한 행이다. 고객당 하나만
두면 주를 옮기는 순간 다른 주에 쓰던 문구가 따라온다.

Revision ID: 0046_report_feedback_draft
Revises: 0045_chat_pdf_attachments
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0046_report_feedback_draft"
down_revision: str | Sequence[str] | None = "0045_chat_pdf_attachments"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "trainer_report_feedback",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column(
            "trainer_id",
            sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "member_id",
            sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("week_start", sa.String(10), nullable=False),
        sa.Column("body", sa.Text(), nullable=False, server_default=""),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint(
            "trainer_id",
            "member_id",
            "week_start",
            name="uq_trainer_report_feedback_week",
        ),
    )
    op.create_index(
        "ix_trainer_report_feedback_trainer_id",
        "trainer_report_feedback",
        ["trainer_id"],
    )
    op.create_index(
        "ix_trainer_report_feedback_member_id",
        "trainer_report_feedback",
        ["member_id"],
    )
    op.create_index(
        "ix_trainer_report_feedback_week_start",
        "trainer_report_feedback",
        ["week_start"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_trainer_report_feedback_week_start", table_name="trainer_report_feedback"
    )
    op.drop_index(
        "ix_trainer_report_feedback_member_id", table_name="trainer_report_feedback"
    )
    op.drop_index(
        "ix_trainer_report_feedback_trainer_id", table_name="trainer_report_feedback"
    )
    op.drop_table("trainer_report_feedback")
