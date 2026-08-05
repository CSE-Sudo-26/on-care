"""당류 계약 정합: diet_entries.sugar_g 를 Integer → Double precision 으로

프론트는 항목 당류를 소수(double)로 다루는데 항목 단위 컬럼만 Integer 라,
실서버 경로에서 `sugar_g=8.5` 가 절삭되거나 요청이 거부됐다. 음식 단위
(`food_nutrients.sugar_g`)는 이미 Float 이라 항목 단위만 어긋나 있었다.

정수 → 실수 확대라 기존 값은 그대로 보존된다(8 → 8.0). 되돌릴 때는
`round(sugar_g)::integer` 로 변환하므로 소수 정밀도가 손실된다 — 절삭이 아니라
반올림이라 8.6 은 9 가 되고, 중간값은 은행가 반올림이라 8.5·7.5 모두 8 이 된다
(PostgreSQL 의 double precision round 는 C 라이브러리 rint 에 위임된다).

Revision ID: 0018_diet_entry_sugar_g_float
Revises: 0017_add_diet_exercise_goals
Create Date: 2026-08-05
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0018_diet_entry_sugar_g_float"
down_revision: str | Sequence[str] | None = "0017_add_diet_exercise_goals"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column(
        "diet_entries",
        "sugar_g",
        existing_type=sa.Integer(),
        type_=sa.Float(),
        existing_nullable=False,
        existing_server_default=None,
        postgresql_using="sugar_g::double precision",
    )


def downgrade() -> None:
    # 주의: 반올림이라 소수 정밀도가 사라진다(8.6 → 9, 8.5 → 8). 되돌릴 일이
    # 생기면 데이터 손실을 감수한 것.
    op.alter_column(
        "diet_entries",
        "sugar_g",
        existing_type=sa.Float(),
        type_=sa.Integer(),
        existing_nullable=False,
        existing_server_default=None,
        postgresql_using="round(sugar_g)::integer",
    )
