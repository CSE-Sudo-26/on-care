"""대시보드 요약 집계."""
from __future__ import annotations

import json

import pytest
from sqlalchemy import delete

from app.api.v1.dashboard import (
    _build_sodium_warning, _rank_sodium_sources, _score_for,
)


def test_score_for_combines_sodium_and_exercise():
    assert _score_for(True, 200) == 100   # 50 + 20(나트륨) + 30(운동 150+)
    assert _score_for(True, 100) == 85    # 50 + 20 + 15(운동 1~149)
    assert _score_for(True, 0) == 70      # 50 + 20
    assert _score_for(False, 0) == 50     # 기본만


@pytest.mark.parametrize(
    ("total_sodium_mg", "source_names", "expected"),
    [
        (2000, ["라면"], None),
        (
            2100,
            [],
            "오늘 나트륨이 2100mg 으로 권장량(2000mg)을 넘었어요.",
        ),
        (2100, ["라면"], "라면 섭취로 나트륨이 높아요."),
        (2100, ["김밥", "라면"], "김밥·라면 섭취로 나트륨이 높아요."),
        (
            2100,
            ["김치찌개", "배추김치", "라면"],
            "김치찌개·배추김치 섭취로 나트륨이 높아요.",
        ),
    ],
)
def test_build_sodium_warning(
    total_sodium_mg: int,
    source_names: list[str],
    expected: str | None,
):
    assert _build_sodium_warning(total_sodium_mg, source_names) == expected


def test_rank_sodium_sources_combines_duplicate_food_names():
    foods_json_values = [
        json.dumps([
            {"name": "라면", "sodium_mg": 600},
            {"name": "김밥", "sodium_mg": 700},
        ]),
        json.dumps([
            {"name": " 라면 ", "sodium_mg": 600},
            {"name": "샐러드", "sodium_mg": 800},
        ]),
    ]

    assert _rank_sodium_sources(foods_json_values) == ["라면", "샐러드", "김밥"]


def test_dashboard_summary_includes_macros_and_sodium_sources(client, db_session):
    from app.db.init_db import DEMO_USER_ID
    from app.models.models import DietEntry
    from app.services.diet_service import today_str

    db_session.execute(
        delete(DietEntry).where(
            DietEntry.user_id == DEMO_USER_ID,
            DietEntry.date == today_str(),
        )
    )
    db_session.add_all([
        DietEntry(
            id="dashboard-lunch",
            user_id=DEMO_USER_ID,
            date=today_str(),
            meal_type="lunch",
            foods_json=json.dumps([
                {"name": "라면", "sodium_mg": 600},
                {"name": "김밥", "sodium_mg": 700},
            ]),
            total_calories=780,
            carbs_g=86,
            protein_g=40,
            fat_g=29.3,
            sodium_mg=1643,
            sugar_g=7,
        ),
        DietEntry(
            id="dashboard-dinner",
            user_id=DEMO_USER_ID,
            date=today_str(),
            meal_type="dinner",
            foods_json=json.dumps([
                {"name": "라면", "sodium_mg": 600},
                {"name": "샐러드", "sodium_mg": 800},
            ]),
            total_calories=570,
            carbs_g=69,
            protein_g=41,
            fat_g=14.5,
            sodium_mg=535,
            sugar_g=11,
        ),
    ])
    db_session.commit()

    response = client.get("/v1/dashboard/summary")

    assert response.status_code == 200
    body = response.json()
    macros = body["macros"]
    assert macros["carbs_g"] == pytest.approx(155.0)
    assert macros["protein_g"] == pytest.approx(81.0)
    assert macros["fat_g"] == pytest.approx(43.8)
    assert {
        "carbs_pct": macros["carbs_pct"],
        "protein_pct": macros["protein_pct"],
        "fat_pct": macros["fat_pct"],
    } == {
        "carbs_pct": 46,
        "protein_pct": 24,
        "fat_pct": 30,
    }
    assert body["sodium_warning"] == "라면·샐러드 섭취로 나트륨이 높아요."
    assert isinstance(body["exercise_minutes"], int)
    assert isinstance(body["exercise_calories"], int)
    assert isinstance(body["exercise_count"], int)

    # 주간 추이(이번 주 월~일 7일) + 지난 주 비교선 7일
    assert len(body["nutrition_week"]) == 7
    assert len(body["nutrition_week_prev"]) == 7
    assert [d["label"] for d in body["nutrition_week"]] == \
        ["월", "화", "수", "목", "금", "토", "일"]
    # 오늘 점심(780)+저녁(570)이 이번 주 어느 요일에 집계돼야 한다.
    assert sum(d["calories"] for d in body["nutrition_week"]) >= 1350
    # 소모 목표 필드(기본값) + 지난주 대비 변화량은 정수
    assert body["exercise_burn_goal"] == 500
    assert isinstance(body["week_score_delta"], int)
