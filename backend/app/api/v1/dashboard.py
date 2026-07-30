"""
대시보드(홈) 라우터 — 프론트 계약 정렬.

  GET /dashboard/summary -> 홈 화면용 종합 집계

식단/운동/일정 데이터를 모아 한 번에 반환합니다.
권장 기준치(나트륨 2000mg, 당류 50g, 칼로리 2000kcal)는 고혈압·당뇨 관점 기본값.
"""
from __future__ import annotations

import json
from collections.abc import Iterable
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import CurrentUser
from app.db.session import get_db
from app.models.models import DietEntry, ExerciseSession, ScheduleEvent
from app.schemas.dashboard_api import (
    DashboardIndicator, DashboardScheduleItem, DashboardSummary,
)
from app.schemas.diet_api import calculate_macros
from app.services.exercise_service import monday_of_this_week_str

router = APIRouter(tags=["dashboard"])

# 고혈압·당뇨 관점 일일 권장 기준치
_MAX_CALORIES = 2000
_MAX_SODIUM_MG = 2000
_MAX_SUGAR_G = 50


def _build_sodium_warning(
    total_sodium_mg: int,
    source_names: list[str],
) -> str | None:
    if total_sodium_mg <= _MAX_SODIUM_MG:
        return None
    if not source_names:
        return (
            f"오늘 나트륨이 {total_sodium_mg}mg 으로 "
            f"권장량({_MAX_SODIUM_MG}mg)을 넘었어요."
        )

    top_source_names = "·".join(source_names[:2])
    return f"{top_source_names} 섭취로 나트륨이 높아요."


def _rank_sodium_sources(foods_json_values: Iterable[str]) -> list[str]:
    sodium_by_food_name: dict[str, int] = {}
    for foods_json in foods_json_values:
        try:
            foods = json.loads(foods_json)
        except (TypeError, json.JSONDecodeError):
            continue
        for food in foods if isinstance(foods, list) else []:
            if not isinstance(food, dict):
                continue
            name = str(food.get("name") or "").strip()
            sodium = food.get("sodium_mg")
            if name and isinstance(sodium, (int, float)) and sodium > 0:
                sodium_by_food_name[name] = (
                    sodium_by_food_name.get(name, 0) + int(sodium)
                )

    sodium_sources = sorted(
        sodium_by_food_name.items(),
        key=lambda item: (-item[1], item[0]),
    )
    return [name for name, _ in sodium_sources]


@router.get("/dashboard/summary", response_model=DashboardSummary)
def dashboard_summary(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> DashboardSummary:
    uid = current_user.id
    today = datetime.now().strftime("%Y-%m-%d")

    # --- 오늘 식단 집계 ---
    diet_rows = db.scalars(
        select(DietEntry).where(DietEntry.user_id == uid).where(DietEntry.date == today)
    ).all()
    total_cal = sum(r.total_calories for r in diet_rows)
    total_na = sum(r.sodium_mg for r in diet_rows)
    total_sugar = sum(r.sugar_g for r in diet_rows)
    total_carbs = sum(r.carbs_g for r in diet_rows)
    total_protein = sum(r.protein_g for r in diet_rows)
    total_fat = sum(r.fat_g for r in diet_rows)
    macros = calculate_macros(total_carbs, total_protein, total_fat)

    indicators = [
        DashboardIndicator(label="칼로리", current=total_cal, max=_MAX_CALORIES,
                           unit="kcal", over_budget=total_cal > _MAX_CALORIES),
        DashboardIndicator(label="나트륨", current=total_na, max=_MAX_SODIUM_MG,
                           unit="mg", over_budget=total_na > _MAX_SODIUM_MG),
        DashboardIndicator(label="당류", current=total_sugar, max=_MAX_SUGAR_G,
                           unit="g", over_budget=total_sugar > _MAX_SUGAR_G),
    ]
    source_names = _rank_sodium_sources(row.foods_json for row in diet_rows)
    sodium_warning = _build_sodium_warning(total_na, source_names)

    # --- 이번 주 운동 집계 ---
    week = monday_of_this_week_str()
    ex_rows = db.scalars(
        select(ExerciseSession).where(ExerciseSession.user_id == uid)
        .where(ExerciseSession.week_start == week)
    ).all()
    exercise_minutes = sum(r.minutes for r in ex_rows)
    exercise_calories = sum(r.calories for r in ex_rows)
    exercise_count = len(ex_rows)
    if exercise_minutes >= 150:
        exercise_feedback = f"이번 주 {exercise_minutes}분 운동했어요. 목표 달성 중이에요!"
    elif exercise_minutes > 0:
        exercise_feedback = f"이번 주 {exercise_minutes}분 운동했어요. 조금만 더 힘내요!"
    else:
        exercise_feedback = "이번 주 운동을 시작해 보세요. 가벼운 걷기부터 좋아요."

    # --- 오늘 일정 ---
    sched_rows = db.scalars(
        select(ScheduleEvent).where(ScheduleEvent.user_id == uid)
        .where(ScheduleEvent.date == today).order_by(ScheduleEvent.time.asc())
    ).all()
    today_schedule = [
        DashboardScheduleItem(id=s.id, time=s.time, title=s.title,
                              category=s.category, emoji=s.emoji)
        for s in sched_rows
    ]

    # --- 주간 점수 (식단 균형 + 운동량 기반 간이 점수) ---
    score = 50
    if total_na <= _MAX_SODIUM_MG:
        score += 20
    if exercise_minutes >= 150:
        score += 30
    elif exercise_minutes > 0:
        score += 15
    score = min(score, 100)

    return DashboardSummary(
        indicators=indicators,
        macros=macros,
        diet_entries=len(diet_rows),
        exercise_minutes=exercise_minutes,
        exercise_calories=exercise_calories,
        exercise_count=exercise_count,
        today_schedule=today_schedule,
        week_score=score,
        week_score_delta=5,  # 지난주 대비(추세 추적 전까지 데모 고정값)
        sodium_warning=sodium_warning,
        exercise_feedback=exercise_feedback,
    )
