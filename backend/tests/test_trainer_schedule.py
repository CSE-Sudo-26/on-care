"""트레이너 스케줄 CRUD + 예약→수업→기록 완료 루프(#252). DB 필요."""
from __future__ import annotations

import pytest


def _tok(client) -> str:
    return client.post(
        "/v1/auth/login",
        data={"username": "trainer@oncare.com", "password": "oncare123"},
    ).json()["access_token"]


def _h(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _today() -> str:
    from datetime import date
    return date.today().isoformat()


def test_schedule_seeded_timeline(client):
    token = _tok(client)
    r = client.get("/v1/trainer/schedule", headers=_h(token))
    assert r.status_code == 200, r.text
    slots = r.json()
    assert len(slots) >= 6
    # 시간순 정렬
    times = [s["time"] for s in slots]
    assert times == sorted(times)
    # 공백 슬롯 + program 포함 슬롯 존재
    assert any(s["status"] == "공백" for s in slots)
    assert any(len(s["program"]) > 0 for s in slots)


def test_schedule_crud(client):
    token = _tok(client)
    # 생성(예정)
    c = client.post(
        "/v1/trainer/schedule",
        json={
            "date": _today(), "time": "16:00", "client_name": "이지수",
            "member_id": "user-jisu", "type": "1:1 PT", "duration_minutes": 45,
            "program": [{"name": "스쿼트", "sets": 3, "reps": "10회", "weight": "40kg"}],
        },
        headers=_h(token),
    )
    assert c.status_code == 201, c.text
    sid = c.json()["id"]
    assert c.json()["status"] == "예정"

    # 수정
    u = client.put(
        f"/v1/trainer/schedule/{sid}",
        json={"time": "16:30", "duration_minutes": 50},
        headers=_h(token),
    )
    assert u.status_code == 200, u.text
    assert u.json()["time"] == "16:30"
    assert u.json()["duration_minutes"] == 50

    # 삭제
    d = client.delete(f"/v1/trainer/schedule/{sid}", headers=_h(token))
    assert d.status_code == 200
    # 삭제 후 다시 삭제 → 404
    assert client.delete(f"/v1/trainer/schedule/{sid}", headers=_h(token)).status_code == 404


def test_schedule_update_member_id_empty_unassigns(client, db_session):
    """빈 member_id 로 수정하면 실제로 member_id IS NULL 로 저장되고(FK 위반 500 아님),
    이후 완료해도 배정이 없으므로 회원 운동기록(sched-hist-{sid})이 생성되지 않는다."""
    from app.models import models

    token = _tok(client)
    c = client.post(
        "/v1/trainer/schedule",
        json={
            "date": _today(), "time": "16:45", "client_name": "이지수",
            "member_id": "user-jisu", "type": "1:1 PT", "duration_minutes": 40,
        },
        headers=_h(token),
    )
    sid = c.json()["id"]

    # 빈 member_id 로 수정 → 200, 그리고 DB 에 실제로 NULL 로 저장(빈 값 무시하고 유지하면 실패)
    u = client.put(
        f"/v1/trainer/schedule/{sid}", json={"member_id": ""}, headers=_h(token)
    )
    assert u.status_code == 200, u.text
    db_session.expire_all()
    assert db_session.get(models.TrainerSchedule, sid).member_id is None

    # 완료해도 배정된 회원이 없으므로 운동기록이 만들어지지 않는다
    done = client.post(f"/v1/trainer/schedule/{sid}/complete", json={}, headers=_h(token))
    assert done.status_code == 200
    db_session.expire_all()
    assert db_session.get(models.RoutineHistory, f"sched-hist-{sid}") is None

    client.delete(f"/v1/trainer/schedule/{sid}", headers=_h(token))


@pytest.mark.parametrize(
    "field",
    ["time", "client_name", "type", "duration_minutes", "note", "program"],
)
def test_schedule_update_rejects_null_for_non_nullable_fields(client, field):
    """명시적 null이 NOT NULL 컬럼까지 도달해 500을 만들지 않고 API 경계에서 422가 된다."""
    token = _tok(client)
    c = client.post(
        "/v1/trainer/schedule",
        json={
            "date": _today(),
            "time": "16:50",
            "client_name": "이지수",
            "member_id": "user-jisu",
            "type": "1:1 PT",
            "duration_minutes": 40,
        },
        headers=_h(token),
    )
    assert c.status_code == 201, c.text

    r = client.put(
        f"/v1/trainer/schedule/{c.json()['id']}",
        json={field: None},
        headers=_h(token),
    )
    assert r.status_code == 422, r.text


def test_delete_completed_session_removes_derived_history(client, db_session):
    """완료 세션을 삭제하면 완료 시 파생된 운동기록(sched-hist-{id})도 함께 제거되어
    회원 이력에 고아 레코드가 남지 않는다."""
    from app.models import models

    token = _tok(client)
    c = client.post(
        "/v1/trainer/schedule",
        json={
            "date": _today(), "time": "07:15", "client_name": "이지수",
            "member_id": "user-jisu", "type": "1:1 PT",
            "program": [{"name": "스쿼트", "sets": 3, "reps": "10회", "weight": "40kg"}],
        },
        headers=_h(token),
    )
    sid = c.json()["id"]
    client.post(f"/v1/trainer/schedule/{sid}/complete", json={"note": "완료"}, headers=_h(token))
    db_session.expire_all()
    assert db_session.get(models.RoutineHistory, f"sched-hist-{sid}") is not None

    d = client.delete(f"/v1/trainer/schedule/{sid}", headers=_h(token))
    assert d.status_code == 200
    db_session.expire_all()
    assert db_session.get(models.RoutineHistory, f"sched-hist-{sid}") is None  # 고아 없음


def test_schedule_create_with_unlinked_member_404(client):
    token = _tok(client)
    r = client.post(
        "/v1/trainer/schedule",
        json={"date": _today(), "time": "11:00", "member_id": "user-nobody"},
        headers=_h(token),
    )
    assert r.status_code == 404


def test_complete_session_logs_history_and_is_idempotent(client):
    token = _tok(client)
    # 오늘 예정 세션 생성(user-jisu 매칭)
    c = client.post(
        "/v1/trainer/schedule",
        json={
            "date": _today(), "time": "18:30", "client_name": "이지수",
            "member_id": "user-jisu", "type": "1:1 PT", "duration_minutes": 40,
            "program": [
                {"name": "레그프레스", "sets": 3, "reps": "12회", "weight": "80kg"},
                {"name": "카프레이즈", "sets": 1, "reps": "20회", "weight": "-"},
            ],
        },
        headers=_h(token),
    )
    sid = c.json()["id"]

    before = client.get("/v1/trainer/clients/user-jisu/history", headers=_h(token)).json()
    n_before = len(before)

    # 완료 처리 → 완료 상태 + 운동기록 1건 추가
    done = client.post(
        f"/v1/trainer/schedule/{sid}/complete",
        json={"note": "잘 마쳤어요"}, headers=_h(token),
    )
    assert done.status_code == 200, done.text
    assert done.json()["status"] == "완료"

    after = client.get("/v1/trainer/clients/user-jisu/history", headers=_h(token)).json()
    assert len(after) == n_before + 1
    assert after[0]["label"] == "PT 세션 · 트레이너 지도"
    assert after[0]["trainer_note"] == "잘 마쳤어요"
    assert "레그프레스 3세트" in after[0]["exercises"]

    # 재호출(멱등) → 상태 유지, 기록 중복 없음
    again = client.post(
        f"/v1/trainer/schedule/{sid}/complete", json={"note": "x"}, headers=_h(token)
    )
    assert again.status_code == 200
    after2 = client.get("/v1/trainer/clients/user-jisu/history", headers=_h(token)).json()
    assert len(after2) == n_before + 1  # 중복 기록 없음


def test_complete_future_session_rejected(client):
    from datetime import date, timedelta

    token = _tok(client)
    future = (date.today() + timedelta(days=3)).isoformat()
    c = client.post(
        "/v1/trainer/schedule",
        json={"date": future, "time": "10:00", "member_id": "user-jisu", "type": "1:1 PT"},
        headers=_h(token),
    )
    sid = c.json()["id"]
    r = client.post(f"/v1/trainer/schedule/{sid}/complete", json={}, headers=_h(token))
    assert r.status_code == 400  # 미래 일정 완료 불가


def test_schedule_ownership_and_role(client):
    token = _tok(client)
    # 없는 일정 완료/수정 → 404
    assert client.post(
        "/v1/trainer/schedule/nope/complete", json={}, headers=_h(token)
    ).status_code == 404
    assert client.put(
        "/v1/trainer/schedule/nope", json={"time": "09:00"}, headers=_h(token)
    ).status_code == 404

    # 회원 계정 → 403
    from uuid import uuid4
    email = f"m-{uuid4().hex[:8]}@oncare.com"
    client.post("/v1/auth/register", json={"email": email, "password": "pw!", "name": "u"})
    mtok = client.post(
        "/v1/auth/login", data={"username": email, "password": "pw!"}
    ).json()["access_token"]
    assert client.get("/v1/trainer/schedule", headers=_h(mtok)).status_code == 403


def test_booked_dates(client):
    token = _tok(client)
    r = client.get("/v1/trainer/schedule/booked-dates", headers=_h(token))
    assert r.status_code == 200, r.text
    dates = r.json()
    assert _today() in dates  # 오늘 시드에 예약(공백 아님)이 있음


def test_completed_session_cannot_be_edited(client):
    """완료된 세션 수정은 409 — 스케줄과 운동기록이 어긋나지 않게 한다(리뷰 재-#2)."""
    token = _tok(client)
    c = client.post(
        "/v1/trainer/schedule",
        json={
            "date": _today(), "time": "08:30", "client_name": "이지수",
            "member_id": "user-jisu", "type": "1:1 PT",
            "program": [{"name": "스쿼트", "sets": 3, "reps": "10회", "weight": "40kg"}],
        },
        headers=_h(token),
    )
    sid = c.json()["id"]
    client.post(f"/v1/trainer/schedule/{sid}/complete", json={"note": "완료"}, headers=_h(token))

    # 완료 후 다른 회원으로 재배정 시도 → 409(데이터 분리 방지)
    r = client.put(
        f"/v1/trainer/schedule/{sid}", json={"member_id": "user-sungho"}, headers=_h(token)
    )
    assert r.status_code == 409
    # note 등 다른 필드 수정도 409
    assert client.put(
        f"/v1/trainer/schedule/{sid}", json={"note": "바꿈"}, headers=_h(token)
    ).status_code == 409
    # 기록은 여전히 원래 회원(user-jisu)에 남아 있고 sungho 로 옮겨가지 않았다
    jisu_hist = client.get("/v1/trainer/clients/user-jisu/history", headers=_h(token)).json()
    assert any(h["label"] == "PT 세션 · 트레이너 지도" for h in jisu_hist)


def test_schedule_invalid_date_time_422(client):
    """달력상 불가능한 날짜/시간은 create·update 모두 422(DB 저장 방지, 리뷰 재-#4)."""
    token = _tok(client)
    base = {"date": _today(), "time": "10:00", "type": "1:1 PT"}
    url = "/v1/trainer/schedule"
    # 잘못된 날짜
    assert client.post(url, json={**base, "date": "2026-99-99"}, headers=_h(token)).status_code == 422
    assert client.post(url, json={**base, "date": "2026-02-31"}, headers=_h(token)).status_code == 422
    # 잘못된/빈 시간
    assert client.post(url, json={**base, "time": "25:99"}, headers=_h(token)).status_code == 422
    assert client.post(url, json={**base, "time": ""}, headers=_h(token)).status_code == 422
    # update 도 잘못된 시간 422
    sid = client.post(url, json=base, headers=_h(token)).json()["id"]
    assert client.put(
        f"{url}/{sid}", json={"time": "99:99"}, headers=_h(token)
    ).status_code == 422


# ---- 기간·고객 조회 (#378) ----

def _sched_token(client) -> str:
    return client.post(
        "/v1/auth/login",
        data={"username": "trainer@oncare.com", "password": "oncare123"},
    ).json()["access_token"]


def _sched_auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_schedule_range_returns_every_day_in_one_request(client):
    """주 캘린더가 7일치를 한 번에 읽는다 — 하루짜리 요청 7번이 아니라."""
    token = _sched_token(client)
    made = []
    for day in ("2026-09-07", "2026-09-09", "2026-09-13"):
        r = client.post(
            "/v1/trainer/schedule",
            json={"date": day, "time": "10:00", "client_name": "범위테스트",
                  "type": "1:1 PT", "duration_minutes": 60},
            headers=_sched_auth(token),
        )
        assert r.status_code == 201, r.text
        made.append(r.json()["id"])
    try:
        r = client.get(
            "/v1/trainer/schedule",
            params={"from": "2026-09-07", "to": "2026-09-13"},
            headers=_sched_auth(token),
        )
        assert r.status_code == 200, r.text
        dates = [s["date"] for s in r.json() if s["client_name"] == "범위테스트"]
        # 경계 포함(from/to 양끝), 날짜순.
        assert dates == ["2026-09-07", "2026-09-09", "2026-09-13"]
    finally:
        for sid in made:
            client.delete(f"/v1/trainer/schedule/{sid}", headers=_sched_auth(token))


def test_schedule_range_excludes_days_outside_the_window(client):
    token = _sched_token(client)
    r = client.post(
        "/v1/trainer/schedule",
        json={"date": "2026-09-20", "time": "10:00", "client_name": "창밖",
              "type": "1:1 PT", "duration_minutes": 60},
        headers=_sched_auth(token),
    )
    sid = r.json()["id"]
    try:
        r = client.get(
            "/v1/trainer/schedule",
            params={"from": "2026-09-07", "to": "2026-09-13"},
            headers=_sched_auth(token),
        )
        assert all(s["client_name"] != "창밖" for s in r.json())
    finally:
        client.delete(f"/v1/trainer/schedule/{sid}", headers=_sched_auth(token))


def test_schedule_range_needs_both_ends(client):
    """한쪽만 오면 조용히 하루로 떨어뜨리지 않는다 — 클라이언트는 구간을
    받았다고 믿는다."""
    token = _sched_token(client)
    r = client.get(
        "/v1/trainer/schedule", params={"from": "2026-09-07"},
        headers=_sched_auth(token),
    )
    assert r.status_code == 422
    r = client.get(
        "/v1/trainer/schedule", params={"to": "2026-09-13"},
        headers=_sched_auth(token),
    )
    assert r.status_code == 422


def test_schedule_range_rejects_reversed_and_malformed_bounds(client):
    token = _sched_token(client)
    r = client.get(
        "/v1/trainer/schedule",
        params={"from": "2026-09-13", "to": "2026-09-07"},
        headers=_sched_auth(token),
    )
    assert r.status_code == 422
    r = client.get(
        "/v1/trainer/schedule",
        params={"from": "2026-09", "to": "2026-09-13"},
        headers=_sched_auth(token),
    )
    assert r.status_code == 422


def test_schedule_member_filter_returns_only_that_clients_sessions(client):
    token = _sched_token(client)
    roster = client.get("/v1/trainer/clients", headers=_sched_auth(token)).json()
    member_id = roster[0]["id"]

    r = client.get(
        "/v1/trainer/schedule",
        params={"from": "2026-01-01", "to": "2027-01-01", "member_id": member_id},
        headers=_sched_auth(token),
    )
    assert r.status_code == 200, r.text
    # 공백 슬롯은 배정된 회원이 없으므로 자연히 빠진다.
    assert all(s["status"] != "공백" for s in r.json())


def test_schedule_member_only_returns_every_session_no_date_bound(client):
    """`member_id` 만 주면 날짜 제한 없이 그 고객의 전체 세션.

    구간으로 흉내내면 구간 밖의 오래된 세션이 조용히 빠지고, 고객 상세의
    루틴 이력은 그걸 '기록 없음' 으로 읽는다.
    """
    token = _sched_token(client)
    roster = client.get("/v1/trainer/clients", headers=_sched_auth(token)).json()
    member_id = roster[0]["id"]

    # 아주 오래된 세션 하나 — 어떤 '최근 N일' 구간에도 걸리지 않는다.
    created = client.post(
        "/v1/trainer/schedule",
        json={
            "date": "2020-01-02", "time": "07:00", "client_name": roster[0]["name"],
            "member_id": member_id, "type": "1:1 PT", "duration_minutes": 30,
        },
        headers=_sched_auth(token),
    )
    assert created.status_code == 201, created.text
    old_id = created.json()["id"]

    r = client.get(
        "/v1/trainer/schedule",
        params={"member_id": member_id},
        headers=_sched_auth(token),
    )
    assert r.status_code == 200, r.text
    ids = [s["id"] for s in r.json()]
    assert old_id in ids
    # 여전히 그 고객 것만.
    assert all(s["status"] != "공백" for s in r.json())


def test_schedule_member_filter_rejects_someone_elses_client(client):
    token = _sched_token(client)
    r = client.get(
        "/v1/trainer/schedule",
        params={"member_id": "user-nobody"},
        headers=_sched_auth(token),
    )
    assert r.status_code == 404


def test_schedule_rejects_a_malformed_date(client):
    token = _sched_token(client)
    r = client.get(
        "/v1/trainer/schedule", params={"date": "2026-09"},
        headers=_sched_auth(token),
    )
    assert r.status_code == 422
