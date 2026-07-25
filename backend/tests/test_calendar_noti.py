"""캘린더 상세 + 알림 액션(#256). DB 필요(로컬 skip, CI 실행).

인증은 데모 폴백(토큰 없음 → user-demo 회원)을 사용한다.
"""
from __future__ import annotations

from datetime import date


def _today() -> str:
    return date.today().isoformat()


# ---- 캘린더 상세(일정 CRUD) ----

def test_schedule_event_detail_crud(client):
    # 생성
    c = client.post(
        "/v1/schedule/events",
        json={"date": _today(), "time": "09:00", "title": "혈압 측정", "category": "medication"},
    )
    assert c.status_code == 201, c.text
    eid = c.json()["id"]

    # 상세 조회
    g = client.get(f"/v1/schedule/events/{eid}")
    assert g.status_code == 200
    assert g.json()["title"] == "혈압 측정"

    # 수정(부분)
    u = client.put(f"/v1/schedule/events/{eid}", json={"time": "10:30", "title": "혈압 재측정"})
    assert u.status_code == 200
    assert u.json()["time"] == "10:30"
    assert u.json()["title"] == "혈압 재측정"
    assert u.json()["category"] == "medication"  # 미변경 필드 유지

    # 삭제 → 이후 조회 404
    d = client.delete(f"/v1/schedule/events/{eid}")
    assert d.status_code == 200
    assert client.get(f"/v1/schedule/events/{eid}").status_code == 404


def test_schedule_event_detail_not_found(client):
    assert client.get("/v1/schedule/events/nope").status_code == 404
    assert client.put("/v1/schedule/events/nope", json={"title": "x"}).status_code == 404
    assert client.delete("/v1/schedule/events/nope").status_code == 404


def test_schedule_event_input_validation(client):
    """잘못된 날짜·시간·카테고리·색상은 DB 500 이 아니라 422(리뷰 재-#4)."""
    base = {"date": _today(), "title": "검진"}
    url = "/v1/schedule/events"
    assert client.post(url, json={**base, "date": "2026-99-99"}).status_code == 422
    assert client.post(url, json={**base, "date": "2026-02-31"}).status_code == 422
    assert client.post(url, json={**base, "time": "25:99"}).status_code == 422
    assert client.post(url, json={**base, "category": "invalid"}).status_code == 422
    assert client.post(url, json={**base, "color_hex": "red"}).status_code == 422
    assert client.post(url, json={**base, "title": ""}).status_code == 422
    # 유효 입력은 201 (time 은 빈 값=종일 허용)
    ok = client.post(url, json={**base, "time": "", "category": "hospital", "color_hex": "#E0F2F7"})
    assert ok.status_code == 201
    eid = ok.json()["id"]
    # 수정도 잘못된 값 422
    assert client.put(f"{url}/{eid}", json={"time": "99:99"}).status_code == 422
    assert client.put(f"{url}/{eid}", json={"category": "nope"}).status_code == 422
    client.delete(f"{url}/{eid}")


# ---- 알림 액션 ----

def test_notification_action_derived(client):
    rows = client.get("/v1/notifications").json()
    assert len(rows) >= 1
    by_cat = {r["category"]: r for r in rows}
    # 시드: reminder / achievement / health_check → 파생 액션 존재
    if "reminder" in by_cat:
        assert by_cat["reminder"]["action"]["label"] == "기록하러 가기"
        assert by_cat["reminder"]["action"]["target"] == "vitals"
    if "health_check" in by_cat:
        assert by_cat["health_check"]["action"]["target"] == "schedule"


def test_notification_read_all_and_unread_count(client, db_session):
    from app.models.models import Notification

    db_session.add(Notification(
        id="noti-test-unread", user_id="user-demo", title="테스트 알림",
        body="본문", category="reminder", read=False,
    ))
    db_session.commit()
    try:
        assert client.get("/v1/notifications/unread-count").json()["unread"] >= 1
        marked = client.post("/v1/notifications/read-all").json()["marked_read"]
        assert marked >= 1
        assert client.get("/v1/notifications/unread-count").json()["unread"] == 0
    finally:
        db_session.query(Notification).filter(
            Notification.id == "noti-test-unread"
        ).delete()
        db_session.commit()


def test_notification_delete(client, db_session):
    from app.models.models import Notification

    db_session.add(Notification(
        id="noti-test-del", user_id="user-demo", title="삭제용", body="b",
        category="system", read=False,
    ))
    db_session.commit()
    # system 카테고리는 액션 없음(None)
    rows = client.get("/v1/notifications").json()
    target = next((r for r in rows if r["id"] == "noti-test-del"), None)
    assert target is not None
    assert target["action"] is None

    d = client.delete("/v1/notifications/noti-test-del")
    assert d.status_code == 200
    assert client.delete("/v1/notifications/noti-test-del").status_code == 404


def test_notification_action_and_delete_ownership(client, db_session):
    from uuid import uuid4

    # 다른 사용자 소유 알림은 삭제 불가(404)
    from app.models.models import Notification, User

    other = f"other-{uuid4().hex[:6]}"
    db_session.add(User(id=other, email=f"{other}@oncare.com", name="타인", role="member"))
    db_session.flush()
    db_session.add(Notification(
        id="noti-other", user_id=other, title="남의 알림", body="b",
        category="system", read=False,
    ))
    db_session.commit()
    try:
        # 데모(user-demo)로 남의 알림 삭제 시도 → 404
        assert client.delete("/v1/notifications/noti-other").status_code == 404
    finally:
        db_session.query(Notification).filter(Notification.id == "noti-other").delete()
        db_session.query(User).filter(User.id == other).delete()
        db_session.commit()
