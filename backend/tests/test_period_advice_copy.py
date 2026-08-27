"""기간별 조언 문장의 규칙. (#1574)

확인하는 것은 세 가지다.

- 기간마다 **다른 재료를 보고 다른 말**을 하는가 (그래프만 갈리고 조언이 오늘
  이야기로 남으면 안 된다),
- 없는 기록으로 조언을 지어내지 않는가,
- **짧은가.** 카드는 회원 앱·트레이너웹 양쪽에서 좁은 폭에 들어간다 — 길어질수록
  정작 짚어 주는 수치가 묻힌다.

문장은 회원 앱의 데모 재현본(`core/demo/period_advice.dart`)과 같아야 한다. 한쪽만
고치면 데모로 본 화면과 실 연동으로 본 화면이 다른 말을 하게 된다.
"""
from __future__ import annotations

from datetime import date, timedelta

import pytest

from app.services import diet_service, exercise_service, period_window
from app.services.diet_service import DietDayTotals
from app.services.exercise_service import ExerciseDayTotals

#: 한 문장 반. 이보다 길어지면 카드가 두 줄을 넘겨 화면이 밀린다.
MAX_LEN = 45

PERIODS = (period_window.PERIOD_TODAY, period_window.PERIOD_WEEK, period_window.PERIOD_ALL)


def _diet_day(day: date, sodium: int) -> DietDayTotals:
    return DietDayTotals(date=day, calories=700, sodium_mg=sodium, sugar_g=8.0)


def _exercise_day(day: date, minutes: int = 30, kind: str = "cardio") -> ExerciseDayTotals:
    return ExerciseDayTotals(
        date=day,
        minutes=minutes,
        calories=minutes * 9,
        by_type={kind: minutes},
    )


@pytest.mark.parametrize("period", PERIODS)
def test_empty_records_get_their_own_message(period):
    """기록이 없으면 없다고 말한다. 기간별로 다른 안내다."""
    assert diet_service.period_coach_message([], period)
    assert exercise_service.period_coach_message([], period)


def test_empty_messages_differ_between_periods():
    """셋이 같은 문장이면 토글이 아무 일도 하지 않는 것처럼 보인다."""
    assert len({diet_service.period_coach_message([], p) for p in PERIODS}) == 3
    assert len({exercise_service.period_coach_message([], p) for p in PERIODS}) == 3


def test_diet_periods_look_at_different_material():
    today = date(2026, 8, 27)  # 목요일
    monday = today - timedelta(days=today.weekday())
    days = [_diet_day(monday + timedelta(days=i), 2600) for i in range(3)]
    days.append(_diet_day(today, 1200))

    day_view = diet_service.period_coach_message(days, period_window.PERIOD_TODAY)
    week = diet_service.period_coach_message(days, period_window.PERIOD_WEEK)

    # 오늘은 오늘 합계를, 이번 주는 초과한 날 수를 말한다.
    assert "1200mg" in day_view
    assert "이번 주 3일" in week
    assert day_view != week


def test_exercise_periods_look_at_different_material():
    today = date(2026, 8, 27)
    monday = today - timedelta(days=today.weekday())
    days = [_exercise_day(monday + timedelta(days=i)) for i in range(4)]

    day_view = exercise_service.period_coach_message(days, period_window.PERIOD_TODAY)
    week = exercise_service.period_coach_message(days, period_window.PERIOD_WEEK)

    assert "오늘" in day_view
    # 유산소만 한 주 — 쏠림을 먼저 짚고 다른 유형을 권한다.
    assert "유산소" in week and "근력" in week
    assert day_view != week


@pytest.mark.parametrize(
    "days",
    [
        [],
        [_diet_day(date(2026, 8, 27), 3400)],
        [_diet_day(date(2026, 8, 27), 1200)],
        [_diet_day(date(2026, 8, 24) + timedelta(days=i), 2600) for i in range(4)],
    ],
)
@pytest.mark.parametrize("period", PERIODS)
def test_diet_messages_stay_short(days, period):
    message = diet_service.period_coach_message(days, period)
    assert len(message) <= MAX_LEN, message


@pytest.mark.parametrize(
    "days",
    [
        [],
        [_exercise_day(date(2026, 8, 27), minutes=45)],
        [_exercise_day(date(2026, 8, 24) + timedelta(days=i)) for i in range(4)],
        [
            _exercise_day(date(2026, 8, 24), kind="cardio"),
            _exercise_day(date(2026, 8, 25), kind="strength"),
            _exercise_day(date(2026, 8, 26), kind="stretching"),
        ],
    ],
)
@pytest.mark.parametrize("period", PERIODS)
def test_exercise_messages_stay_short(days, period):
    message = exercise_service.period_coach_message(days, period)
    assert len(message) <= MAX_LEN, message
