"""
식단 API 응답 스키마 — 프론트 계약(_dietToday) 정렬.

GET /diet/days/today 응답:
  { entries[], total_calories, total_sodium_mg, total_sugar_g, macros, ai_coach_message }
entries[]: { id, meal_type, time_label, foods[], total_calories, carbs_g, protein_g,
             fat_g, sodium_mg, sugar_g }
"""
from __future__ import annotations

from typing import Any, Literal
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
    sugar_g: float


class DietEntryUpdate(BaseModel):
    """PUT /diet/entries/{id} — 끼니 정보와 영양소 부분 수정."""
    meal_type: str | None = None
    time_label: str | None = None
    total_calories: int | None = Field(None, ge=0)
    carbs_g: float | None = Field(None, ge=0, allow_inf_nan=False)
    protein_g: float | None = Field(None, ge=0, allow_inf_nan=False)
    fat_g: float | None = Field(None, ge=0, allow_inf_nan=False)
    sodium_mg: int | None = Field(None, ge=0)
    sugar_g: float | None = Field(None, ge=0, allow_inf_nan=False)


class DietTodayResponse(BaseModel):
    entries: list[DietEntryOut]
    total_calories: int
    total_sodium_mg: int
    total_sugar_g: float
    macros: Macros
    ai_coach_message: str


class DietAnalyzeResponse(BaseModel):
    """POST /diet/analyze 응답: 저장된 entry id + 분석 결과."""
    entry_id: str
    analysis: DietAnalysis


class DietRecommendationItem(BaseModel):
    """홈 추천 카드 1장.

    문자열(요리명·태그)을 내려주지 않는 게 핵심이다. 앱이 `key` 로 번들 이미지와
    로케일 문구를 찾아 그리므로, 서버는 "무엇을 어떤 순서로"만 정한다.
    `reason_text` 는 LLM 이 쓴 개인화 문구이며 없을 수 있다(그때 앱은 `reason_key`
    의 l10n 기본 문구를 쓴다) — 영어 로케일에서 한국어가 새는 걸 막는 장치다.
    """
    key: str
    reason_key: str
    reason_text: str | None = None


class DietRecommendationsResponse(BaseModel):
    """GET /diet/recommendations 응답.

    `basis` 는 추천의 근거를 사람이 읽는 한 줄로 요약한 것(예: "최근 3일 평균 나트륨
    2,400mg"). 개인화가 실제로 일어났는지 화면에서 확인할 수 있게 노출한다.
    `personalized=False` 면 근거 데이터가 없어 기본 순서로 내려준 것이다.
    `source` 는 관측용: llm | rules | fallback.
    """
    items: list[DietRecommendationItem]
    basis: str | None = None
    personalized: bool = False
    source: Literal["llm", "rules", "fallback"] = "rules"

    # 근거를 앱이 직접 문장으로 만들 수 있도록 수치도 함께 준다. `basis` 는 서버가
    # 조립한 한국어 문장이라 영어 로케일에 그대로 쓸 수 없다(요리명·이유를 key 로
    # 주고받는 것과 같은 이유). 화면 문구는 앱이 l10n 으로 만든다.
    days_with_data: int = 0
    avg_sodium_mg: int = 0
    sodium_limit_mg: int = 0
