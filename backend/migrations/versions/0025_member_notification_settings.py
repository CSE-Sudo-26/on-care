"""회원 알림 수신 설정

회원 알림 설정이 기기 로컬(SharedPreferences)에만 있어 기기를 바꾸면 초기화됐고,
무엇보다 서버가 몰라서 알림을 만들 때 끌 수가 없었다. 트레이너는
`trainer_profiles.notify_*` 로 계정 단위 저장이 이미 되어 있어 두 앱이
비대칭이었다. (#489)

행이 없으면 기본값으로 본다 — 가입할 때마다 행을 만들지 않아도 되고, 기본값을
바꾸면 한 번도 설정을 건드리지 않은 회원에게 바로 적용된다. 그래서 기존 회원을
백필하지 않는다.

컬럼 기본값은 사용자 앱의 현재 기본값과 같다(주간 리포트만 꺼짐).

Revision ID: 0025_member_noti_settings
Revises: 0024_trainer_invite_codes
Create Date: 2026-08-08
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0025_member_noti_settings"
down_revision: str | Sequence[str] | None = "0024_trainer_invite_codes"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "member_notification_settings",
        sa.Column("member_id", sa.String(length=64), nullable=False),
        sa.Column(
            "diet_log", sa.Boolean(), server_default=sa.true(), nullable=False
        ),
        sa.Column(
            "exercise_reminder",
            sa.Boolean(),
            server_default=sa.true(),
            nullable=False,
        ),
        sa.Column(
            "trainer_message",
            sa.Boolean(),
            server_default=sa.true(),
            nullable=False,
        ),
        sa.Column(
            "ai_coaching",
            sa.Boolean(),
            server_default=sa.true(),
            nullable=False,
        ),
        sa.Column(
            "weekly_report",
            sa.Boolean(),
            server_default=sa.false(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["member_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("member_id"),
    )


def downgrade() -> None:
    op.drop_table("member_notification_settings")
