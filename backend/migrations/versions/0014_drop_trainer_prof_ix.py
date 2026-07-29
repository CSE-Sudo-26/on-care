"""trainer_profiles: 중복 인덱스 ix_trainer_profiles_trainer_id 제거

trainer_profiles.trainer_id 는 UniqueConstraint(uq_trainer_profiles_trainer)로 이미
유니크 인덱스를 갖는다. 0012 에서 함께 만든 비유니크 ix_trainer_profiles_trainer_id 는
잉여이므로 제거한다(리뷰 #277). 모델에서도 index=True 를 뺐다.

Revision ID: 0014_drop_trainer_prof_ix
Revises: 0013_trainer_active_coach_uq
Create Date: 2026-07-29
"""
from __future__ import annotations

from collections.abc import Sequence

from alembic import op

revision: str = "0014_drop_trainer_prof_ix"
down_revision: str | Sequence[str] | None = "0013_trainer_active_coach_uq"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.drop_index("ix_trainer_profiles_trainer_id", table_name="trainer_profiles")


def downgrade() -> None:
    op.create_index(
        "ix_trainer_profiles_trainer_id", "trainer_profiles", ["trainer_id"]
    )
