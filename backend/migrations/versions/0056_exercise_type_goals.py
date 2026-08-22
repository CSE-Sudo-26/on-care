"""운동 목표를 운동 탭이 쓰는 축으로: 일일 소모 + 유형별 주간 목표 (#1139)

MY 건강 목표는 주간 운동 횟수·시간·소모칼로리를 다뤘는데, 운동 탭이 실제로
견주는 값은 **일일 소모 칼로리**와 **유형별 주간 목표**(유산소 분·근력 세트·
스트레칭 분)였다. 같은 회원의 목표를 두 화면이 서로 다른 축으로 말하고 있었다.

기존 세 컬럼은 남긴다 — 트레이너 앱이 고객의 주간 운동 횟수를 그대로 쓴다.

Revision ID: 0056_exercise_type_goals
Revises: 0055_slot_session_type
Create Date: 2026-08-23
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0056_exercise_type_goals"
down_revision: str | Sequence[str] | None = "0055_slot_session_type"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

#: health_profiles 에 추가하는 목표 컬럼(모두 nullable Integer).
_ADDED_COLUMNS: list[str] = [
    "daily_burn_kcal",
    "weekly_cardio_minutes",
    "weekly_strength_sets",
    "weekly_flexibility_minutes",
]


def upgrade() -> None:
    for name in _ADDED_COLUMNS:
        op.add_column(
            "health_profiles", sa.Column(name, sa.Integer(), nullable=True)
        )


def downgrade() -> None:
    for name in reversed(_ADDED_COLUMNS):
        op.drop_column("health_profiles", name)
