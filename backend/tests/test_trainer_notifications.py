"""트레이너 알림함. (#503) DB 필요.

전에는 트레이너가 받은 알림을 볼 자리가 없었다. 사이드바 배지는 지금 보고 있을
때만 눈에 들어오고, 지나가면 다시 볼 수 없었다.

회원용 `/notifications` 를 쓰지 못하는 이유도 함께 확인한다 — `get_current_user`
가 트레이너 계정을 403 으로 막는 회원 전용 경로다.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest


def _login(client, email: str, password: str = "oncare123") -> str:
    res = client.post(
        "/v1/auth/login", data={"username": email, "password": password}
    )
    assert res.status_code == 200, res.text
    return res.json()["access_token"]


def _h(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture()
def trainer_token(client) -> str:
    return _login(client, "trainer@oncare.com")


def test_member_only_notifications_reject_a_trainer(client, trainer_token):
    """회원용 알림 경로는 트레이너를 막는다 — 그래서 별도 경로가 필요했다."""
    assert client.get("/v1/notifications", headers=_h(trainer_token)).status_code == 403


def test_member_message_lands_in_the_trainer_inbox(client, trainer_token):
    """회원이 보낸 메시지는 트레이너 알림함에 남는다."""
    member_token = _login(client, "jisu@oncare.com")

    text = f"안녕하세요 {uuid4().hex[:6]}"
    sent = client.post(
        "/v1/me/coach/chat", json={"text": text}, headers=_h(member_token)
    )
    assert sent.status_code == 201, sent.text

    # 총 개수가 아니라 **맨 앞 항목**을 본다. 목록은 최신순 상한이 있어, 오래
    # 돌린 DB 에서는 개수 비교가 상한에 걸려 의미를 잃는다.
    newest = client.get(
        "/v1/trainer/notifications", headers=_h(trainer_token)
    ).json()[0]
    assert newest["category"] == "message"
    assert newest["body"] == text
    assert newest["read"] is False


def test_message_notification_respects_the_trainer_setting(client, trainer_token):
    """설정에서 끄면 만들지 않는다 — 서버가 설정을 모르면 끌 수가 없다."""
    member_token = _login(client, "jisu@oncare.com")
    client.put(
        "/v1/trainer/me/settings",
        json={"notify_new_message": False},
        headers=_h(trainer_token),
    )
    try:
        text = f"꺼진 상태 {uuid4().hex[:6]}"
        client.post(
            "/v1/me/coach/chat", json={"text": text}, headers=_h(member_token)
        )
        newest = client.get(
            "/v1/trainer/notifications", headers=_h(trainer_token)
        ).json()
        # 이 메시지로 만들어진 알림이 하나도 없어야 한다.
        assert all(row["body"] != text for row in newest)
    finally:
        client.put(
            "/v1/trainer/me/settings",
            json={"notify_new_message": True},
            headers=_h(trainer_token),
        )


def test_new_reservation_lands_in_the_trainer_inbox(client, trainer_token):
    """회원이 잡은 자리를 트레이너가 스케줄을 다시 열어야만 아는 상태를 없앤다."""
    member_token = _login(client, "jisu@oncare.com")
    slot = client.post(
        "/v1/trainer/reservation-slots",
        headers=_h(trainer_token),
        json={
            "starts_at": (
                datetime.now(timezone.utc) + timedelta(days=4)
            ).isoformat(),
            "capacity": 1,
        },
    )
    assert slot.status_code == 201, slot.text

    booked = client.post(
        "/v1/reservations",
        headers=_h(member_token),
        json={"slot_id": slot.json()["id"]},
    )
    assert booked.status_code == 201, booked.text

    newest = client.get(
        "/v1/trainer/notifications", headers=_h(trainer_token)
    ).json()[0]
    assert newest["category"] == "reservation"
    assert "새 예약" in newest["title"]

    # 취소도 같은 인박스로 온다(#502 가 남기는 행).
    client.delete(
        f"/v1/reservations/{booked.json()['id']}", headers=_h(member_token)
    )
    cancelled = client.get(
        "/v1/trainer/notifications", headers=_h(trainer_token)
    ).json()[0]
    assert cancelled["category"] == "reservation"
    assert "취소" in cancelled["title"]


def test_unread_count_and_read_actions(client, trainer_token):
    member_token = _login(client, "jisu@oncare.com")
    client.post(
        "/v1/me/coach/chat",
        json={"text": f"읽음 테스트 {uuid4().hex[:6]}"},
        headers=_h(member_token),
    )

    unread = client.get(
        "/v1/trainer/notifications/unread-count", headers=_h(trainer_token)
    )
    assert unread.status_code == 200, unread.text
    assert unread.json()["unread"] >= 1

    newest = client.get(
        "/v1/trainer/notifications", headers=_h(trainer_token)
    ).json()[0]
    read = client.post(
        f"/v1/trainer/notifications/{newest['id']}/read", headers=_h(trainer_token)
    )
    assert read.status_code == 200, read.text
    assert read.json()["read"] is True

    all_read = client.post(
        "/v1/trainer/notifications/read-all", headers=_h(trainer_token)
    )
    assert all_read.status_code == 200, all_read.text
    assert (
        client.get(
            "/v1/trainer/notifications/unread-count", headers=_h(trainer_token)
        ).json()["unread"]
        == 0
    )


def test_reading_someone_elses_notification_is_404(client, trainer_token, db_session):
    """남의 알림은 존재조차 드러내지 않는다."""
    from app.models import models

    other = models.Notification(
        id=f"noti-{uuid4().hex[:12]}",
        user_id="user-jisu",
        title="회원 알림",
        body="",
        category="system",
        read=False,
    )
    db_session.add(other)
    db_session.commit()
    try:
        res = client.post(
            f"/v1/trainer/notifications/{other.id}/read", headers=_h(trainer_token)
        )
        assert res.status_code == 404
    finally:
        db_session.delete(other)
        db_session.commit()


def test_trainer_notifications_require_a_trainer(client):
    """회원 토큰으로는 트레이너 알림함을 볼 수 없다."""
    member_token = _login(client, "jisu@oncare.com")
    assert (
        client.get("/v1/trainer/notifications", headers=_h(member_token)).status_code
        == 403
    )
