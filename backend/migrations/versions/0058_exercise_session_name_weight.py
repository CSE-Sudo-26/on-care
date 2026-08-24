"""운동 기록과 배정 루틴에 운동 이름·중량·강도·날짜를 더한다.

유형은 집계 축이라 넷(유산소/근력/유연성/기타)뿐이다. 그래서 기록을 다시 볼 때
"근력 12세트" 까지만 남고 무엇을 했는지는 사라졌다 — 스쿼트였는지 데드리프트였는지
회원도 트레이너도 알 수 없었다. 이름 칸을 둔다.

중량은 근력의 세트와 짝이다. 세트만으로는 같은 12세트가 20kg 인지 60kg 인지
구분되지 않아, 트레이너가 지난 기록을 보고 다음 무게를 정할 근거가 없었다.
소수점 한 자리까지 받는다(원판 0.5kg 단위).

배정 루틴에도 같은 칸을 둔다. 트레이너 화면에는 강도를 고르는 자리가 있었지만
저장할 칸이 없어 값이 버려졌고, 예상 칼로리는 늘 '보통'으로 계산됐다. 날짜도
마찬가지다 — 언제 하라고 보낸 배정인지 남지 않았다.

모든 칸이 이 마이그레이션 전 행에서는 비어 있다.

Revision ID: 0058_exercise_session_name_weight
Revises: 0057_exercise_session_sets
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0058_exercise_session_name_weight"
down_revision: str | Sequence[str] | None = "0057_exercise_session_sets"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "exercise_sessions",
        sa.Column("name", sa.String(length=100), nullable=False, server_default=""),
    )
    op.add_column(
        "exercise_sessions",
        sa.Column("weight", sa.Float(), nullable=True),
    )
    op.add_column(
        "trainer_routines",
        sa.Column("exercise_date", sa.String(length=10), nullable=True),
    )
    op.add_column(
        "trainer_routines",
        sa.Column(
            "intensity", sa.String(length=20), nullable=False, server_default="moderate"
        ),
    )
    op.add_column("trainer_routines", sa.Column("sets", sa.Integer(), nullable=True))
    op.add_column("trainer_routines", sa.Column("weight", sa.Float(), nullable=True))


def downgrade() -> None:
    op.drop_column("trainer_routines", "weight")
    op.drop_column("trainer_routines", "sets")
    op.drop_column("trainer_routines", "intensity")
    op.drop_column("trainer_routines", "exercise_date")
    op.drop_column("exercise_sessions", "weight")
    op.drop_column("exercise_sessions", "name")
