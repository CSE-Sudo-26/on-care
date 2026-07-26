"""
식단 라우터 — 프론트 계약 정렬.

  GET  /diet/days/today          -> 오늘 식단 집계(나트륨·당류 포함 + 코칭 메시지)
  POST /diet/analyze             -> 사진 → Gemini 분석 → diet_entries 저장
  POST /diet/analyze?engine=yolo -> 엔진 강제(비교실험)

인식 엔진은 factory 뒤에 숨어 있어 모델 교체 시에도 계약 동일.
"""
from __future__ import annotations

import json
import logging
import uuid
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import CurrentUser
from app.core.config import get_settings
from app.db.session import get_db
from app.models.models import DietEntry
from app.schemas.diet import DietAnalysis, RecognizedFood
from app.schemas.diet_api import (
    DietAnalyzeResponse, DietEntryOut, DietEntryUpdate, DietTodayResponse, calculate_macros,
)
from app.services.coach.personal_ingest import record_diet
from app.services.nutrition.enrich import enrich_analysis
from app.services.recognizer.factory import get_recognizer

router = APIRouter(tags=["diet"])
logger = logging.getLogger(__name__)

_ALLOWED_MIME = {"image/jpeg", "image/png", "image/webp"}
_FOOD_STORAGE_FIELDS = ("name", "calories", "sodium_mg", "sugar_g", "source")


def _today_str() -> str:
    return datetime.now().strftime("%Y-%m-%d")


def _load_foods(foods_json: str) -> list[dict]:
    foods = json.loads(foods_json) if foods_json else []
    # Meal-level DietEntry macros are authoritative. Ignore legacy per-food macro keys.
    return [
        {field: food[field] for field in _FOOD_STORAGE_FIELDS if field in food}
        for food in foods
    ]


def _entry_to_analysis(entry: DietEntry) -> DietAnalysis:
    """저장된 DietEntry → 분석 응답용 DietAnalysis 재구성(멱등 재시도 응답용).

    coach_comment 는 저장하지 않으므로 재시도 응답에선 비운다(엔트리는 이미 존재).
    끼니 매크로 합계는 DietEntry 를 단일 원본으로 삼아 그대로 반영한다.
    """
    foods_raw = json.loads(entry.foods_json) if entry.foods_json else []
    return DietAnalysis(
        engine=entry.engine or "",
        foods=[RecognizedFood(**f) for f in foods_raw],
        total_calories=entry.total_calories,
        total_carbs_g=entry.carbs_g,
        total_protein_g=entry.protein_g,
        total_fat_g=entry.fat_g,
        total_sodium_mg=entry.sodium_mg,
        total_sugar_g=entry.sugar_g,
        coach_comment="",
    )


@router.get("/diet/days/today", response_model=DietTodayResponse)
def diet_today(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> DietTodayResponse:
    today = _today_str()
    rows = db.scalars(
        select(DietEntry)
        .where(DietEntry.user_id == current_user.id)
        .where(DietEntry.date == today)
        .order_by(DietEntry.created_at.asc())
    ).all()

    entries: list[DietEntryOut] = []
    total_cal = total_na = total_sugar = 0
    total_carbs = total_protein = total_fat = 0.0
    for r in rows:
        foods = _load_foods(r.foods_json)
        entries.append(DietEntryOut(
            id=r.id, meal_type=r.meal_type, time_label=r.time_label,
            foods=foods, total_calories=r.total_calories,
            carbs_g=r.carbs_g, protein_g=r.protein_g, fat_g=r.fat_g,
            sodium_mg=r.sodium_mg, sugar_g=r.sugar_g,
        ))
        total_cal += r.total_calories
        total_carbs += r.carbs_g
        total_protein += r.protein_g
        total_fat += r.fat_g
        total_na += r.sodium_mg
        total_sugar += r.sugar_g

    # 코칭 메시지: 나트륨 기준(고혈압 특화). DASH 권고 ~2000mg 초과 시 경고.
    if total_na > 2000:
        msg = "오늘 나트륨 섭취가 많았어요. 저녁은 담백한 구이/샐러드로 균형을 맞춰봐요!"
    elif not rows:
        msg = "아직 오늘 식단 기록이 없어요. 첫 끼니를 기록해 볼까요?"
    else:
        msg = "균형 잡힌 하루였어요. 내일도 이대로 가요!"

    return DietTodayResponse(
        entries=entries,
        total_calories=total_cal,
        total_sodium_mg=total_na,
        total_sugar_g=total_sugar,
        macros=calculate_macros(total_carbs, total_protein, total_fat),
        ai_coach_message=msg,
    )


@router.post("/diet/analyze", response_model=DietAnalyzeResponse)
async def diet_analyze(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
    image: UploadFile = File(..., description="음식 사진"),
    meal_type: str = Form("lunch", description="breakfast|lunch|dinner|snack"),
    idempotency_key: str | None = Form(
        None,
        max_length=64,  # DietEntry.idempotency_key 컬럼(String(64)) 경계와 일치 — 초과 시 DB 500 방지
        description="재시도 중복 저장 방지 키(선택). 클라 요청당 1회 생성해 재시도 시 재사용.",
    ),
    engine: str | None = Query(None, description="엔진 강제('gemini'|'yolo'). 비교실험용."),
) -> DietAnalyzeResponse:
    if image.content_type not in _ALLOWED_MIME:
        raise HTTPException(status_code=415, detail=f"지원하지 않는 형식: {image.content_type}")
    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="빈 파일입니다.")

    # 멱등키가 있고 이미 저장된 요청이면 인식·저장을 건너뛰고 기존 결과 반환(재시도 중복 방지)
    if idempotency_key:
        existing = db.scalar(
            select(DietEntry)
            .where(DietEntry.user_id == current_user.id)
            .where(DietEntry.idempotency_key == idempotency_key)
        )
        if existing is not None:
            return DietAnalyzeResponse(entry_id=existing.id, analysis=_entry_to_analysis(existing))

    try:
        recognizer = get_recognizer(engine)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e

    try:
        analysis = await recognizer.recognize(image_bytes, image.content_type)
    except NotImplementedError as e:
        raise HTTPException(status_code=501, detail=str(e)) from e
    except Exception as e:  # noqa: BLE001
        # 원본 에러(API 키/내부 URL 등)는 서버 로그에만 남기고, 클라이언트엔 일반화된 메시지
        logger.exception("식단 인식 실패 (engine=%s)", engine)
        raise HTTPException(
            status_code=502, detail="식단 인식에 실패했습니다. 잠시 후 다시 시도해 주세요."
        ) from e

    # 공공 식품영양성분 DB 매핑으로 영양 수치 보강(매칭 시 신뢰값으로 교체 → 합계 재계산)
    enrich_analysis(db, analysis, enabled=get_settings().nutrition_db_enrich)

    # Per-food macros are used only to calculate meal totals; DietEntry is the single source of truth.
    foods_for_storage = [
        {"name": f.name, "calories": f.calories,
         "sodium_mg": f.sodium_mg, "sugar_g": f.sugar_g, "source": f.source}
        for f in analysis.foods
    ]
    entry = DietEntry(
        id=f"diet-{uuid.uuid4().hex[:12]}",
        user_id=current_user.id,
        date=_today_str(),
        meal_type=meal_type,
        time_label=datetime.now().strftime("%H:%M"),
        foods_json=json.dumps(foods_for_storage, ensure_ascii=False),
        total_calories=analysis.total_calories,
        carbs_g=analysis.total_carbs_g,
        protein_g=analysis.total_protein_g,
        fat_g=analysis.total_fat_g,
        sodium_mg=analysis.total_sodium_mg,
        sugar_g=analysis.total_sugar_g,
        engine=analysis.engine,
        idempotency_key=idempotency_key,
    )
    db.add(entry)
    try:
        db.commit()
    except IntegrityError:
        # 동시 재시도가 유니크 제약에 걸리면 이미 저장된 엔트리를 반환(중복 저장·재적재 방지)
        db.rollback()
        existing = db.scalar(
            select(DietEntry)
            .where(DietEntry.user_id == current_user.id)
            .where(DietEntry.idempotency_key == idempotency_key)
        ) if idempotency_key else None
        if existing is not None:
            return DietAnalyzeResponse(entry_id=existing.id, analysis=_entry_to_analysis(existing))
        raise
    db.refresh(entry)

    # 개인 RAG 문서로 적재(코치가 내 최근 식단을 검색하도록). best-effort.
    record_diet(
        db, current_user.id, date=entry.date, foods=foods_for_storage,
        total_calories=entry.total_calories, sodium_mg=entry.sodium_mg, sugar_g=entry.sugar_g,
    )

    # 모델 원본 출력(raw_model_output)은 클라이언트로 내보내지 않음(디버깅 전용)
    analysis.raw_model_output = None
    return DietAnalyzeResponse(entry_id=entry.id, analysis=analysis)


@router.put("/diet/entries/{entry_id}", response_model=DietEntryOut)
def update_entry(
    entry_id: str,
    payload: DietEntryUpdate,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> DietEntryOut:
    """식단 기록의 끼니 분류/시간 수정(본인 소유만, 아니면 404)."""
    row = db.scalar(
        select(DietEntry)
        .where(DietEntry.id == entry_id)
        .where(DietEntry.user_id == current_user.id)
    )
    if row is None:
        raise HTTPException(status_code=404, detail="식단 기록을 찾을 수 없습니다.")
    if payload.meal_type is not None:
        row.meal_type = payload.meal_type
    if payload.time_label is not None:
        row.time_label = payload.time_label
    for field in (
        "total_calories", "carbs_g", "protein_g", "fat_g", "sodium_mg", "sugar_g"
    ):
        value = getattr(payload, field)
        if value is not None:
            setattr(row, field, value)
    db.commit()
    db.refresh(row)
    foods = _load_foods(row.foods_json)
    return DietEntryOut(
        id=row.id, meal_type=row.meal_type, time_label=row.time_label,
        foods=foods, total_calories=row.total_calories,
        carbs_g=row.carbs_g, protein_g=row.protein_g, fat_g=row.fat_g,
        sodium_mg=row.sodium_mg, sugar_g=row.sugar_g,
    )


@router.delete("/diet/entries/{entry_id}")
def delete_entry(
    entry_id: str,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    """식단 기록 삭제. 본인 소유 엔트리만 삭제 가능(아니면 404)."""
    row = db.scalar(
        select(DietEntry)
        .where(DietEntry.id == entry_id)
        .where(DietEntry.user_id == current_user.id)
    )
    if row is None:
        raise HTTPException(status_code=404, detail="식단 기록을 찾을 수 없습니다.")
    db.delete(row)
    db.commit()
    return {"status": "deleted"}
