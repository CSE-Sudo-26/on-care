"""
트레이너 API 스키마 — 트레이너 프론트 계약(seedTrainerProfile / TrainerProfile) 정렬.

GET /trainer/me 응답:
  { id, name, email, phone, specialty, career, intro, certifications[], gym{...} }
"""
from __future__ import annotations

from pydantic import BaseModel


class TrainerGymOut(BaseModel):
    name: str
    address: str
    hours: str
    phone: str


class TrainerMe(BaseModel):
    id: str
    name: str
    email: str
    phone: str
    specialty: str
    career: str          # "7년" (career_years 파생)
    intro: str
    certifications: list[str]
    gym: TrainerGymOut


class TrainerClientOut(BaseModel):
    """고객 로스터 카드 — 프론트 TrainerClient 계약 정렬.

    id 는 회원 User id(하위 엔드포인트 키). calories/sodium_mg/sugar_g 는 회원의
    실제 오늘 식단(DietEntry)에서 집계한 값이다(진짜 데이터 공유).
    """
    id: str                      # member_id — /trainer/clients/{id}/... 키
    name: str
    avatar: str
    goal: str
    last_message: str
    last_time: str
    active: bool
    calories: int                # 오늘 총 칼로리(회원 실데이터)
    sodium_mg: int               # 오늘 총 나트륨
    sugar_g: int                 # 오늘 총 당류
    last_routine: str            # 마지막 루틴 전송 라벨(오늘/어제/N일 전)
    week_completion: list[int]   # 이번 주 일별 완료율 7개(월→일)
    sodium_week: list[int]       # 최근 7일 일별 나트륨(오래된→오늘)


class ClientDietEntryOut(BaseModel):
    """고객 식단 서브탭 한 끼 — 프론트 ClientDietEntry 계약 정렬."""
    meal: str        # 아침|점심|저녁|간식
    items: str       # 음식명 나열
    calories: int
    sodium_mg: int


class RoutineHistoryOut(BaseModel):
    """고객 운동기록 서브탭 항목 — 프론트 RoutineHistoryEntry 계약 정렬."""
    date_label: str          # "7/12 (오늘)"
    label: str               # "PT 세션 · 트레이너 지도"
    completion_rate: int     # 0..100
    exercises: list[str]
    client_feedback: str
    trainer_note: str
