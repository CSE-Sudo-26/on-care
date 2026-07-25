"""
STEP 6 스키마 — 일정 / 알림 / 장소 / AI 코치.
프론트 계약(_scheduleEvents, _notifications, _placesNearby, _aiCoachFeedback) 정렬.
"""
from __future__ import annotations

from datetime import datetime
from typing import Optional
from pydantic import BaseModel


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
    date: str
    time: str = ""
    title: str
    category: str = "other"
    emoji: str = ""
    color_hex: str = "#E0F2F7"


class ScheduleEventUpdate(BaseModel):
    """일정 상세 수정(부분). 제공된 필드만 반영."""
    date: str | None = None
    time: str | None = None
    title: str | None = None
    category: str | None = None
    emoji: str | None = None
    color_hex: str | None = None


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
