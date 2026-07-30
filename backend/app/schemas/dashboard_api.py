"""대시보드(홈) 요약 스키마 — 프론트 _dashboardSummary 계약 정렬."""
from __future__ import annotations

from typing import Optional
from pydantic import BaseModel

from app.schemas.diet_api import Macros


class DashboardIndicator(BaseModel):
    label: str            # 칼로리 | 나트륨 | 당류
    current: int
    max: int
    unit: str
    over_budget: bool = False


class DashboardScheduleItem(BaseModel):
    id: str
    time: str
    title: str
    category: str
    emoji: str


class DashboardSummary(BaseModel):
    indicators: list[DashboardIndicator]
    macros: Macros
    diet_entries: int
    exercise_minutes: int
    exercise_calories: int
    exercise_count: int
    today_schedule: list[DashboardScheduleItem]
    week_score: int
    week_score_delta: int
    sodium_warning: Optional[str]
    exercise_feedback: str
