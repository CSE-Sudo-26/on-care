"""트레이너 스케줄 CRUD + 예약→수업→기록 완료 루프(#252). DB 필요."""
from __future__ import annotations


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


def test_schedule_update_member_id_empty_unassigns(client):
    """빈 member_id 로 수정하면 배정 해제(NULL)로 저장 — ""는 FK 위반 500 이 아니라 200."""
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
    # 빈 member_id 로 수정 → FK 위반 500 이 아니라 200(NULL 로 배정 해제)
    u = client.put(
        f"/v1/trainer/schedule/{sid}", json={"member_id": ""}, headers=_h(token)
    )
    assert u.status_code == 200, u.text

    # 배정 해제된 슬롯은 이후 완료해도 회원 운동기록으로 적재되지 않는다(member_id NULL)
    done = client.post(f"/v1/trainer/schedule/{sid}/complete", json={}, headers=_h(token))
    assert done.status_code == 200
    client.delete(f"/v1/trainer/schedule/{sid}", headers=_h(token))


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
