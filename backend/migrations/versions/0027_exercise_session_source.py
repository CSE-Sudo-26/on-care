"""운동 기록의 출처 표시

트레이너가 PT 세션을 완료 처리하면 회원 쪽 운동 기록(`exercise_sessions`)이
파생 생성된다(#499). 그 기록은 근거가 트레이너에게 있어 회원이 수정·삭제할 수
없고 화면에서도 수기 입력과 구분돼야 하는데, 지금 스키마로는 둘을 구별할 방법이
없다.

기존 행은 전부 회원이 직접 남긴 것이므로 server_default 로 'member' 가 채워진다.
백필 쿼리가 따로 필요 없다.

Revision ID: 0027_exercise_source
Revises: 0026_trainer_reservations
Create Date: 2026-08-09
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0027_exercise_source"
down_revision: str | Sequence[str] | None = "0026_trainer_reservations"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "exercise_sessions",
        sa.Column(
            "source",
            sa.String(length=20),
            server_default="member",
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_column("exercise_sessions", "source")
