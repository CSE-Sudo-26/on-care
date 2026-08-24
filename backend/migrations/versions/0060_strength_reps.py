"""근력 기록과 배정 루틴에 횟수를 더한다.

세트·중량만으로는 근력 한 줄이 재현되지 않는다. "12세트 60kg" 은 한 세트에 몇
번을 들었는지가 빠져 있어, 트레이너가 지난 주와 같은 운동을 다시 짜려 해도
근거가 없고 회원도 무엇을 했는지 되짚을 수 없다. 세트·횟수·중량은 근력에서 셋이
한 벌이다.

#1276 이 통일 스펙을 잡으며 횟수를 뺐던 것을 되돌린다. 거리·휴식·RPE 는 그대로
두고 횟수만 되살린다 — 그 셋은 화면 어디에서도 묻지 않지만 횟수는 근력을 적는
모든 화면이 물어야 하는 값이다.

중량과 마찬가지로 칼로리 계산에는 쓰지 않는다. 표시·재현용 값이다.

이 마이그레이션 전 행에서는 비어 있다.

Revision ID: 0060_strength_reps
Revises: 0059_exercise_name_weight
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0060_strength_reps"
down_revision: str | Sequence[str] | None = "0059_exercise_name_weight"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("exercise_sessions", sa.Column("reps", sa.Integer(), nullable=True))
    op.add_column("trainer_routines", sa.Column("reps", sa.Integer(), nullable=True))


def downgrade() -> None:
    op.drop_column("trainer_routines", "reps")
    op.drop_column("exercise_sessions", "reps")
