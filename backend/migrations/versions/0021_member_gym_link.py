"""회원↔헬스장 링크 테이블

회원의 '내 헬스장'이 담당 트레이너의 소속(`trainer_profiles.gym_id`)에서 파생돼,
트레이너만 해제해도 헬스장이 같이 사라졌다. 앱 MY 탭은 두 해제를 따로 제공하므로
서버에도 각각의 링크가 있어야 한다. (#444)

기존 회원의 헬스장을 잃지 않도록, 활성 담당 링크가 있는 회원은 그 트레이너의
소속 헬스장으로 채워 넣는다 — 지금까지 화면에 보이던 값과 같다.

Revision ID: 0021_member_gym_link
Revises: 0020_gym_profiles_trainer_fk
Create Date: 2026-08-07
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0021_member_gym_link"
down_revision: str | Sequence[str] | None = "0020_gym_profiles_trainer_fk"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "member_gyms",
        # 회원당 헬스장 1곳. PK 로 두면 불변식이 구조로 강제돼 별도 유니크 인덱스가
        # 필요 없다(담당 링크가 partial unique index 로 하는 일을 여기선 PK 가 한다).
        sa.Column(
            "member_id",
            sa.String(length=64),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        # 헬스장은 places(category='fitness'). 장소가 지워지면 링크도 지운다 —
        # NOT NULL 이라 SET NULL 을 쓸 수 없다.
        sa.Column(
            "gym_id",
            sa.String(length=64),
            sa.ForeignKey("places.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    # '이 헬스장에 연결된 회원'을 세는 방향(트레이너 앱·운영 통계)이 인덱스 없이는
    # 전건 스캔이다.
    op.create_index("ix_member_gyms_gym_id", "member_gyms", ["gym_id"])

    # 백필: 활성 담당이 있고 그 트레이너의 소속 헬스장을 아는 회원.
    # 지금 화면에 뜨는 '내 헬스장'이 정확히 이 값이라, 마이그레이션 전후로 보이는
    # 것이 달라지지 않는다. 회원당 active 담당은 1건(partial unique index)이므로
    # 이 SELECT 는 회원당 최대 한 행이다.
    op.execute(
        """
        INSERT INTO member_gyms (member_id, gym_id)
        SELECT tc.member_id, tp.gym_id
        FROM trainer_clients tc
        JOIN trainer_profiles tp ON tp.trainer_id = tc.trainer_id
        WHERE tc.active AND tp.gym_id IS NOT NULL
        ON CONFLICT (member_id) DO NOTHING
        """
    )


def downgrade() -> None:
    op.drop_index("ix_member_gyms_gym_id", table_name="member_gyms")
    op.drop_table("member_gyms")
