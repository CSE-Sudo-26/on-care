"""서비스 기준 시각이 서버 타임존과 무관하게 KST 인지 — DB 불필요 (#557).

배포 이미지(`python:3.12-slim`)의 기본 타임존은 UTC 다. 서버 로컬 시간을 쓰면
KST 00:00~09:00 사이에 서비스가 판단하는 '오늘'이 하루 전이 되어, 아침에 기록한
식사가 전날 식단으로 들어가고 '오늘/어제' 라벨이 밀린다. 이 테스트는 프로세스
타임존을 UTC 로 바꿔 놓고도 도메인 날짜가 KST 를 따르는지 고정한다.
"""
from __future__ import annotations

import os
import time
from datetime import datetime, timedelta, timezone

import pytest

from app.core import clock

KST_OFFSET_SECONDS = 9 * 3600


@pytest.fixture
def utc_process_tz():
    """프로세스 로컬 타임존을 UTC 로 바꾼다 — 배포 컨테이너와 같은 상태."""
    if not hasattr(time, "tzset"):
        pytest.skip("tzset 을 지원하지 않는 플랫폼")
    original = os.environ.get("TZ")
    os.environ["TZ"] = "UTC"
    time.tzset()
    try:
        yield
    finally:
        if original is None:
            os.environ.pop("TZ", None)
        else:
            os.environ["TZ"] = original
        time.tzset()


def _kst_today():
    """테스트가 기대하는 KST 오늘 — clock 구현과 독립적으로 계산한다."""
    return datetime.now(timezone.utc).astimezone(clock.SEOUL).date()


def test_now_is_tz_aware_kst(utc_process_tz):
    now = clock.now()
    assert now.tzinfo is not None, "naive 시각은 서버 TZ 에 휘둘린다"
    assert now.utcoffset().total_seconds() == KST_OFFSET_SECONDS


def test_today_follows_kst_not_server_tz(utc_process_tz):
    expected = _kst_today()
    assert clock.today() == expected
    assert clock.today_iso() == expected.isoformat()


def test_kst_early_morning_is_not_previous_day():
    """KST 새벽은 UTC 로는 전날 — 하루 밀리던 구간을 고정한다."""
    # 2026-08-10 00:30 KST == 2026-08-09 15:30 UTC
    instant = datetime(2026, 8, 9, 15, 30, tzinfo=timezone.utc)
    assert instant.date().isoformat() == "2026-08-09"  # UTC 기준으로는 전날
    assert clock.to_seoul(instant).date().isoformat() == "2026-08-10"


def test_to_seoul_treats_naive_as_utc():
    """created_at 은 UTC naive 로 저장되므로 UTC 로 간주해야 한다."""
    naive = datetime(2026, 8, 9, 15, 30)
    converted = clock.to_seoul(naive)
    assert converted.date().isoformat() == "2026-08-10"
    assert converted.strftime("%H:%M") == "00:30"


def test_domain_today_helpers_use_kst(utc_process_tz):
    """서비스 계층의 '오늘'이 전부 KST 를 따르는지 — 회귀 방지."""
    from app.services import diet_service, exercise_service, trainer_service

    expected = _kst_today()
    assert diet_service.today_str() == expected.isoformat()
    assert trainer_service.today_iso() == expected.isoformat()

    monday = expected - timedelta(days=expected.weekday())
    assert exercise_service.monday_of_this_week_str() == monday.isoformat()


def test_trainer_labels_use_kst_dates():
    """채팅 시각·이력 날짜 라벨이 UTC 가 아니라 KST 로 찍힌다."""
    from app.services import trainer_service

    # 2026-08-10 00:30 KST 에 저장된 메시지(UTC naive 로 보관된 형태)
    created_at = datetime(2026, 8, 9, 15, 30)
    assert trainer_service._hhmm(created_at) == "00:30"
    assert trainer_service._local_date_iso(created_at) == "2026-08-10"
