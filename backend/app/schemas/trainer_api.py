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
