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

유형 어휘도 되돌린다: `flexibility`/`유연성` → `stretching`/`스트레칭`. 회원과
트레이너가 실제로 쓰는 말이 "스트레칭" 이라, 두 앱의 입력 폼을 하나로 맞추면서
화면 문구만이 아니라 저장값까지 그 말로 옮겼다. 0053 이 반대 방향으로 접었던
것을 되돌리는 셈이다.

Revision ID: 0059_exercise_name_weight
Revises: 0058_reservation_slot_duration
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0059_exercise_name_weight"
down_revision: str | Sequence[str] | None = "0058_reservation_slot_duration"
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

    # 유형 어휘: 유연성 → 스트레칭. 0053 이 반대로 접었던 것을 되돌린다.
    op.execute(
        "UPDATE exercise_sessions SET type = 'stretching' "
        "WHERE type = 'flexibility'"
    )
    op.execute(
        "UPDATE trainer_routines SET type = '스트레칭' WHERE type = '유연성'"
    )
    # 프로그램·초안의 운동 항목은 JSON 안에 유형이 들어 있다. 문자열 치환으로
    # 바꾼다 — 이 값은 언제나 `"type": "유연성"` 꼴이라 다른 칸을 건드리지 않는다.
    for table, column in (
        ("trainer_routines", "exercises_json"),
        ("trainer_program_drafts", "sessions_json"),
        ("trainer_program_templates", "exercises_json"),
        ("trainer_schedule", "program_json"),
    ):
        op.execute(
            f"UPDATE {table} SET {column} = "
            f"REPLACE({column}, '\"type\": \"유연성\"', '\"type\": \"스트레칭\"') "
            f"WHERE {column} LIKE '%\"type\": \"유연성\"%'"
        )


def downgrade() -> None:
    op.drop_column("trainer_routines", "weight")
    op.drop_column("trainer_routines", "sets")
    op.drop_column("trainer_routines", "intensity")
    op.drop_column("trainer_routines", "exercise_date")
    op.drop_column("exercise_sessions", "weight")
    op.drop_column("exercise_sessions", "name")
