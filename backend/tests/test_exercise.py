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


def test_strength_reps_persist_with_sets_and_weight(client):
    """세트·횟수·중량이 한 벌로 남는다 — 셋 중 하나만 빠져도 기록이 재현되지 않는다. (#1310)"""
    h = _login(client)
    r = client.post(
        "/v1/exercise/sessions",
        json={
            "type": "strength", "minutes": 36, "sets": 12, "reps": 10,
            "weight": 62.5, "calories": 216, "date": _day("월"),
        },
        headers=h,
    )
    assert r.status_code == 201, r.text
    body = r.json()
    assert (body["sets"], body["reps"], body["weight"]) == (12, 10, 62.5)

    week = client.get("/v1/exercise/weeks/current", headers=h).json()
    stored = next(s for s in week["sessions"] if s["id"] == body["id"])
    assert stored["reps"] == 10


def test_reps_ignored_for_non_strength_types(client):
    """유산소를 횟수로 세는 화면은 없다 — 세트와 같은 규칙이다. (#1310)"""
    h = _login(client)
    r = client.post(
        "/v1/exercise/sessions",
        json={
            "type": "cardio", "minutes": 30, "reps": 10,
            "calories": 180, "date": _day("목"),
        },
        headers=h,
    )
    assert r.status_code == 201, r.text
    assert r.json()["reps"] is None


def test_update_to_another_type_clears_reps(client):
    """근력이던 기록을 유산소로 고치면 횟수도 함께 지워진다. (#1310)"""
    h = _login(client)
    sid = client.post(
        "/v1/exercise/sessions",
        json={
            "type": "strength", "minutes": 36, "sets": 12, "reps": 10,
            "calories": 216, "date": _day("금"),
        },
        headers=h,
    ).json()["id"]

    r = client.put(
        f"/v1/exercise/sessions/{sid}",
        json={
            "type": "cardio", "minutes": 30, "reps": 10,
            "calories": 180, "date": _day("금"),
        },
        headers=h,
    )
    assert r.status_code == 200, r.text
    assert r.json()["reps"] is None


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


def test_name_and_weight_round_trip(client):
    """운동 이름과 중량이 저장·조회를 지나 그대로 돌아온다. (#1276)"""
    h = _login(client)
    r = client.post(
        "/v1/exercise/sessions",
        json={
            "type": "strength", "name": "데드리프트", "minutes": 36,
            "sets": 12, "weight": 62.5, "calories": 216, "date": _day("수"),
        },
        headers=h,
    )
    assert r.status_code == 201, r.text
    assert r.json()["name"] == "데드리프트"
    assert r.json()["weight"] == 62.5
    assert r.json()["date"] == _day("수")

    week = client.get("/v1/exercise/weeks/current", headers=h).json()
    session = week["sessions"][0]
    assert session["name"] == "데드리프트"
    assert session["weight"] == 62.5
    # 이름이 있으면 그게 이 기록의 내용이다 — 유형별 기본 문구를 지어내지 않는다.
    assert session["items"] == ["데드리프트"]


def test_weight_is_dropped_for_non_strength_types(client):
    """중량은 근력에만 남는다 — 세트와 같은 규칙이다. (#1276)"""
    h = _login(client)
    r = client.post(
        "/v1/exercise/sessions",
        json={
            "type": "cardio", "name": "러닝머신", "minutes": 30,
            "weight": 60, "calories": 270, "date": _day("목"),
        },
        headers=h,
    )
    assert r.status_code == 201, r.text
    assert r.json()["weight"] is None


def test_a_past_date_lands_in_that_week_not_this_one(client):
    """지난 날짜를 고르면 그 주에 저장된다. (#1276)

    예전에는 요일 라벨만 받고 주차는 늘 이번 주로 박아, 지난 기록을 적어도
    이번 주 집계에 들어왔다.
    """
    from datetime import date, timedelta

    h = _login(client)
    last_week = clock.today() - timedelta(days=7)
    r = client.post(
        "/v1/exercise/sessions",
        json={
            "type": "cardio", "name": "산책", "minutes": 40,
            "calories": 360, "date": last_week.isoformat(),
        },
        headers=h,
    )
    assert r.status_code == 201, r.text
    assert r.json()["date"] == last_week.isoformat()

    # 이번 주에는 잡히지 않는다.
    assert client.get(
        "/v1/exercise/weeks/current", headers=h
    ).json()["total_minutes"] == 0

    monday = last_week - timedelta(days=last_week.weekday())
    past = client.get(
        f"/v1/exercise/weeks/current?week_start={monday.isoformat()}", headers=h
    ).json()
    assert past["total_minutes"] == 40
    assert isinstance(date.fromisoformat(past["sessions"][0]["date"]), date)


def test_editing_without_a_date_keeps_the_record_where_it_was(client):
    """날짜를 주지 않은 수정은 원래 자리를 그대로 둔다. (#1276)"""
    from datetime import timedelta

    h = _login(client)
    last_week = (clock.today() - timedelta(days=7)).isoformat()
    sid = client.post(
        "/v1/exercise/sessions",
        json={
            "type": "cardio", "name": "산책", "minutes": 40,
            "calories": 360, "date": last_week,
        },
        headers=h,
    ).json()["id"]

    r = client.put(
        f"/v1/exercise/sessions/{sid}",
        json={"type": "cardio", "name": "산책", "minutes": 50, "calories": 450},
        headers=h,
    )
    assert r.status_code == 200, r.text
    assert r.json()["date"] == last_week
    assert client.get(
        "/v1/exercise/weeks/current", headers=h
    ).json()["total_minutes"] == 0
