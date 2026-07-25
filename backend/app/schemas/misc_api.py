"""
STEP 6 스키마 — 일정 / 알림 / 장소 / AI 코치.
프론트 계약(_scheduleEvents, _notifications, _placesNearby, _aiCoachFeedback) 정렬.
"""
from __future__ import annotations

from datetime import date as _date, datetime
from typing import Literal, Optional
from pydantic import BaseModel, Field, field_validator

# 회원 일정 카테고리 허용값(프론트 계약).
ScheduleCategory = Literal["hospital", "exercise", "meal", "medication", "other"]
_HEX_COLOR = r"^#[0-9A-Fa-f]{3}([0-9A-Fa-f]{3})?$"


def _valid_ymd(v: str) -> str:
    try:
        _date.fromisoformat(v)  # 2026-99-99 등 달력상 불가능한 값 거부
    except ValueError as e:
        raise ValueError("유효한 날짜(YYYY-MM-DD)가 아닙니다.") from e
    return v


def _valid_hhmm_or_empty(v: str) -> str:
    if v == "":
        return v  # 시간 미지정(종일) 허용
    try:
        datetime.strptime(v, "%H:%M")  # 25:99 등 거부
    except ValueError as e:
        raise ValueError("유효한 시간(HH:MM)이 아닙니다.") from e
    return v


# ---- 일정 ----
class ScheduleEventOut(BaseModel):
    id: str
    date: str          # YYYY-MM-DD
    time: str
    title: str
    category: str      # hospital|exercise|meal|medication|other
    emoji: str
    color_hex: str


class ScheduleEventCreate(BaseModel):
    date: str = Field(max_length=10)
    time: str = Field(default="", max_length=10)
    title: str = Field(min_length=1, max_length=200)
    category: ScheduleCategory = "other"
    emoji: str = Field(default="", max_length=10)
    color_hex: str = Field(default="#E0F2F7", max_length=10, pattern=_HEX_COLOR)

    _v_date = field_validator("date")(_valid_ymd)
    _v_time = field_validator("time")(_valid_hhmm_or_empty)


class ScheduleEventUpdate(BaseModel):
    """일정 상세 수정(부분). 제공된 필드만 반영. 잘못된 값은 422."""
    date: str | None = Field(default=None, max_length=10)
    time: str | None = Field(default=None, max_length=10)
    title: str | None = Field(default=None, min_length=1, max_length=200)
    category: ScheduleCategory | None = None
    emoji: str | None = Field(default=None, max_length=10)
    color_hex: str | None = Field(default=None, max_length=10, pattern=_HEX_COLOR)

    @field_validator("date")
    @classmethod
    def _vd(cls, v: str | None) -> str | None:
        return _valid_ymd(v) if v is not None else v

    @field_validator("time")
    @classmethod
    def _vt(cls, v: str | None) -> str | None:
        return _valid_hhmm_or_empty(v) if v is not None else v


# ---- 알림 ----
class NotificationAction(BaseModel):
    """알림에서 바로 갈 수 있는 액션(카테고리에서 파생). 프론트가 target 으로 이동."""
    label: str         # "기록하러 가기"
    target: str        # 프론트 라우트 힌트: vitals|schedule|dashboard


class NotificationOut(BaseModel):
    id: str
    title: str
    body: str
    category: str      # reminder|health_check|achievement|system
    read: bool
    created_at: datetime
    time_ago: str
    action: NotificationAction | None = None


# ---- 장소 ----
class PlaceOut(BaseModel):
    id: str
    name: str
    category: str      # medical|fitness|healthy_food|pharmacy
    address: str
    distance_meters: int
    lat: Optional[float]
    lng: Optional[float]


# ---- AI 코치 ----
class CoachSuggestion(BaseModel):
    tag: str           # diet|exercise|hydration|...
    title: str
    body: str


class AiCoachFeedback(BaseModel):
    greeting: str
    suggestions: list[CoachSuggestion]


# ---- AI 코치 챗봇 (대화형) ----
class ChatTurn(BaseModel):
    role: str          # user | coach
    content: str


class ChatRequest(BaseModel):
    message: str
    history: list[ChatTurn] = []   # 직전 대화(선택). 최근 것부터가 아니라 시간순.


class ChatReply(BaseModel):
    reply: str
    sources: list[str] = []        # 답변 근거로 쓰인 공공 가이드라인 제목
