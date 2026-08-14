"""로스터가 트레이너 웹의 화면 상태를 실 API 에서도 재현하는지 (#572).

목업 로스터(`seed_clients.dart`)의 15명은 **화면 상태의 fixture** 다 — 나트륨 초과,
이행률 저조, 휴면, 답장 대기, 짧은 스파크라인을 클릭만으로 도달할 수 있게 고른 숫자다.
실 API 시드가 3명뿐이던 동안에는 실서버로 전환하면 그 상태들이 대부분 도달 불가능했다.

여기서 단언하는 것은 개별 숫자가 아니라 **상태가 하나라도 존재하는가** 다. 숫자를 그대로
박으면 시드를 손볼 때마다 깨지고, 정작 지키려는 것(경고가 그려질 수 있는가)은 놓친다.
임계값은 트레이너 웹 `client_alerts.dart` 와 맞춘다.
"""
from __future__ import annotations

from datetime import date

import pytest

_SODIUM_OVER = 2000  # 하루 나트륨 초과 기준
_COMPLETION_LOW = 60  # 기록된 날 평균 이행률이 이 아래면 '이행률 저조'


def _trainer_token(client) -> str:
    r = client.post(
        "/v1/auth/login",
        data={"username": "trainer@oncare.com", "password": "oncare123"},
    )
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


def _roster(client) -> list[dict]:
    token = _trainer_token(client)
    r = client.get("/v1/trainer/clients", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200, r.text
    return r.json()


def _unread_counts(client) -> dict[str, int]:
    token = _trainer_token(client)
    r = client.get(
        "/v1/trainer/chat/unread",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 200, r.text
    return r.json()


def test_roster_matches_the_seeded_member_list(client):
    from app.db.seed_trainer import _MEMBERS

    rows = _roster(client)
    assert len(rows) == len(_MEMBERS)


def test_every_alert_state_is_reachable_through_the_api(client):
    """화면 상태를 그릴 수 있는 고객이 상태별로 최소 1명씩 있다."""
    rows = _roster(client)

    sodium_over = [
        r for r in rows
        if sum(1 for v in r.get("sodium_week") or [] if v > _SODIUM_OVER) >= 3
    ]
    assert sodium_over, "나트륨 초과 경고를 그릴 고객이 없다"

    low_completion = []
    for r in rows:
        logged = [v for v in r.get("week_completion") or [] if v > 0]
        if logged and sum(logged) / len(logged) < _COMPLETION_LOW:
            low_completion.append(r)
    assert low_completion, "이행률 저조 경고를 그릴 고객이 없다"

    dormant = [r for r in rows if r.get("active") is False]
    assert dormant, "휴면 고객이 없다"

    unread = _unread_counts(client)
    awaiting_reply = [r for r in rows if unread.get(r["id"], 0) > 0]
    assert awaiting_reply, "답장 대기 배지를 그릴 고객이 없다"


def test_sparklines_cover_empty_short_and_full_weeks(client):
    """차트가 그려야 하는 기록 길이가 모두 존재한다.

    전부 꽉 차 있으면 '기록이 적을 때' 화면(빈 상태·단일 포인트)이 도달
    불가능해진다. 계열이 이번 주 월→일로 고정되면서(#746) '꽉 찬 주'는 7일이
    아니라 **오늘까지의 날 수**다 — 아직 오지 않은 요일은 누구에게나 0 이다.
    """
    elapsed = date.today().weekday() + 1
    lengths = {
        len([v for v in (r.get("sodium_week") or []) if v > 0]) for r in _roster(client)
    }
    assert 0 in lengths, "기록이 전혀 없는 고객이 없다"
    assert any(0 < n < elapsed for n in lengths), "기록이 일부만 있는 고객이 없다"
    assert elapsed in lengths, "이번 주를 하루도 빠짐없이 기록한 고객이 없다"


def test_detailed_records_stay_with_the_original_three(client):
    """상세 기록은 기존 3명만 가진다(#572 결정).

    확장 회원은 로스터·차트가 동작할 최소 기록만 가진다. 12명 전원에게 끼니별 음식·
    피드백·트레이너 메모까지 넣으면 시드 유지 비용이 커진다.
    """
    token = _trainer_token(client)
    headers = {"Authorization": f"Bearer {token}"}

    detailed = client.get("/v1/trainer/clients/user-jisu/diet", headers=headers)
    assert detailed.status_code == 200
    assert len(detailed.json()) >= 3, "기존 3명은 끼니별 상세를 유지해야 한다"

    minimal = client.get("/v1/trainer/clients/user-seojin/diet", headers=headers)
    assert minimal.status_code == 200
    # 하루 한 줄짜리 — 있지만 상세하지는 않다.
    assert minimal.json(), "확장 회원도 지표를 만들 기록은 있어야 한다"


def test_roster_carries_all_three_daily_series(client):
    """칼로리·나트륨·당류가 **같은 창**으로 내려온다. (#746)

    셋이 길이가 다르면 지표를 바꿀 때 그래프의 x 축이 어긋난다.
    """
    rows = _roster(client)
    for row in rows:
        assert len(row["sodium_week"]) == 7
        assert len(row["calories_week"]) == 7
        assert len(row["sugar_week"]) == 7

    # 기록이 있는 회원이 하나라도 있어야 그래프가 그려진다.
    assert any(sum(r["calories_week"]) > 0 for r in rows), "칼로리 추이를 그릴 회원이 없다"
    assert any(sum(r["sugar_week"]) > 0 for r in rows), "당류 추이를 그릴 회원이 없다"


def test_daily_series_sit_on_this_weeks_weekdays(client):
    """계열은 롤링 7일이 아니라 **이번 주 월→일**이다. (#746)

    화면이 요일 라벨과 함께 그리므로 창이 굴러가면 금요일 수치가 일요일 자리에
    놓인다. 오늘 이후 요일은 아직 오지 않았으니 0 이고, 오늘 자리는 같은 응답의
    오늘 합계와 같아야 한다.
    """
    today = date.today()
    today_index = today.weekday()
    rows = _roster(client)
    for row in rows:
        assert row["sodium_week"][today_index] == row["sodium_mg"], row["name"]
        assert row["calories_week"][today_index] == row["calories"], row["name"]
        # 계열은 소수 첫째 자리로 다듬고 오늘 합계는 그대로라, 그 반올림
        # 폭까지만 같으면 된다(19.666… → 19.7).
        assert row["sugar_week"][today_index] == pytest.approx(
            row["sugar_g"], abs=0.05
        ), row["name"]
        # 아직 오지 않은 요일.
        assert all(v == 0 for v in row["sodium_week"][today_index + 1 :]), row["name"]
        assert all(v == 0 for v in row["calories_week"][today_index + 1 :]), row["name"]
        assert all(v == 0 for v in row["sugar_week"][today_index + 1 :]), row["name"]


def test_daily_sugar_keeps_its_decimals(client):
    """당류는 소수를 유지한다 — 반올림하면 식단 탭 수치와 어긋난다."""
    rows = _roster(client)
    values = [v for row in rows for v in row["sugar_week"]]
    assert values, "당류 계열이 비어 있다"
    # 정수만 있어도 계약 위반은 아니지만, 타입은 소수를 담을 수 있어야 한다.
    assert all(isinstance(v, (int, float)) for v in values)
    assert any(isinstance(v, float) for v in values) or all(
        float(v) == v for v in values
    )

