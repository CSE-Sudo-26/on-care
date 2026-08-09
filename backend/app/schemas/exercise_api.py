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
    # 이 기록을 누가 만들었나. member=회원이 직접 남김, trainer_pt=트레이너가 PT
    # 세션을 완료해 파생된 기록. 앱은 이 값으로 배지를 붙이고 수정·삭제를 감춘다.
    # 기본값이 있어야 이 필드를 모르는 기존 클라이언트가 깨지지 않는다. (#499)
    source: str = "member"


class ExerciseWeekResponse(BaseModel):
    sessions: list[ExerciseSessionOut]
    daily_minutes: list[int]
    # 홈 '주간 추이' 차트가 읽는 일별 소모 칼로리. 없으면 클라이언트가 데모 상수로
    # 폴백하므로 daily_minutes 와 같이 내려준다.
    daily_calories: list[int]
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
