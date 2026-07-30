"""대시보드 요약 집계 — DB 필요(로컬 skip, CI 실행)."""
from __future__ import annotations

import json

from sqlalchemy import delete


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
                {"name": "김치찌개", "sodium_mg": 900},
                {"name": "배추김치", "sodium_mg": 420},
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
                {"name": "오리엔탈 드레싱", "sodium_mg": 350},
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
    assert body["macros"] == {
        "carbs_g": 155.0,
        "protein_g": 81.0,
        "fat_g": 43.8,
        "carbs_pct": 46,
        "protein_pct": 24,
        "fat_pct": 30,
    }
    assert "김치찌개" in body["sodium_warning"]
    assert "배추김치" in body["sodium_warning"]
    assert isinstance(body["exercise_minutes"], int)
    assert isinstance(body["exercise_calories"], int)
    assert isinstance(body["exercise_count"], int)
