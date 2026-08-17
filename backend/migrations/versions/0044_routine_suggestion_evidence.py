"""Carry the data a suggestion was derived from, so the trainer can judge it.

AI 개인운동 제안을 승인할지 말지는 "추천 이유" 한 줄로 갈린다(#790). 그런데
이유 문구만으로는 **무엇을 보고 그렇게 판단했는지**가 빠진다 — 트레이너가
알고 있는 부상·회복 상태와 맞춰 보려면 근거가 된 데이터가 짧게라도 보여야
한다(`최근 PT 피드백 반영`, `혈압 관리 목표`).

이유(`reason`)와 나눠 두는 까닭: 이유는 회원에게 그대로 전달되는 문구이고,
근거는 트레이너의 판단 재료다. 한 필드에 이어 붙이면 승인 즉시 회원 화면에
`최근 근력운동 비중 높음` 같은 내부 판단이 함께 나간다.

기존 행은 빈 목록이다 — 지금까지의 배정에는 근거를 모아 둔 적이 없고, 빈
목록은 화면에서 근거 줄이 아예 나오지 않는 것과 같다.

Revision ID: 0044_routine_suggestion_evidence
Revises: 0043_routine_without_trainer
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0044_routine_suggestion_evidence"
down_revision: str | Sequence[str] | None = "0043_routine_without_trainer"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # server_default 가 있어야 이미 있는 행이 NOT NULL 을 만족한다.
    # `exercises_json` 과 같은 방식(Text + '[]')이다 — 근거는 짧은 문자열
    # 목록이고, 개수·문구가 늘 바뀌므로 컬럼으로 펼치지 않는다.
    op.add_column(
        "trainer_routines",
        sa.Column(
            "evidence_json",
            sa.Text(),
            nullable=False,
            server_default="[]",
        ),
    )


def downgrade() -> None:
    op.drop_column("trainer_routines", "evidence_json")
