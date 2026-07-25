"""트레이너 서비스 배치 쿼리 — 리뷰 반영(#250).

_latest_by_member 가 회원당 최신 1건만 DB 에서 반환하는지(반환 행 수가 메시지 수가
아니라 회원 수에 비례) 검증한다. DB 필요(로컬 skip, CI 실행).
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone


def test_latest_by_member_returns_one_row_per_member(client, db_session):
    from app.db.seed_trainer import TRAINER_ID
    from app.models.models import ChatMessage
    from app.services.trainer_service import _latest_by_member

    # user-jisu 스레드에 메시지 5건을 서로 다른 시각으로 삽입(오래된 것 다수)
    base = datetime.now(timezone.utc) - timedelta(hours=5)
    ids = [f"chat-test-{i}" for i in range(5)]
    for i, cid in enumerate(ids):
        db_session.add(ChatMessage(
            id=cid, trainer_id=TRAINER_ID, member_id="user-jisu",
            sender="member", body=f"msg{i}", created_at=base + timedelta(minutes=i),
        ))
    db_session.commit()
    try:
        latest = _latest_by_member(
            db_session, ChatMessage, TRAINER_ID,
            ["user-jisu", "user-demo", "user-sungho"],
        )
        # 반환 행 수는 회원 수 이하(메시지 5건이어도) — 회원당 최신 1건만
        assert len(latest) <= 3
        assert "user-jisu" in latest
        # 최신(msg4)이 선택됨
        assert latest["user-jisu"].body == "msg4"
    finally:
        db_session.query(ChatMessage).filter(
            ChatMessage.id.in_(ids)
        ).delete(synchronize_session=False)
        db_session.commit()
