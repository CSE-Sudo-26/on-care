"""운동 기록 추가/조회 — DB 필요(로컬 skip, CI 실행)."""
from __future__ import annotations

from uuid import uuid4


def _login(client) -> dict:
    email = f"ex-{uuid4().hex[:8]}@oncare.com"
    client.post("/v1/auth/register", json={"email": email, "password": "pw!", "name": "u"})
    token = client.post("/v1/auth/login", data={"username": email, "password": "pw!"}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_add_session_reflected_in_week(client):
    h = _login(client)
    r = client.post(
        "/v1/exercise/sessions",
        json={"type": "other", "minutes": 30, "calories": 120, "day_label": "월"},
        headers=h,
    )
    assert r.status_code == 201, r.text
    assert r.json()["type"] == "other"
    assert r.json()["minutes"] == 30

    week = client.get("/v1/exercise/weeks/current", headers=h)
    assert week.status_code == 200
    assert week.json()["total_minutes"] == 30


def test_add_session_rejects_unknown_type(client):
    h = _login(client)
    r = client.post("/v1/exercise/sessions", json={"type": "flying", "minutes": 10}, headers=h)
    assert r.status_code == 400


def test_add_session_rejects_nonpositive_minutes(client):
    h = _login(client)
    r = client.post("/v1/exercise/sessions", json={"type": "cardio", "minutes": 0}, headers=h)
    # minutes 는 스키마 제약(Field(gt=0)) 이라 FastAPI 가 422(Unprocessable) 로 거부
    assert r.status_code == 422


def test_delete_session_removes_from_week(client):
    h = _login(client)
    sid = client.post(
        "/v1/exercise/sessions",
        json={"type": "cardio", "minutes": 40, "calories": 200, "day_label": "화"},
        headers=h,
    ).json()["id"]

    d = client.delete(f"/v1/exercise/sessions/{sid}", headers=h)
    assert d.status_code == 200, d.text
    assert d.json()["status"] == "deleted"

    week = client.get("/v1/exercise/weeks/current", headers=h)
    assert week.json()["total_minutes"] == 0


def test_delete_session_404_when_missing(client):
    h = _login(client)
    r = client.delete("/v1/exercise/sessions/ex-nope", headers=h)
    assert r.status_code == 404


def test_update_session_changes_week(client):
    h = _login(client)
    sid = client.post(
        "/v1/exercise/sessions",
        json={"type": "cardio", "minutes": 30, "calories": 150, "day_label": "월"},
        headers=h,
    ).json()["id"]

    r = client.put(
        f"/v1/exercise/sessions/{sid}",
        json={"type": "strength", "minutes": 50, "calories": 250, "day_label": "화"},
        headers=h,
    )
    assert r.status_code == 200, r.text
    assert r.json()["type"] == "strength"
    assert r.json()["minutes"] == 50

    week = client.get("/v1/exercise/weeks/current", headers=h)
    assert week.json()["total_minutes"] == 50


def test_update_session_404_when_missing(client):
    h = _login(client)
    r = client.put(
        "/v1/exercise/sessions/ex-nope",
        json={"type": "cardio", "minutes": 20},
        headers=h,
    )
    assert r.status_code == 404


def test_intensity_persists_and_is_returned(client):
    h = _login(client)
    r = client.post(
        "/v1/exercise/sessions",
        json={"type": "cardio", "minutes": 30, "calories": 300, "intensity": "high", "day_label": "월"},
        headers=h,
    )
    assert r.status_code == 201, r.text
    assert r.json()["intensity"] == "high"

    week = client.get("/v1/exercise/weeks/current", headers=h)
    assert week.json()["sessions"][0]["intensity"] == "high"


def test_intensity_defaults_to_moderate_when_omitted(client):
    h = _login(client)
    r = client.post(
        "/v1/exercise/sessions",
        json={"type": "cardio", "minutes": 30, "day_label": "월"},
        headers=h,
    )
    assert r.status_code == 201, r.text
    assert r.json()["intensity"] == "moderate"


def test_add_session_rejects_unknown_intensity(client):
    h = _login(client)
    r = client.post(
        "/v1/exercise/sessions",
        json={"type": "cardio", "minutes": 10, "intensity": "extreme"},
        headers=h,
    )
    assert r.status_code == 400


def test_update_session_changes_intensity(client):
    h = _login(client)
    sid = client.post(
        "/v1/exercise/sessions",
        json={"type": "cardio", "minutes": 30, "intensity": "light", "day_label": "월"},
        headers=h,
    ).json()["id"]

    r = client.put(
        f"/v1/exercise/sessions/{sid}",
        json={"type": "cardio", "minutes": 30, "intensity": "high", "day_label": "월"},
        headers=h,
    )
    assert r.status_code == 200, r.text
    assert r.json()["intensity"] == "high"


def test_update_session_rejects_bad_type(client):
    h = _login(client)
    sid = client.post(
        "/v1/exercise/sessions",
        json={"type": "cardio", "minutes": 30, "day_label": "월"},
        headers=h,
    ).json()["id"]
    r = client.put(
        f"/v1/exercise/sessions/{sid}",
        json={"type": "flying", "minutes": 20},
        headers=h,
    )
    assert r.status_code == 400
