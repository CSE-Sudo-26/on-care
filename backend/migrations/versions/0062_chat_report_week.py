"""채팅 메시지에 리포트 주차를 남긴다.

트레이너가 주간 리포트를 보내면 두 앱은 그 메시지를 일반 대화가 아니라 "리포트가
등록되었어요" 안내로 그린다. 지금까지 그 표시는 트레이너 앱의 로컬 데모에만
있었다 — 실서버를 거치면 리포트인지 아닌지가 사라져, 같은 사건이 데모에서는
안내로, 실제 대화에서는 파일 하나로 보였다.

첨부로는 판단할 수 없다. 리포트는 PDF 없이 본문만으로도 나가고(`/report/send`),
반대로 트레이너가 보내는 PDF 가 언제나 리포트라는 보장도 없다. 파일명에 박힌
날짜를 파내는 방법도 있지만, 그러면 화면에 보이라고 지은 문자열이 곧 로직이 된다.
보내는 쪽이 이미 알고 있는 주차를 그대로 저장한다.

일반 대화는 NULL 이다 — 이 컬럼이 생기기 전의 메시지도 마찬가지라, 예전 행은
지금까지와 똑같이 읽힌다.

Revision ID: 0062_chat_report_week
Revises: 0061_demo_member_id
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0062_chat_report_week"
down_revision: str | Sequence[str] | None = "0061_demo_member_id"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "chat_messages",
        sa.Column("report_week_start", sa.String(length=10), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("chat_messages", "report_week_start")
