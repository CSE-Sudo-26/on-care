"""운동 기록의 논리 운동일. (#1264)

고객 앱이 보는 날짜(`week_start + day_label`)가 기준이다. `created_at` 은 DB
적재 시각이라, 과거 기록을 다시 시드하면 몇 주 전 운동도 방금 만든 행이 된다.

DB 없이 도는 순수 규칙 테스트다.
"""
from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from app.core import clock
from app.services import exercise_activity as activity


class _Row:
    """필요한 필드만 든 가짜 행 — 모델을 만들지 않고 규칙만 본다."""

    def __init__(self, **fields):
        self.week_start = fields.get("week_start")
        self.day_label = fields.get("day_label")
        self.completed_at = fields.get("completed_at")
        self.created_at = fields.get("created_at")


def test_week_start_and_day_label_win():
    row = _Row(
        week_start="2026-08-17",  # 월요일
        day_label="목",
        # 적재는 3주 뒤에 됐다 — 그래도 운동한 날은 8/20 이다.
        completed_at=datetime(2026, 9, 10, 3, 0, tzinfo=timezone.utc),
        created_at=datetime(2026, 9, 10, 3, 0, tzinfo=timezone.utc),
    )
    assert activity.activity_date_of(row) == date(2026, 8, 20)


def test_falls_back_to_completed_at_then_created_at():
    completed = _Row(
        week_start="깨진값",
        day_label="목",
        completed_at=datetime(2026, 8, 20, 9, 0, tzinfo=timezone.utc),
        created_at=datetime(2026, 9, 1, 9, 0, tzinfo=timezone.utc),
    )
    assert activity.activity_date_of(completed) == date(2026, 8, 20)

    created_only = _Row(
        week_start=None,
        day_label=None,
        created_at=datetime(2026, 8, 20, 9, 0, tzinfo=timezone.utc),
    )
    assert activity.activity_date_of(created_only) == date(2026, 8, 20)


def test_unknown_date_is_none_not_today():
    # 모르는 행을 오늘로 떨어뜨리면 기간 집계가 조용히 부푼다.
    assert activity.activity_date_of(_Row()) is None
    assert activity.activity_date_of(_Row(week_start="2026-08-17")) is None
    assert (
        activity.activity_date_of(_Row(week_start="2026-08-17", day_label="X"))
        is None
    )


def test_fallback_reads_the_timestamp_in_kst():
    # UTC 로 8/20 15:30 은 KST 로 8/21 00:30 이다. 서버 타임존을 따라가면
    # 하루가 밀린다(#557 과 같은 함정).
    row = _Row(completed_at=datetime(2026, 8, 20, 15, 30, tzinfo=timezone.utc))
    assert activity.activity_date_of(row) == date(2026, 8, 21)
    assert activity.noon(date(2026, 8, 21)).tzinfo is clock.SEOUL


def test_recent_window_counts_today_in():
    start, end = activity.recent_window(14, today=date(2026, 8, 20))
    assert end == date(2026, 8, 20)
    assert start == date(2026, 8, 7)
    # 오늘 포함 정확히 14개 날짜다.
    assert (end - start).days + 1 == 14

    window = (start, end)
    assert activity.in_window(date(2026, 8, 7), window)
    assert activity.in_window(date(2026, 8, 20), window)
    assert not activity.in_window(date(2026, 8, 6), window)
    assert not activity.in_window(date(2026, 8, 21), window)
    assert not activity.in_window(None, window)


def test_week_starts_cover_month_year_and_leap_boundaries():
    # 해가 바뀌는 구간.
    assert activity.week_starts_covering(
        date(2026, 12, 28), date(2027, 1, 4)
    ) == ["2026-12-28", "2027-01-04"]

    # 윤년 2월 29일이 있는 주.
    assert "2028-02-28" in activity.week_starts_covering(
        date(2028, 2, 29), date(2028, 2, 29)
    )

    # 14일 구간은 언제 시작해도 세 주를 넘지 않는다.
    for offset in range(370):
        end = date(2026, 1, 1) + timedelta(days=offset)
        start = end - timedelta(days=13)
        weeks = activity.week_starts_covering(start, end)
        assert 2 <= len(weeks) <= 3
        assert weeks == sorted(weeks)
