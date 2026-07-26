"""
사용자 응답 스키마 — 프론트 계약(_usersMe, _usersMeHealth)에 정확히 맞춤.

모든 필드는 snake_case (프론트 case_mapper 가 camelCase 로 변환).
"""
from __future__ import annotations

from typing import Optional
from pydantic import BaseModel


# ---- GET /users/me ----
class UserMe(BaseModel):
    id: str
    name: str
    email: str


# ---- GET /users/me/health ----
class HealthProfileBrief(BaseModel):
    name: str
    email: str


class RiskInfo(BaseModel):
    title: str
    body: str
    level: str  # low | medium | high


class RecentRecord(BaseModel):
    label: str
    value: str


class HealthIndicator(BaseModel):
    kind: str  # weight | blood-pressure | blood-sugar
    label: str
    latest_value: str
    unit: str
    delta_text: str
    improving: bool
    last_7_days: list[float]
    chart_values: list[float]
    chart_min_y: float
    chart_max_y: float
    chart_interval: float
    recent_records: list[RecentRecord]


class SettingItem(BaseModel):
    label: str
    icon: str
    kind: str


class UserHealth(BaseModel):
    profile: HealthProfileBrief
    risk: RiskInfo
    indicators: list[HealthIndicator]
    activity_points: int
    activity_rank: Optional[int]
    settings: list[SettingItem]


# ---- 인증(로그인) ----
class Token(BaseModel):
    access_token: str
    refresh_token: str = ""
    token_type: str = "bearer"


class RefreshRequest(BaseModel):
    refresh_token: str


class SocialLoginRequest(BaseModel):
    # provider 가 준 토큰 (kakao/naver=access_token, google=id_token)
    token: str


class UserRegister(BaseModel):
    email: str
    password: str
    name: str = ""


# ---- 프로필 / 온보딩 / 건강 목표 ----
class ProfileView(BaseModel):
    """GET /users/me/profile — 내 프로필 화면용 통합 뷰."""
    id: str
    name: str
    email: str
    phone: str = ""
    birth_date: str = ""
    gender: str = ""
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    conditions: str = ""
    goals: str = ""
    goal_weight_kg: Optional[float] = None
    goal_bp_systolic: Optional[int] = None
    goal_blood_sugar: Optional[int] = None
    daily_calories: Optional[int] = None
    daily_sodium_mg: Optional[int] = None
    daily_sugar_g: Optional[int] = None
    onboarded: bool = False


class OnboardingRequest(BaseModel):
    """POST /users/me/onboarding — 최초 온보딩(모두 선택, 부분 저장 허용).

    name 은 User, 나머지는 HealthProfile 컬럼과 1:1 로 매핑된다.
    """
    name: Optional[str] = None
    birth_date: Optional[str] = None       # YYYY-MM-DD
    gender: Optional[str] = None           # male|female|other
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    conditions: Optional[str] = None       # "고혈압, 당뇨 전단계"
    goals: Optional[str] = None
    goal_weight_kg: Optional[float] = None
    goal_bp_systolic: Optional[int] = None
    goal_blood_sugar: Optional[int] = None
    daily_calories: Optional[int] = None
    daily_sodium_mg: Optional[int] = None
    daily_sugar_g: Optional[int] = None


class ProfileUpdate(BaseModel):
    """PUT /users/me — 내 프로필 모달(이름/이메일/전화/생년월일)."""
    name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    birth_date: Optional[str] = None


class HealthGoalsUpdate(BaseModel):
    """PUT /users/me/health-goals — 건강 목표 모달."""
    goal_weight_kg: Optional[float] = None
    goal_bp_systolic: Optional[int] = None
    goal_blood_sugar: Optional[int] = None
    daily_calories: Optional[int] = None
    daily_sodium_mg: Optional[int] = None
    daily_sugar_g: Optional[int] = None
