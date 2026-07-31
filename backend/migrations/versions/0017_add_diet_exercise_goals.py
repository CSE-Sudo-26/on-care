"""건강 목표 확장: 식단 일일 목표(탄단지) + 주간 운동 목표 컬럼 추가

MY-설정 건강 목표에서 편집하는 값. 식단 일일 목표에 탄수화물/단백질/지방을,
주간 운동 목표(횟수·시간·소모칼로리)를 추가한다. 체중/혈압/혈당(vitals) 목표는
다루지 않는다(0016 에서 제거됨).

Revision ID: 0017_add_diet_exercise_goals
Revises: 0016_drop_vitals
Create Date: 2026-07-31
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0017_add_diet_exercise_goals"
down_revision: str | Sequence[str] | None = "0016_drop_vitals"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# health_profiles 에 추가하는 목표 컬럼(모두 nullable Integer).
_ADDED_COLUMNS: list[str] = [
    "daily_carbs_g",
    "daily_protein_g",
    "daily_fat_g",
    "weekly_workout_goal",
    "weekly_exercise_minutes_goal",
    "weekly_burn_goal",
]


def upgrade() -> None:
    for name in _ADDED_COLUMNS:
        op.add_column(
            "health_profiles", sa.Column(name, sa.Integer(), nullable=True)
        )


def downgrade() -> None:
    for name in reversed(_ADDED_COLUMNS):
        op.drop_column("health_profiles", name)
