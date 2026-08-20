"""운동 API 스키마 — 프론트 _exerciseCurrentWeek 계약 정렬."""
from __future__ import annotations
from datetime import datetime
from pydantic import BaseModel, Field


class ExerciseSessionOut(BaseModel):
    id: str
    day_label: str
    type: str  # cardio|strength|flexibility|other (옛 값은 서버가 접어 준다)
    minutes: int
    calories: int
    intensity: str  # light|moderate|high
    date_label: str
    time_label: str
    items: list[str]
    # 기록 출처: member | trainer_pt | assigned_routine. 앱은 파생 기록을
    # 수기 기록과 구분하고 수정·삭제를 감춘다.
    # 기본값이 있어야 이 필드를 모르는 기존 클라이언트가 깨지지 않는다. (#499)
    source: str = "member"
    assigned_routine_id: str | None = None
    assigned_routine_name: str = ""
    member_note: str = ""
    trainer_feedback: str = ""
    completed_at: datetime | None = None


class ExerciseWeekResponse(BaseModel):
    sessions: list[ExerciseSessionOut]
    daily_minutes: list[int]
    # 홈 '주간 추이' 차트가 읽는 일별 소모 칼로리. 없으면 클라이언트가 데모 상수로
    # 폴백하므로 daily_minutes 와 같이 내려준다.
    daily_calories: list[int]
    # 운동 유형 네 가지의 일별 시간 — 유산소 / 근력 / 유연성 / 기타. (#996)
    cardio_minutes: list[int]
    strength_minutes: list[int]
    flexibility_minutes: list[int] = Field(default_factory=list)
    other_minutes: list[int] = Field(default_factory=list)
    #: 옛 이름. `flexibility_minutes` 와 같은 값이다 — 두 앱이 옮겨 갈 때까지만
    #: 함께 내려준다.
    stretching_minutes: list[int]
    day_labels: list[str]
    total_minutes: int
    total_calories: int
    streak_days: int
    ai_coach_message: str


class ExerciseSessionCreate(BaseModel):
    """운동 기록 추가 입력. day_label 생략 시 오늘 요일 자동."""
    type: str  # cardio|strength|flexibility|other (옛 값도 받아 정규화한다)
    minutes: int = Field(..., gt=0)
    calories: int = Field(0, ge=0)
    intensity: str = "moderate"  # light|moderate|high
    day_label: str | None = None


class AssignedRoutineCompleteRequest(BaseModel):
    """회원이 배정 루틴을 실제 수행한 결과."""

    minutes: int = Field(..., gt=0, le=600)
    intensity: str = "moderate"
    member_note: str = Field(default="", max_length=1000)
