"""운동 API 스키마 — 프론트 _exerciseCurrentWeek 계약 정렬."""
from __future__ import annotations
from datetime import datetime
from pydantic import BaseModel, Field


class ExerciseSessionOut(BaseModel):
    id: str
    day_label: str
    type: str  # cardio|strength|flexibility|other (옛 값은 서버가 접어 준다)
    minutes: int
    #: 근력 기록의 세트 수. 다른 유형과 세트를 모르는 옛 근력 기록은 None —
    #: 그때는 클라이언트가 분에서 환산해 읽는다. (#1262)
    sets: int | None = None
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


class ExerciseAdviceResponse(BaseModel):
    """기간에 맞는 운동 조언. (#1025)

    식단 조언(`DietAdviceResponse`, #1017)과 같은 모양이다 — 두 카드가 한 화면에
    나란히 서므로 응답도 같은 말을 같은 이름으로 해야 한다.

    기간 경계도 함께 돌려준다. 화면이 "무슨 구간을 두고 한 말인가" 를 보여 줄 수
    있어야 하고, 앱과 서버가 서로 다른 주를 셌는지도 이 값으로 드러난다.
    """

    period: str
    from_date: str
    to_date: str
    days_logged: int
    message: str


class ExerciseWeekResponse(BaseModel):
    sessions: list[ExerciseSessionOut]
    daily_minutes: list[int]
    # 홈 '주간 추이' 차트가 읽는 일별 소모 칼로리. 없으면 클라이언트가 데모 상수로
    # 폴백하므로 daily_minutes 와 같이 내려준다.
    daily_calories: list[int]
    # 운동 유형 네 가지의 일별 시간 — 유산소 / 근력 / 유연성 / 기타. (#996)
    cardio_minutes: list[int]
    strength_minutes: list[int]
    #: 근력의 일별 세트 수. 기록이 세트를 들고 있으면 그 값을, 없으면 분에서
    #: 환산한 값을 센다 — 화면은 근력을 세트로만 읽는다. (#1262)
    strength_sets: list[int] = Field(default_factory=list)
    flexibility_minutes: list[int] = Field(default_factory=list)
    other_minutes: list[int] = Field(default_factory=list)
    #: 옛 이름. `flexibility_minutes` 와 같은 값이다 — 두 앱이 옮겨 갈 때까지만
    #: 함께 내려준다.
    stretching_minutes: list[int]
    day_labels: list[str]
    total_minutes: int
    total_calories: int
    streak_days: int
    #: 이 회원의 주간 운동 목표(분)와 소모 칼로리 목표. 그래프의 목표선이 두 앱
    #: 모두 같은 값을 쓰게 하려고 응답에 싣는다 — 트레이너 화면은 회원 프로필을
    #: 따로 읽지 않으므로, 이게 없으면 회원과 트레이너가 서로 다른 선을 본다.
    #: (#1015)
    weekly_goal_minutes: int = 0
    weekly_goal_calories: int = 0
    ai_coach_message: str


class ExerciseSessionCreate(BaseModel):
    """운동 기록 추가 입력. day_label 생략 시 오늘 요일 자동."""
    type: str  # cardio|strength|flexibility|other (옛 값도 받아 정규화한다)
    minutes: int = Field(..., gt=0)
    #: 근력이면 회원이 적은 세트 수. 다른 유형에서 와도 저장하지 않는다 —
    #: 유산소를 세트로 세는 화면은 없다. (#1262)
    sets: int | None = Field(None, gt=0, le=100)
    calories: int = Field(0, ge=0)
    intensity: str = "moderate"  # light|moderate|high
    day_label: str | None = None


class AssignedRoutineCompleteRequest(BaseModel):
    """회원이 배정 루틴을 실제 수행한 결과."""

    minutes: int = Field(..., gt=0, le=600)
    intensity: str = "moderate"
    member_note: str = Field(default="", max_length=1000)
