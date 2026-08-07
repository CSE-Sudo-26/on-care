"""헬스장 프로필 테이블 + 트레이너 소속 헬스장 FK

회원앱의 헬스장·트레이너 디렉터리가 전부 프론트 하드코딩(`MockGymRepository`)이었다.
실 백엔드를 세우기 위한 스키마다. (#324, #301)

헬스장 저장소로 `places` 를 재사용한다 — 새 테이블을 만들지 않는 이유:
`consultation_service._validate_target()` 이 이미 상담 대상 헬스장을
`places`(category='fitness') 에서 검증하고, `/places/nearby` 도 같은 테이블을 쓴다.
헬스장 엔티티를 따로 만들면 그 두 곳을 함께 바꿔야 한다.

다만 평점·영업시간·전화·태그·제휴여부를 `places` 에 직접 넣으면 병원·약국·건강식이
공유하는 테이블이 오염된다. `trainer_profiles` 가 `users` 를 확장하듯 `gym_profiles`
로 1:1 확장한다.

`trainer_profiles` 의 헬스장 정보는 `gym_name`/`gym_address`/`gym_hours`/`gym_phone`
문자열 4개로 비정규화돼 있어 한 헬스장에 여러 트레이너를 묶을 수 없었다. `gym_id` FK 를
추가한다. 기존 문자열 컬럼은 트레이너 앱이 아직 읽고 있으므로 이번엔 남겨 두고,
`gym_id` 가 있으면 그쪽을 우선하도록 서비스에서 처리한다.

Revision ID: 0020_gym_profiles_trainer_fk
Revises: 0019_trainer_noti_settings
Create Date: 2026-08-07
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0020_gym_profiles_trainer_fk"
down_revision: str | Sequence[str] | None = "0019_trainer_noti_settings"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "gym_profiles",
        # places.id 를 그대로 PK 로 쓴다 — 1:1 확장이라 대리키가 필요 없고,
        # 조인 없이도 헬스장 id 하나로 양쪽을 다룰 수 있다.
        sa.Column(
            "place_id",
            sa.String(length=64),
            sa.ForeignKey("places.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        # 카카오 Local 은 평점을 주지 않는다. 제휴 헬스장만 값이 있고, 발견된
        # 헬스장은 NULL 로 남아 UI 가 뱃지를 감춘다.
        sa.Column("rating", sa.Float(), nullable=True),
        sa.Column("weekday_hours", sa.String(length=50), nullable=False, server_default=""),
        sa.Column("weekend_hours", sa.String(length=50), nullable=False, server_default=""),
        sa.Column("phone", sa.String(length=20), nullable=False, server_default=""),
        # ["다이어트", "재활운동"] — 개수가 적고 검색 대상이 아니라 JSON 문자열로 둔다.
        sa.Column("tags_json", sa.Text(), nullable=False, server_default="[]"),
        # 제휴 헬스장만 트레이너 연결·상담이 가능하다. 카카오에서 발견한 곳과 구분한다.
        sa.Column(
            "is_partner", sa.Boolean(), nullable=False, server_default=sa.false()
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    # 제휴 헬스장 목록 조회가 가장 잦은 질의다.
    op.create_index(
        "ix_gym_profiles_is_partner", "gym_profiles", ["is_partner"]
    )

    op.add_column(
        "trainer_profiles",
        sa.Column("gym_id", sa.String(length=64), nullable=True),
    )
    op.create_foreign_key(
        "fk_trainer_profiles_gym_id_places",
        "trainer_profiles",
        "places",
        ["gym_id"],
        ["id"],
        # 헬스장이 사라져도 트레이너 계정은 남아야 한다 — 소속만 비운다.
        ondelete="SET NULL",
    )
    # "이 헬스장 소속 트레이너 전원" 조회가 헬스장 상세의 핵심 질의다.
    op.create_index(
        "ix_trainer_profiles_gym_id", "trainer_profiles", ["gym_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_trainer_profiles_gym_id", table_name="trainer_profiles")
    op.drop_constraint(
        "fk_trainer_profiles_gym_id_places", "trainer_profiles", type_="foreignkey"
    )
    op.drop_column("trainer_profiles", "gym_id")
    op.drop_index("ix_gym_profiles_is_partner", table_name="gym_profiles")
    op.drop_table("gym_profiles")
