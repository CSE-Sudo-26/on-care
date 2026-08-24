"""운동 API 스키마 — 프론트 _exerciseCurrentWeek 계약 정렬."""
from __future__ import annotations
from datetime import date as date_, datetime
from typing import Literal

from pydantic import BaseModel, Field

#: 회원이 고를 수 있는 운동 유형. 저장 값은 이 넷뿐이다(#996).
ExerciseTypeIn = Literal["cardio", "strength", "flexibility", "other"]
#: 옛 어휘. 아직 이 값을 보내는 앱이 있어 입력에서만 받아 접어 준다 — 거절하면
#: 기록이 통째로 사라지는데, 그건 유형 하나 어긋난 것보다 나쁘다.
LegacyExerciseTypeIn = Literal["walking", "yoga", "stretching"]
ExerciseIntensityIn = Literal["light", "moderate", "high"]


class ExerciseSessionOut(BaseModel):
    id: str
    day_label: str
    #: 이 기록의 실제 날짜. 저장은 (주 시작 + 요일 라벨)로 쪼개져 있어 요일만으로는
    #: 몇 주 전 기록과 구분되지 않는다 — 앱이 날짜를 고쳐 쓸 수 있도록 되돌려
    #: 준다. (#1276)
    date: date_ | None = None
    type: str  # cardio|strength|flexibility|other (옛 값은 서버가 접어 준다)
    #: 회원이 적은 운동 이름. 이 필드가 생기기 전 기록은 빈 문자열이다. (#1276)
    name: str = ""
    minutes: int
    #: 근력 기록의 세트 수. 다른 유형과 세트를 모르는 옛 근력 기록은 None —
    #: 그때는 클라이언트가 분에서 환산해 읽는다. (#1262)
    sets: int | None = None
    #: 근력 기록의 중량(kg). 세트와 짝이라 근력에만 있다. (#1276)
    weight: float | None = None
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
    # 운동 유형 네 가지의 일별 시간 — 유산소 / 근력 / 스트레칭 / 기타. (#996)
    cardio_minutes: list[int]
    strength_minutes: list[int]
    #: 근력의 일별 세트 수. 기록이 세트를 들고 있으면 그 값을, 없으면 분에서
    #: 환산한 값을 센다 — 화면은 근력을 세트로만 읽는다. (#1262)
    strength_sets: list[int] = Field(default_factory=list)
    stretching_minutes: list[int]
    other_minutes: list[int] = Field(default_factory=list)
    #: 옛 이름. `stretching_minutes` 와 같은 값이다 — 유형 어휘를 스트레칭으로
    #: 되돌리기 전(#996) 잠깐 쓰던 이름이라, 아직 이걸 읽는 클라이언트가 있는
    #: 동안만 함께 내려준다. (#1276)
    flexibility_minutes: list[int] = Field(default_factory=list)
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
    """운동 기록 추가·수정 입력.

    값마다 제 타입으로 받는다(#1276). 날짜는 문자열이 아니라 `date` 이고 유형과
    강도는 Literal 이라, 잘못된 값은 라우터에 닿기 전에 422 로 걸린다 — 예전에는
    셋 다 자유 문자열이라 화이트리스트 검사를 라우터가 손으로 했다.
    """

    type: ExerciseTypeIn | LegacyExerciseTypeIn
    #: 회원이 적은 운동 이름. 유형만으로는 무슨 운동인지 남지 않는다.
    name: str = Field(default="", max_length=100)
    minutes: int = Field(..., gt=0)
    #: 근력이면 회원이 적은 세트 수. 다른 유형에서 와도 저장하지 않는다 —
    #: 유산소를 세트로 세는 화면은 없다. (#1262)
    sets: int | None = Field(None, gt=0, le=100)
    #: 근력이면 중량(kg). 세트와 같은 규칙으로, 다른 유형에서 와도 버린다.
    weight: float | None = Field(None, ge=0, le=1000)
    calories: int = Field(0, ge=0)
    intensity: ExerciseIntensityIn = "moderate"
    #: 이 운동을 한 날. 생략하면 오늘이다. 예전 `day_label`(요일 문자열)은 어느
    #: 주인지를 담지 못해, 지난 날짜를 골라도 늘 이번 주로 저장됐다.
    date: date_ | None = None


class AssignedRoutineCompleteRequest(BaseModel):
    """회원이 배정 루틴을 실제 수행한 결과."""

    minutes: int = Field(..., gt=0, le=600)
    #: 근력 루틴이면 실제로 한 세트 수와 중량. 수기 기록과 같은 값을 남겨야
    #: 그래프가 두 기록을 같은 축으로 읽는다. (#1276)
    sets: int | None = Field(None, gt=0, le=100)
    weight: float | None = Field(None, ge=0, le=1000)
    intensity: ExerciseIntensityIn = "moderate"
    member_note: str = Field(default="", max_length=1000)
