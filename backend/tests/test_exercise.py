"""운동 기록 추가/조회 — DB 필요(로컬 skip, CI 실행)."""
from __future__ import annotations

from datetime import timedelta
from uuid import uuid4

from app.core import clock
from app.services.exercise_service import WEEKDAY_LABELS


def _day(label: str) -> str:
    """이번 주 `label` 요일의 날짜. 기록은 요일이 아니라 날짜로 보낸다(#1276)."""
    today = clock.today()
    monday = today - timedelta(days=today.weekday())
    return (monday + timedelta(days=WEEKDAY_LABELS.index(label))).isoformat()


def _login(client) -> dict:
    email = f"ex-{uuid4().hex[:8]}@oncare.com"
    client.post("/v1/auth/register", json={"email": email, "password": "pw!", "name": "u"})
    token = client.post("/v1/auth/login", data={"username": email, "password": "pw!"}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_add_session_reflected_in_week(client):
    h = _login(client)
    r = client.post(
        "/v1/exercise/sessions",
        json={"type": "other", "minutes": 30, "calories": 120, "date": _day("월")},
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
    # type 은 스키마의 Literal 이라 라우터에 닿기 전에 422 로 걸린다 (#1276)
    assert r.status_code == 422


def test_add_session_rejects_nonpositive_minutes(client):
    h = _login(client)
    r = client.post("/v1/exercise/sessions", json={"type": "cardio", "minutes": 0}, headers=h)
    # minutes 는 스키마 제약(Field(gt=0)) 이라 FastAPI 가 422(Unprocessable) 로 거부
    assert r.status_code == 422


def test_delete_session_removes_from_week(client):
    h = _login(client)
    sid = client.post(
        "/v1/exercise/sessions",
        json={"type": "cardio", "minutes": 40, "calories": 200, "date": _day("화")},
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
        json={"type": "cardio", "minutes": 30, "calories": 150, "date": _day("월")},
        headers=h,
    ).json()["id"]

    r = client.put(
        f"/v1/exercise/sessions/{sid}",
        json={"type": "strength", "minutes": 50, "calories": 250, "date": _day("화")},
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
        json={"type": "cardio", "minutes": 30, "calories": 300, "intensity": "high", "date": _day("월")},
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
        json={"type": "cardio", "minutes": 30, "date": _day("월")},
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
    # intensity 도 Literal 이라 스키마 단계에서 422 다 (#1276)
    assert r.status_code == 422


def test_update_session_changes_intensity(client):
    h = _login(client)
    sid = client.post(
        "/v1/exercise/sessions",
        json={"type": "cardio", "minutes": 30, "intensity": "light", "date": _day("월")},
        headers=h,
    ).json()["id"]

    r = client.put(
        f"/v1/exercise/sessions/{sid}",
        json={"type": "cardio", "minutes": 30, "intensity": "high", "date": _day("월")},
        headers=h,
    )
    assert r.status_code == 200, r.text
    assert r.json()["intensity"] == "high"


def test_update_session_rejects_bad_type(client):
    h = _login(client)
    sid = client.post(
        "/v1/exercise/sessions",
        json={"type": "cardio", "minutes": 30, "date": _day("월")},
        headers=h,
    ).json()["id"]
    r = client.put(
        f"/v1/exercise/sessions/{sid}",
        json={"type": "flying", "minutes": 20},
        headers=h,
    )
    assert r.status_code == 422


def test_week_start_query_returns_that_week(client):
    """`week_start` 로 지난 주를 조회한다 (#671).

    앱이 지난 날짜를 고르면 그 주를 받아 하루치를 그린다. 파라미터가 없던 때는
    조회가 이번 주 하나뿐이라 지난 기록을 볼 방법이 없었다.
    """
    from datetime import date, timedelta

    from app.services.exercise_service import monday_of_this_week_str

    h = _login(client)
    client.post(
        "/v1/exercise/sessions",
        json={"type": "cardio", "minutes": 30, "calories": 200, "date": _day("월")},
        headers=h,
    )

    this_monday = date.fromisoformat(monday_of_this_week_str())
    last_monday = this_monday - timedelta(days=7)

    # 지난 주에는 기록이 없다 — 이번 주 값이 새어 나오면 안 된다.
    past = client.get(
        "/v1/exercise/weeks/current",
        params={"week_start": last_monday.isoformat()},
        headers=h,
    )
    assert past.status_code == 200, past.text
    assert past.json()["total_minutes"] == 0

    # 이번 주를 명시해도 파라미터 없이 부른 것과 같다.
    current = client.get(
        "/v1/exercise/weeks/current",
        params={"week_start": this_monday.isoformat()},
        headers=h,
    )
    assert current.json()["total_minutes"] == 30


def test_week_start_accepts_any_day_of_that_week(client):
    """월요일이 아닌 날짜를 줘도 그 날이 속한 주로 맞춘다."""
    from datetime import date, timedelta

    from app.services.exercise_service import monday_of_this_week_str

    h = _login(client)
    client.post(
        "/v1/exercise/sessions",
        json={"type": "cardio", "minutes": 25, "calories": 150, "date": _day("월")},
        headers=h,
    )

    thursday = date.fromisoformat(monday_of_this_week_str()) + timedelta(days=3)
    r = client.get(
        "/v1/exercise/weeks/current",
        params={"week_start": thursday.isoformat()},
        headers=h,
    )
    assert r.status_code == 200, r.text
    assert r.json()["total_minutes"] == 25


def test_week_start_rejects_malformed_date(client):
    h = _login(client)
    r = client.get(
        "/v1/exercise/weeks/current", params={"week_start": "2026-13-99"}, headers=h
    )
    assert r.status_code == 422


def test_week_start_rejects_non_iso_basic_format(client):
    """`20260810` 같은 기본 형식은 받지 않는다.

    date.fromisoformat 은 3.11 부터 이 형식도 받지만, 앱의 로컬 목업은 엄격한
    YYYY-MM-DD 만 받는다. 두 구현이 같은 요청에 다르게 답하면 안 된다.
    """
    h = _login(client)
    r = client.get(
        "/v1/exercise/weeks/current", params={"week_start": "20260810"}, headers=h
    )
    assert r.status_code == 422


def test_week_start_rejects_empty_string(client):
    h = _login(client)
    r = client.get(
        "/v1/exercise/weeks/current", params={"week_start": ""}, headers=h
    )
    assert r.status_code == 422


# --- 근력 세트 (#1262) --------------------------------------------------------


def test_strength_sets_persist_and_are_counted(client):
    """회원이 적은 세트가 기록에도 주간 집계에도 그대로 남는다."""
    h = _login(client)
    r = client.post(
        "/v1/exercise/sessions",
        json={
            "type": "strength", "minutes": 36, "sets": 12,
            "calories": 216, "date": _day("월"),
        },
        headers=h,
    )
    assert r.status_code == 201, r.text
    assert r.json()["sets"] == 12

    week = client.get("/v1/exercise/weeks/current", headers=h).json()
    assert week["strength_sets"][0] == 12


def test_strength_sets_derived_from_minutes_when_absent(client):
    """세트를 안 보낸 근력 기록은 분에서 환산해 센다 — 옛 기록도 같은 길이다."""
    h = _login(client)
    r = client.post(
        "/v1/exercise/sessions",
        json={"type": "strength", "minutes": 30, "calories": 180, "date": _day("화")},
        headers=h,
    )
    assert r.status_code == 201, r.text
    assert r.json()["sets"] is None

    week = client.get("/v1/exercise/weeks/current", headers=h).json()
    assert week["strength_sets"][1] == 10  # 30분 ÷ 3분


def test_sets_ignored_for_non_strength_types(client):
    """유산소를 세트로 세는 화면은 없다 — 값이 와도 기록에 남기지 않는다."""
    h = _login(client)
    r = client.post(
        "/v1/exercise/sessions",
        json={"type": "cardio", "minutes": 30, "sets": 12, "date": _day("수")},
        headers=h,
    )
    assert r.status_code == 201, r.text
    assert r.json()["sets"] is None

    week = client.get("/v1/exercise/weeks/current", headers=h).json()
    assert week["strength_sets"] == [0, 0, 0, 0, 0, 0, 0]


def test_update_session_changes_sets(client):
    h = _login(client)
    sid = client.post(
        "/v1/exercise/sessions",
        json={
            "type": "strength", "minutes": 36, "sets": 12,
            "calories": 216, "date": _day("목"),
        },
        headers=h,
    ).json()["id"]

    r = client.put(
        f"/v1/exercise/sessions/{sid}",
        json={
            "type": "strength", "minutes": 45, "sets": 15,
            "calories": 270, "date": _day("목"),
        },
        headers=h,
    )
    assert r.status_code == 200, r.text
    assert r.json()["sets"] == 15

    week = client.get("/v1/exercise/weeks/current", headers=h).json()
    assert week["strength_sets"][3] == 15


def test_update_to_another_type_clears_sets(client):
    """근력이던 기록을 유산소로 고치면 세트는 남지 않는다."""
    h = _login(client)
    sid = client.post(
        "/v1/exercise/sessions",
        json={
            "type": "strength", "minutes": 36, "sets": 12,
            "calories": 216, "date": _day("금"),
        },
        headers=h,
    ).json()["id"]

    r = client.put(
        f"/v1/exercise/sessions/{sid}",
        json={"type": "cardio", "minutes": 36, "calories": 324, "date": _day("금")},
        headers=h,
    )
    assert r.status_code == 200, r.text
    assert r.json()["sets"] is None


def test_add_session_rejects_nonpositive_sets(client):
    h = _login(client)
    r = client.post(
        "/v1/exercise/sessions",
        json={"type": "strength", "minutes": 30, "sets": 0},
        headers=h,
    )
    assert r.status_code == 422
