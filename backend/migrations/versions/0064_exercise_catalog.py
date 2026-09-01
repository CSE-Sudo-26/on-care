"""운동 종목 참조표 + 이름 해석 캐시. (#1312)

운동 이름은 지금까지 소모 칼로리에 아무 영향이 없었다. 유형·시간·강도만 보는
고정 표라 `유산소 30분` 이면 달리기든 자전거든, 회원 체중이 몇이든 같은 값이
적혔다. 식단이 이미 하는 것처럼 **수치의 근거를 참조표로 옮긴다**.

`exercise_catalog` 는 시딩 후 읽기 전용인 작은 참조표(`food_nutrients` 와 같은
성격)다. `exercise_name_matches` 는 표에 바로 붙지 않는 자유 입력을 종목으로 접은
해석의 캐시로, 같은 이름에 늘 같은 값이 나오게 한다.

두 표가 비어 있어도 저장은 실패하지 않는다 — 매칭이 없으면 예전 유형 표로
떨어진다.

Revision ID: 0064_exercise_catalog
Revises: 0063_member_pairing_codes
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0064_exercise_catalog"
down_revision: str | Sequence[str] | None = "0063_member_pairing_codes"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "exercise_catalog",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("name_norm", sa.String(100), nullable=False, server_default=""),
        sa.Column("aliases_norm", sa.Text(), nullable=False, server_default=""),
        sa.Column("type", sa.String(20), nullable=False, server_default="other"),
        sa.Column("met", sa.Float(), nullable=False, server_default="0"),
        sa.Column("source", sa.String(20), nullable=False, server_default="khpi"),
    )
    op.create_index("ix_exercise_catalog_name", "exercise_catalog", ["name"])
    op.create_index("ix_exercise_catalog_name_norm", "exercise_catalog", ["name_norm"])

    # 기존 기록은 전부 유형 평균으로 계산된 값이다 — 그렇게 표시돼야 한다.
    op.add_column(
        "exercise_sessions",
        sa.Column(
            "calorie_source",
            sa.String(20),
            nullable=False,
            server_default="estimate",
        ),
    )

    op.create_table(
        "exercise_name_matches",
        sa.Column("name_norm", sa.String(100), primary_key=True),
        sa.Column(
            "catalog_id",
            sa.Integer(),
            sa.ForeignKey("exercise_catalog.id", ondelete="CASCADE"),
            nullable=True,
        ),
        sa.Column("confidence", sa.Float(), nullable=False, server_default="0"),
        sa.Column("resolver", sa.String(20), nullable=False, server_default="ai"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_table("exercise_name_matches")
    op.drop_column("exercise_sessions", "calorie_source")
    op.drop_index("ix_exercise_catalog_name_norm", table_name="exercise_catalog")
    op.drop_index("ix_exercise_catalog_name", table_name="exercise_catalog")
    op.drop_table("exercise_catalog")
