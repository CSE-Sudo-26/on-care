"""회원측 트레이너 미러(#253) — 내 코치/받은 루틴/세션/양방향 채팅. DB 필요."""
from __future__ import annotations

from uuid import uuid4


def _h(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _member_tok(client) -> str:
    # user-jisu 는 시드가 demo_login_password(oncare123)로 생성 + 트레이너 링크 보유
    return client.post(
        "/v1/auth/login", data={"username": "jisu@oncare.com", "password": "oncare123"}
    ).json()["access_token"]


def _trainer_tok(client) -> str:
    return client.post(
        "/v1/auth/login", data={"username": "trainer@oncare.com", "password": "oncare123"}
    ).json()["access_token"]


def test_one_active_coach_per_member_enforced(client, db_session):
    """회원측 API 는 '현재 담당 코치 1명'을 전제하므로, 회원당 active 담당 링크는 DB
    partial unique index 로 최대 1개만 허용된다(복수 트레이너 동시 배정 방지)."""
    import pytest
    from sqlalchemy.exc import IntegrityError

    from app.models import models

    tid = f"trainer-{uuid4().hex[:8]}"
    db_session.add(models.User(
        id=tid, email=f"{tid}@oncare.com", name="T2", hashed_password="x", role="trainer",
    ))
    db_session.commit()
    try:
        # user-jisu 는 시드로 이미 active 담당(trainer-demo)이 있다. 두 번째 active 담당 추가 → 실패
        db_session.add(models.TrainerClient(
            id=f"tc-{tid}-jisu", trainer_id=tid, member_id="user-jisu", active=True,
        ))
        with pytest.raises(IntegrityError):
            db_session.commit()
        db_session.rollback()
        # 반면 휴면(active=False) 링크는 여러 개 허용된다
        db_session.add(models.TrainerClient(
            id=f"tc-{tid}-jisu", trainer_id=tid, member_id="user-jisu", active=False,
        ))
        db_session.commit()
    finally:
        db_session.rollback()
        for row in db_session.query(models.TrainerClient).filter_by(trainer_id=tid).all():
            db_session.delete(row)
        db_session.delete(db_session.get(models.User, tid))
        db_session.commit()


def test_my_coach(client):
    t = _member_tok(client)
    r = client.get("/v1/me/coach", headers=_h(t))
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["name"] == "김트레이너"
    assert body["career"] == "7년"
    assert body["gym"]["name"] == "온케어짐 신촌점"
    assert body["goal"] == "체력 강화 · 다이어트"


def test_my_routines_and_sessions(client):
    t = _member_tok(client)
    routines = client.get("/v1/me/coach/routines", headers=_h(t)).json()
    assert len(routines) >= 3
    assert all(rt["type"] in ("유산소", "근력", "스트레칭") for rt in routines)

    sessions = client.get("/v1/me/coach/sessions", headers=_h(t)).json()
    # 시드 스케줄에 이지수(user-jisu) 12:00 완료 세션이 있다
    assert any(s["status"] == "완료" for s in sessions)


def test_member_send_reflects_in_trainer_roster(client):
    mt = _member_tok(client)
    r = client.post(
        "/v1/me/coach/chat", json={"text": "코치님 오늘 운동 힘들었어요"}, headers=_h(mt)
    )
    assert r.status_code == 201, r.text
    assert r.json()["sender"] == "me"

    # 회원 스레드 마지막이 내 메시지(관점 me)
    thread = client.get("/v1/me/coach/chat", headers=_h(mt)).json()
    assert thread[-1]["sender"] == "me"
    assert thread[-1]["body"] == "코치님 오늘 운동 힘들었어요"

    # 트레이너 로스터 last_message 에 회원 발신이 반영(양방향)
    tt = _trainer_tok(client)
    roster = client.get("/v1/trainer/clients", headers=_h(tt)).json()
    jisu = next(c for c in roster if c["id"] == "user-jisu")
    assert jisu["last_message"] == "코치님 오늘 운동 힘들었어요"


def test_member_unread_and_read(client):
    tt = _trainer_tok(client)
    client.post(
        "/v1/trainer/clients/user-jisu/chat",
        json={"text": "내일 PT 잊지마세요"}, headers=_h(tt),
    )
    mt = _member_tok(client)
    u = client.get("/v1/me/coach/chat/unread", headers=_h(mt)).json()
    assert u["unread"] >= 1

    rd = client.post("/v1/me/coach/chat/read", headers=_h(mt))
    assert rd.status_code == 200
    u2 = client.get("/v1/me/coach/chat/unread", headers=_h(mt)).json()
    assert u2["unread"] == 0


def test_member_without_coach_404(client):
    email = f"m-{uuid4().hex[:8]}@oncare.com"
    client.post("/v1/auth/register", json={"email": email, "password": "pw!", "name": "u"})
    tok = client.post(
        "/v1/auth/login", data={"username": email, "password": "pw!"}
    ).json()["access_token"]
    # 담당 트레이너가 없는 회원
    assert client.get("/v1/me/coach", headers=_h(tok)).status_code == 404
    assert client.post(
        "/v1/me/coach/chat", json={"text": "hi"}, headers=_h(tok)
    ).status_code == 404
    # 받은 루틴은 빈 목록(에러 아님)
    assert client.get("/v1/me/coach/routines", headers=_h(tok)).json() == []


def test_trainer_token_rejected_on_member_coach(client):
    tt = _trainer_tok(client)
    # 회원 전용 API — 트레이너 토큰은 403(CurrentUser 가 트레이너 차단)
    assert client.get("/v1/me/coach", headers=_h(tt)).status_code == 403
    assert client.get("/v1/me/coach/routines", headers=_h(tt)).status_code == 403


def test_inactive_link_member_has_no_current_coach(client):
    """비활성(휴면) 링크만 가진 회원은 현재 담당 코치가 없다(리뷰 재-#3).

    user-sungho 는 시드가 active=False 로 생성한다(트레이너 로스터엔 휴면으로 보이지만,
    회원측 '내 코치'로는 선택되지 않아야 한다).
    """
    tok = client.post(
        "/v1/auth/login", data={"username": "sungho@oncare.com", "password": "oncare123"}
    ).json()["access_token"]
    assert client.get("/v1/me/coach", headers=_h(tok)).status_code == 404
    assert client.get("/v1/me/coach/routines", headers=_h(tok)).json() == []
    assert client.post(
        "/v1/me/coach/chat", json={"text": "안녕하세요"}, headers=_h(tok)
    ).status_code == 404
