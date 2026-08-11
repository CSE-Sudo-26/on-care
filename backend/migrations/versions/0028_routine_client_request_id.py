"""trainer_routines.client_request_id (재전송 중복 배정 방지)

루틴 배정은 멱등하지 않아 매 요청이 새 행을 만든다. 전송 중 네트워크가 끊기면
서버는 이미 커밋했는데 클라이언트는 실패로 처리하는 구간이 생기고, 트레이너가
결과를 확인하지 않고 다시 보내면 회원에게 같은 루틴이 두 번 배정된다.

전송 시도당 멱등키를 저장하고 (trainer_id, member_id, client_request_id) 유니크
제약으로 재전송 중복을 차단한다. NULL 허용 → 기존/무키 요청은 제약 밖.
기존 행 보존을 위한 추가형(additive) 마이그레이션이다.

Postgres 는 NULL 을 서로 다른 값으로 보므로 키 없는 요청끼리는 충돌하지 않는다
(0009_diet_idempotency_key 와 같은 성질).

Revision ID: 0028_routine_client_req
Revises: 0027_exercise_source
Create Date: 2026-08-10
"""
from __future__ import annotations

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "0028_routine_client_req"
down_revision: str | Sequence[str] | None = "0027_exercise_source"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "trainer_routines",
        sa.Column("client_request_id", sa.String(64), nullable=True),
    )
    op.create_unique_constraint(
        "uq_trainer_routines_client_request",
        "trainer_routines",
        ["trainer_id", "member_id", "client_request_id"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_trainer_routines_client_request", "trainer_routines", type_="unique"
    )
    op.drop_column("trainer_routines", "client_request_id")
