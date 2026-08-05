"""트레이너 알림 수신 설정 컬럼 추가

`/my?t=settings` 의 알림 설정이 기기 로컬(SharedPreferences)에만 있어 센터 PC 에서
끈 알림이 태블릿에서는 켜져 있었다. 계정 단위로 옮긴다.

값이 3개뿐이고 프로필과 수명이 같으므로 별도 테이블 대신 `trainer_profiles` 컬럼으로
둔다. 기본값은 서버가 정한다(모두 켬 / 30분 전) — 클라이언트마다 기본값을 들고 있으면
기기마다 갈라진다.

Revision ID: 0019_trainer_noti_settings
Revises: 0018_diet_entry_sugar_g_float
Create Date: 2026-08-06
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0019_trainer_noti_settings"
down_revision: str | Sequence[str] | None = "0018_diet_entry_sugar_g_float"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # server_default 를 함께 주는 이유: 기존 행에도 즉시 값이 채워져야 하고,
    # 그 값이 곧 계약상의 기본값이다(모두 켬 / 30분 전).
    op.add_column(
        "trainer_profiles",
        sa.Column(
            "notify_new_message",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
    )
    op.add_column(
        "trainer_profiles",
        sa.Column(
            "notify_session_reminder",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
    )
    op.add_column(
        "trainer_profiles",
        sa.Column(
            "reminder_lead_minutes",
            sa.Integer(),
            nullable=False,
            server_default="30",
        ),
    )


def downgrade() -> None:
    op.drop_column("trainer_profiles", "reminder_lead_minutes")
    op.drop_column("trainer_profiles", "notify_session_reminder")
    op.drop_column("trainer_profiles", "notify_new_message")
