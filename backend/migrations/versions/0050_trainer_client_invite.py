"""Let a trainer ask a member to become their client.

지금까지 담당 관계가 생기는 경로는 하나뿐이었다 — 회원이 상담을 요청하고
트레이너가 수락한다. 그래서 센터에서 먼저 등록·결제를 마친 회원을 트레이너가
콘솔에서 잡을 방법이 없었고, 트레이너 웹의 명단 추가 UI 는 데모에서만 살아
있었다(#919).

방향만 뒤집힌 요청이지만 `consultation_requests` 에 합치지 않는다. 그 표의
운동 목표·건강 목적·희망 일시는 **회원이 채우는 값**이라, 트레이너가 보내는
요청에서는 영영 비어 있는 컬럼이 된다.

대기 중인 요청만 (trainer, member) 유일 — 거절당한 뒤 다시 보내는 것은 막지
않는다. 사람 사이의 일이라 한 번의 거절이 영구 차단일 이유가 없다.

Revision ID: 0050_trainer_client_invite
Revises: 0049_schedule_series
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0050_trainer_client_invite"
down_revision: str | Sequence[str] | None = "0049_schedule_series"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "trainer_client_invites",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column(
            "trainer_id",
            sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "member_id",
            sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("message", sa.Text(), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column("decided_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint(
            "status IN ('pending', 'accepted', 'rejected', 'cancelled')",
            name="ck_trainer_client_invite_status",
        ),
    )
    op.create_index(
        "ix_trainer_client_invites_trainer_id",
        "trainer_client_invites",
        ["trainer_id"],
    )
    op.create_index(
        "ix_trainer_client_invites_member_id",
        "trainer_client_invites",
        ["member_id"],
    )
    # 회원 앱이 읽는 질의 그대로 — 나에게 온 대기 중인 요청.
    op.create_index(
        "ix_trainer_client_invites_member_status",
        "trainer_client_invites",
        ["member_id", "status"],
    )
    op.create_index(
        "uq_trainer_client_invite_pending",
        "trainer_client_invites",
        ["trainer_id", "member_id"],
        unique=True,
        postgresql_where=sa.text("status = 'pending'"),
    )


def downgrade() -> None:
    op.drop_index(
        "uq_trainer_client_invite_pending", table_name="trainer_client_invites"
    )
    op.drop_index(
        "ix_trainer_client_invites_member_status",
        table_name="trainer_client_invites",
    )
    op.drop_index(
        "ix_trainer_client_invites_member_id", table_name="trainer_client_invites"
    )
    op.drop_index(
        "ix_trainer_client_invites_trainer_id", table_name="trainer_client_invites"
    )
    op.drop_table("trainer_client_invites")
