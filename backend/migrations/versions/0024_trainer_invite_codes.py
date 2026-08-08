"""트레이너 가입 초대 코드

트레이너 계정을 만들 방법이 시드 스크립트뿐이었다. `/auth/register` 는 회원 전용
이라 트레이너 앱에서 가입해도 member 계정이 생기고 `/trainer/me` 가 403 을
돌려줬다. 그래서 가입 진입점이 데모에서만 열려 있었다. (#475)

헬스장이 발급한 코드로만 트레이너가 가입하게 한다. 코드가 소속(`gym_id`)을
결정하므로, 상담 대상 트레이너에게 소속을 요구하는 기존 조건(#443·#451)을 가입
시점에 자연히 만족시킨다.

코드 자체가 PK 다 — 사람이 옮겨 적는 값이고, 별도 대리키를 두면 조회 때마다
유니크 인덱스를 한 번 더 타야 한다.

Revision ID: 0024_trainer_invite_codes
Revises: 0023_consultation_decision
Create Date: 2026-08-08
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0024_trainer_invite_codes"
down_revision: str | Sequence[str] | None = "0023_consultation_decision"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "trainer_invite_codes",
        sa.Column("code", sa.String(length=32), nullable=False),
        sa.Column("gym_id", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("used_by", sa.String(length=64), nullable=True),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        # 헬스장이 사라지면 그 코드로 가입시킬 소속도 없다 — 함께 지운다.
        sa.ForeignKeyConstraint(["gym_id"], ["places.id"], ondelete="CASCADE"),
        # 가입한 트레이너가 탈퇴해도 코드 사용 이력은 남긴다.
        sa.ForeignKeyConstraint(["used_by"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("code"),
    )
    op.create_index(
        "ix_trainer_invite_codes_gym_id", "trainer_invite_codes", ["gym_id"]
    )


def downgrade() -> None:
    op.drop_index(
        "ix_trainer_invite_codes_gym_id", table_name="trainer_invite_codes"
    )
    op.drop_table("trainer_invite_codes")
