"""운동 API 스키마 — 프론트 _exerciseCurrentWeek 계약 정렬."""
from __future__ import annotations
from pydantic import BaseModel, Field


class ExerciseSessionOut(BaseModel):
    id: str
    day_label: str
    type: str  # cardio|strength|yoga|walking
    minutes: int
    calories: int
    intensity: str  # light|moderate|high
    date_label: str
    time_label: str
    items: list[str]


class ExerciseWeekResponse(BaseModel):
    sessions: list[ExerciseSessionOut]
    daily_minutes: list[int]
    cardio_minutes: list[int]
    strength_minutes: list[int]
    stretching_minutes: list[int]
    day_labels: list[str]
    total_minutes: int
    total_calories: int
    streak_days: int
    ai_coach_message: str


class ExerciseSessionCreate(BaseModel):
    """운동 기록 추가 입력. day_label 생략 시 오늘 요일 자동."""
    type: str  # cardio|strength|yoga|walking
    minutes: int = Field(..., gt=0)
    calories: int = Field(0, ge=0)
    intensity: str = "moderate"  # light|moderate|high
    day_label: str | None = None
