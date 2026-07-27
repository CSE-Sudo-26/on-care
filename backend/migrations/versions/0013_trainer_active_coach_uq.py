"""trainer_clients: 회원당 active 담당 1명 partial unique index

회원측 API 는 '현재 담당 코치 1명'을 전제하므로, trainer_clients 에서 회원당 active 링크는
최대 1개여야 한다. 이를 PostgreSQL partial unique index 로 강제한다
(active=false 휴면 링크는 과거 이력으로 여러 개 허용).

이 인덱스는 0012_trainer_domain(테이블 생성) 을 수정하지 않고 별도 revision 으로 추가한다.
0012 가 이미 적용된 DB 에서도 이 마이그레이션이 새 revision 으로 반드시 실행되어
ORM(모델 __table_args__)과 실제 DB 스키마가 어긋나지 않게 한다.

Revision ID: 0013_trainer_active_coach_uq
Revises: 0012_trainer_domain
Create Date: 2026-07-27
"""
from __future__ import annotations

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "0013_trainer_active_coach_uq"
down_revision: str | Sequence[str] | None = "0012_trainer_domain"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_index(
        "uq_trainer_client_active_member",
        "trainer_clients",
        ["member_id"],
        unique=True,
        postgresql_where=sa.text("active"),
    )


def downgrade() -> None:
    op.drop_index("uq_trainer_client_active_member", table_name="trainer_clients")
