"""근력 기록에 세트 수를 더한다.

근력은 시간으로 재는 운동이 아니다. 화면(홈 운동 카드·운동 현황 링·주간 목표)은
이미 근력을 **세트**로 읽는데, 기록에는 분만 있어서 `분 ÷ 3` 으로 되짚어 세트를
지어내고 있었다. 되짚은 값은 반올림에서 어긋나고(12세트→36분→12세트 는 맞지만
10세트→30분→10세트 옆에서 11세트→33분→11세트 처럼 경계값이 흔들린다), 무엇보다
회원이 실제로 적은 수가 아니다.

세트를 그대로 저장한다. 유산소·유연성·기타는 여전히 분이 원본이라 이 칸은 비어
있고, 이 컬럼이 생기기 전의 근력 기록도 비어 있다 — 비어 있으면 예전처럼 분에서
환산해 읽는다.

Revision ID: 0057_exercise_session_sets
Revises: 0056_exercise_type_goals
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0057_exercise_session_sets"
down_revision: str | Sequence[str] | None = "0056_exercise_type_goals"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "exercise_sessions",
        sa.Column("sets", sa.Integer(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("exercise_sessions", "sets")
