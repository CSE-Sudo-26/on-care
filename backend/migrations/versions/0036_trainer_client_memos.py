"""Store per-client trainer memos on the server instead of browser-local storage.

Revision ID: 0036_trainer_memos
Revises: 0035_drop_consultation_gym
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0036_trainer_memos"
down_revision: str | Sequence[str] | None = "0035_drop_consultation_gym"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "trainer_client_memos",
        sa.Column("id", sa.String(length=64), primary_key=True),
        # 트레이너·회원 어느 쪽이 탈퇴해도 메모는 함께 사라진다 — 담당 관계가
        # 사라진 뒤 남은 메모는 아무도 조회할 수 없는 개인 기록이다.
        sa.Column(
            "trainer_id",
            sa.String(length=64),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "member_id",
            sa.String(length=64),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("body", sa.Text(), nullable=False, server_default=""),
        sa.Column(
            "source", sa.String(length=16), nullable=False, server_default="trainer"
        ),
        # 채팅 인사이트에서 만든 메모만 값을 갖는다. 직접 쓴 메모는 NULL 이라
        # 아래 유일 제약에 걸리지 않는다.
        sa.Column("insight_id", sa.String(length=64), nullable=True),
        sa.Column(
            "insight_kind", sa.String(length=32), nullable=False, server_default=""
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.UniqueConstraint(
            "trainer_id",
            "member_id",
            "insight_id",
            name="uq_trainer_client_memo_insight",
        ),
    )
    op.create_index(
        "ix_trainer_client_memos_trainer_id",
        "trainer_client_memos",
        ["trainer_id"],
        unique=False,
    )
    op.create_index(
        "ix_trainer_client_memos_member_id",
        "trainer_client_memos",
        ["member_id"],
        unique=False,
    )
    # 목록 조회는 항상 (트레이너, 회원) 쌍으로 좁힌다.
    op.create_index(
        "ix_trainer_client_memos_pair",
        "trainer_client_memos",
        ["trainer_id", "member_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_trainer_client_memos_pair", table_name="trainer_client_memos")
    op.drop_index(
        "ix_trainer_client_memos_member_id", table_name="trainer_client_memos"
    )
    op.drop_index(
        "ix_trainer_client_memos_trainer_id", table_name="trainer_client_memos"
    )
    op.drop_table("trainer_client_memos")
