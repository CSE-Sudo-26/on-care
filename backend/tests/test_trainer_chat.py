"""트레이너 채팅 + 루틴 배정(#251). DB 필요(로컬 skip, CI 실행)."""
from __future__ import annotations


def _tok(client) -> str:
    return client.post(
        "/v1/auth/login",
        data={"username": "trainer@oncare.com", "password": "oncare123"},
    ).json()["access_token"]


def _h(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_chat_thread_seeded_and_sender_mapped(client):
    token = _tok(client)
    r = client.get("/v1/trainer/clients/user-jisu/chat", headers=_h(token))
    assert r.status_code == 200, r.text
    msgs = r.json()
    assert len(msgs) >= 3
    # 오래된→최신, sender 는 trainer|client 로 노출(member→client 매핑)
    assert msgs[0]["sender"] == "trainer"
    assert any(m["sender"] == "client" for m in msgs)
    assert all(m["sender"] in ("trainer", "client") for m in msgs)


def test_send_message_reflects_in_thread_and_roster(client):
    token = _tok(client)
    r = client.post(
        "/v1/trainer/clients/user-jisu/chat",
        json={"text": "  다음 주 루틴 보냈어요!  "},
        headers=_h(token),
    )
    assert r.status_code == 201, r.text
    assert r.json()["sender"] == "trainer"
    assert r.json()["body"] == "다음 주 루틴 보냈어요!"  # trim 확인

    # 스레드 마지막에 반영
    thread = client.get("/v1/trainer/clients/user-jisu/chat", headers=_h(token)).json()
    assert thread[-1]["body"] == "다음 주 루틴 보냈어요!"

    # 로스터 last_message 가 방금 보낸 메시지로 갱신(자동 반영)
    roster = client.get("/v1/trainer/clients", headers=_h(token)).json()
    jisu = next(c for c in roster if c["id"] == "user-jisu")
    assert jisu["last_message"] == "다음 주 루틴 보냈어요!"


def test_empty_message_rejected(client):
    token = _tok(client)
    r = client.post(
        "/v1/trainer/clients/user-jisu/chat", json={"text": "   "}, headers=_h(token)
    )
    assert r.status_code == 400


def test_unread_and_mark_read(client, db_session):
    from datetime import datetime, timezone
    from uuid import uuid4

    from app.db.seed_trainer import TRAINER_ID
    from app.models.models import ChatMessage

    cid = f"chat-unreadtest-{uuid4().hex[:6]}"
    db_session.add(ChatMessage(
        id=cid, trainer_id=TRAINER_ID, member_id="user-sungho",
        sender="member", body="확인 부탁드려요", created_at=datetime.now(timezone.utc),
    ))
    db_session.commit()
    try:
        token = _tok(client)
        unread = client.get("/v1/trainer/chat/unread", headers=_h(token)).json()
        assert unread.get("user-sungho", 0) >= 1

        rd = client.post("/v1/trainer/clients/user-sungho/chat/read", headers=_h(token))
        assert rd.status_code == 200
        assert rd.json()["marked_read"] >= 1

        unread2 = client.get("/v1/trainer/chat/unread", headers=_h(token)).json()
        assert unread2.get("user-sungho", 0) == 0
    finally:
        db_session.query(ChatMessage).filter(ChatMessage.id == cid).delete()
        db_session.commit()


def test_routines_seeded_and_assign_updates_last_routine(client):
    token = _tok(client)
    # 시드된 AI 루틴
    r = client.get("/v1/trainer/clients/user-jisu/routines", headers=_h(token))
    assert r.status_code == 200, r.text
    routines = r.json()
    assert len(routines) >= 3
    assert all(rt["type"] in ("유산소", "근력", "스트레칭") for rt in routines)
    assert any(rt["source"] == "ai" for rt in routines)

    # 트레이너가 직접 배정
    a = client.post(
        "/v1/trainer/clients/user-jisu/routines",
        json={"name": "코어 서킷", "minutes": 12, "type": "근력", "reason": "복부 안정화"},
        headers=_h(token),
    )
    assert a.status_code == 201, a.text
    assert a.json()["source"] == "trainer"

    after = client.get("/v1/trainer/clients/user-jisu/routines", headers=_h(token)).json()
    assert any(rt["name"] == "코어 서킷" for rt in after)

    # 로스터 last_routine 이 "오늘"로 갱신(방금 배정)
    roster = client.get("/v1/trainer/clients", headers=_h(token)).json()
    jisu = next(c for c in roster if c["id"] == "user-jisu")
    assert jisu["last_routine"] == "오늘"


def test_chat_routine_ownership_and_role(client):
    token = _tok(client)
    # 미담당 회원 → 404
    assert client.get("/v1/trainer/clients/user-nobody/chat", headers=_h(token)).status_code == 404
    assert client.get(
        "/v1/trainer/clients/user-nobody/routines", headers=_h(token)
    ).status_code == 404

    # 회원 계정 → 403
    from uuid import uuid4
    email = f"m-{uuid4().hex[:8]}@oncare.com"
    client.post("/v1/auth/register", json={"email": email, "password": "pw!", "name": "u"})
    mtok = client.post(
        "/v1/auth/login", data={"username": email, "password": "pw!"}
    ).json()["access_token"]
    assert client.get("/v1/trainer/clients/user-jisu/chat", headers=_h(mtok)).status_code == 403


def test_routine_assign_input_validation(client):
    token = _tok(client)
    url = "/v1/trainer/clients/user-jisu/routines"
    base = {"name": "테스트 루틴", "minutes": 10, "type": "근력", "reason": "x"}
    # 잘못된 type / source → 422 (DB 500 아님)
    assert client.post(url, json={**base, "type": "파워"}, headers=_h(token)).status_code == 422
    assert client.post(url, json={**base, "source": "bot"}, headers=_h(token)).status_code == 422
    # minutes 음수/과대 → 422
    assert client.post(url, json={**base, "minutes": -5}, headers=_h(token)).status_code == 422
    assert client.post(url, json={**base, "minutes": 9999}, headers=_h(token)).status_code == 422
    # name 100자 초과 / reason 200자 초과 → 422
    assert client.post(url, json={**base, "name": "가" * 101}, headers=_h(token)).status_code == 422
    assert client.post(url, json={**base, "reason": "가" * 201}, headers=_h(token)).status_code == 422
    # 정상 입력은 201
    assert client.post(url, json=base, headers=_h(token)).status_code == 201


def test_chat_thread_is_paginated(client, db_session):
    from datetime import datetime, timedelta, timezone

    from app.db.seed_trainer import TRAINER_ID
    from app.models.models import ChatMessage

    # 오래된 메시지 60건 삽입(하루 전, 초 간격)
    base = datetime.now(timezone.utc) - timedelta(days=1)
    ids = [f"chat-page-{i}" for i in range(60)]
    for i, cid in enumerate(ids):
        db_session.add(ChatMessage(
            id=cid, trainer_id=TRAINER_ID, member_id="user-demo",
            sender="member", body=f"m{i}", created_at=base + timedelta(seconds=i),
        ))
    db_session.commit()
    try:
        token = _tok(client)
        # 기본 제한 50 이하 — 오래된 메시지가 60건 있어도 한 번에 다 오지 않는다
        msgs = client.get("/v1/trainer/clients/user-demo/chat", headers=_h(token)).json()
        assert len(msgs) <= 50
        # limit 쿼리 존중
        r10 = client.get("/v1/trainer/clients/user-demo/chat?limit=10", headers=_h(token))
        assert len(r10.json()) == 10
        # 잘못된 before → 422
        bad = client.get("/v1/trainer/clients/user-demo/chat?before=notadate", headers=_h(token))
        assert bad.status_code == 422
    finally:
        db_session.query(ChatMessage).filter(
            ChatMessage.id.in_(ids)
        ).delete(synchronize_session=False)
        db_session.commit()


def test_chat_pagination_two_pages_contiguous(client, db_session):
    """(created_at, id) 복합 커서로 연속 페이지 조회 시 중복·누락 없이 전체가 이어진다."""
    from datetime import datetime, timedelta, timezone
    from uuid import uuid4

    from app.db.seed_trainer import TRAINER_ID
    from app.models.models import ChatMessage, TrainerClient, User

    mid = f"pgmember-{uuid4().hex[:6]}"
    db_session.add(User(id=mid, email=f"{mid}@oncare.com", name="페이지회원", role="member"))
    db_session.flush()
    db_session.add(TrainerClient(
        id=f"tc-pg-{mid}", trainer_id=TRAINER_ID, member_id=mid,
        goal="x", active=True, sort_order=999,
    ))
    base = datetime(2021, 1, 1, tzinfo=timezone.utc)
    ids = [f"pgc-{mid}-{i:03d}" for i in range(60)]
    for i, cid in enumerate(ids):
        db_session.add(ChatMessage(
            id=cid, trainer_id=TRAINER_ID, member_id=mid, sender="member",
            body=f"m{i}", created_at=base + timedelta(minutes=i // 2),  # 짝수쌍은 같은 created_at
        ))
    db_session.commit()
    try:
        token = _tok(client)
        url = f"/v1/trainer/clients/{mid}/chat"
        p1 = client.get(url, params={"limit": 25}, headers=_h(token)).json()
        assert len(p1) == 25
        # 이전 페이지 커서 = 이번 페이지 가장 오래된 메시지(p1[0]) 의 (created_at, id).
        # params= 로 넘겨야 타임존 오프셋 '+' 가 올바로 인코딩된다.
        cur = p1[0]
        p2 = client.get(
            url,
            params={"limit": 25, "before": cur["created_at"], "before_id": cur["id"]},
            headers=_h(token),
        ).json()
        assert len(p2) == 25
        cur2 = p2[0]
        p3 = client.get(
            url,
            params={"limit": 25, "before": cur2["created_at"], "before_id": cur2["id"]},
            headers=_h(token),
        ).json()
        assert len(p3) == 10  # 60 = 25 + 25 + 10

        got = [m["id"] for m in p3] + [m["id"] for m in p2] + [m["id"] for m in p1]
        assert len(set(got)) == 60          # 중복 없음
        assert set(got) == set(ids)          # 누락 없음
    finally:
        db_session.query(ChatMessage).filter(ChatMessage.member_id == mid).delete()
        db_session.query(TrainerClient).filter(TrainerClient.member_id == mid).delete()
        db_session.query(User).filter(User.id == mid).delete()
        db_session.commit()
