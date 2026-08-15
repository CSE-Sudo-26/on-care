"""김민수 데모 픽스처 — 파일 자체와 백엔드 리더를 본다.

시드가 DB 에 옮긴 결과는 `test_member_seed.py` 가 본다.
"""
from __future__ import annotations

from datetime import date
from pathlib import Path

from app.db.demo_fixture import FIXTURE_PATH, load_fixture

#: Flutter 두 앱이 읽는 원본. 백엔드 이미지는 `backend/` 만 담아서 같은 파일을
#: 한 벌 더 갖고 있다 — 두 파일이 어긋나면 두 앱과 백엔드의 숫자가 갈라진다.
SHARED_PATH = (
    Path(__file__).resolve().parents[2]
    / "shared/demo_fixture/assets/kim_minsu.json"
)


def test_backend_copy_matches_the_shared_original():
    # 손으로 맞추지 말 것 — `python3 tool/gen_demo_fixture.py` 가 두 곳에 함께 쓴다.
    assert FIXTURE_PATH.read_bytes() == SHARED_PATH.read_bytes()


def test_curated_days_keep_the_numbers_the_demo_says_out_loud():
    days = load_fixture().days_for(date(2026, 8, 16))
    today, yesterday = days[-1], days[-2]

    assert (today.calories, today.sodium_mg, today.sugar_g) == (1067, 3428, 17.8)
    assert (yesterday.calories, yesterday.sodium_mg, yesterday.sugar_g) == (
        2380,
        2261,
        63.0,
    )


def test_no_day_lies_in_the_future():
    # 주중에 열어도 이번 주 남은 요일이 채워지면 주 평균이 실제보다 높아진다(#752).
    for today in (date(2026, 8, 10), date(2026, 8, 13), date(2026, 8, 16)):
        days = load_fixture().days_for(today)
        assert days[-1].day == today
        assert not [d for d in days if d.day > today]


def test_completion_comes_from_the_routine_items():
    for day in load_fixture().days_for(date(2026, 8, 16)):
        if not day.exercises:
            assert day.completion == 0
            continue
        done = sum(1 for e in day.exercises if e.done)
        assert day.completion == round(done * 100 / len(day.exercises))


def test_the_fixture_covers_twelve_weeks_without_gaps():
    fixture = load_fixture()
    days = fixture.days_for(date(2026, 8, 16))  # 일요일 → 12주가 꽉 찬다
    assert fixture.history_weeks == 12
    assert len(days) == 84
    assert len({d.iso for d in days}) == 84
