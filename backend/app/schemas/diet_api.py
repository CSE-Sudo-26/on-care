"""
식단 API 응답 스키마 — 프론트 계약(_dietToday) 정렬.

GET /diet/days/today 응답:
  { entries[], total_calories, total_sodium_mg, total_sugar_g, macros, ai_coach_message }
entries[]: { id, meal_type, time_label, foods[], total_calories, carbs_g, protein_g,
             fat_g, sodium_mg, sugar_g }
"""
from __future__ import annotations

from typing import Any
from pydantic import BaseModel, Field

from app.schemas.diet import DietAnalysis


class Macros(BaseModel):
    carbs_g: float = 0.0
    protein_g: float = 0.0
    fat_g: float = 0.0
    carbs_pct: int = 0
    protein_pct: int = 0
    fat_pct: int = 0


def calculate_macros(carbs_g: float, protein_g: float, fat_g: float) -> Macros:
    """Build 4/4/9 percentages with largest remainders; ties favor fat, then protein."""
    energies = (carbs_g * 4, protein_g * 4, fat_g * 9)
    total_energy = sum(energies)
    if total_energy == 0:
        percentages = [0, 0, 0]
    else:
        raw_percentages = [energy / total_energy * 100 for energy in energies]
        percentages = [int(value) for value in raw_percentages]
        remaining = 100 - sum(percentages)
        ranked = sorted(
            range(len(percentages)),
            key=lambda index: (raw_percentages[index] - percentages[index], index),
            reverse=True,
        )
        for index in ranked[:remaining]:
            percentages[index] += 1
    return Macros(
        carbs_g=carbs_g,
        protein_g=protein_g,
        fat_g=fat_g,
        carbs_pct=percentages[0],
        protein_pct=percentages[1],
        fat_pct=percentages[2],
    )


class DietEntryOut(BaseModel):
    id: str
    meal_type: str
    time_label: str
    foods: list[dict[str, Any]]  # [{name, calories}]
    total_calories: int
    carbs_g: float
    protein_g: float
    fat_g: float
    sodium_mg: int
    sugar_g: int


class DietEntryUpdate(BaseModel):
    """PUT /diet/entries/{id} — 끼니 정보와 영양소 부분 수정."""
    meal_type: str | None = None
    time_label: str | None = None
    total_calories: int | None = Field(None, ge=0)
    carbs_g: float | None = Field(None, ge=0, allow_inf_nan=False)
    protein_g: float | None = Field(None, ge=0, allow_inf_nan=False)
    fat_g: float | None = Field(None, ge=0, allow_inf_nan=False)
    sodium_mg: int | None = Field(None, ge=0)
    sugar_g: int | None = Field(None, ge=0)


class DietTodayResponse(BaseModel):
    entries: list[DietEntryOut]
    total_calories: int
    total_sodium_mg: int
    total_sugar_g: int
    macros: Macros
    ai_coach_message: str


class DietAnalyzeResponse(BaseModel):
    """POST /diet/analyze 응답: 저장된 entry id + 분석 결과."""
    entry_id: str
    analysis: DietAnalysis
