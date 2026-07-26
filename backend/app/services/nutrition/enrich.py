"""인식 결과(DietAnalysis)를 공공 식품영양성분 DB 값으로 보강.

각 음식을 food_nutrients 에 매칭해:
  - 매칭 O → DB 값으로 교체. 인식기 탄단지가 남으면 source="mixed"
  - 매칭 X → LLM 추정치 유지, source="estimate"
그 뒤 합계를 재계산한다. 엔진(gemini/yolo)과 무관하게 동작.
"""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.models import FoodNutrient
from app.schemas.diet import DietAnalysis
from app.services.nutrition.matcher import match_in_rows


def enrich_analysis(db: Session, analysis: DietAnalysis, enabled: bool = True) -> DietAnalysis:
    if not analysis.foods:
        return analysis

    if not enabled:
        for f in analysis.foods:
            if not f.source:
                f.source = "estimate"
        return analysis

    rows = db.scalars(select(FoodNutrient)).all()
    for food in analysis.foods:
        match = match_in_rows(rows, food.name)
        if match is not None:
            food.calories = int(round(match.calories or 0))
            food.sodium_mg = int(round(match.sodium_mg or 0))
            food.sugar_g = int(round(match.sugar_g or 0))
            kept_recognizer_value = False
            for field in ("carbs_g", "protein_g", "fat_g"):
                db_value = getattr(match, field)
                if db_value is not None:
                    setattr(food, field, float(db_value))
                elif getattr(food, field) is not None:
                    kept_recognizer_value = True
            food.source = "mixed" if kept_recognizer_value else "db"
        else:
            food.source = "estimate"

    return analysis.compute_totals()
