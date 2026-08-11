"""
식단 도메인 서비스 — 라우터에서 분리한 집계·코칭·저장 로직.

diet 라우터가 오늘 집계·나트륨 코칭·엔트리 저장/멱등을 직접 수행해 두꺼웠던 것을
여기로 이관한다(exercise_service/health_service 와 일관성). 동작·응답 계약은 불변이며,
라우터는 HTTP 관심사(업로드·인식기 디스패치·에러 매핑)만 담당한다.
"""
from __future__ import annotations

import json
import logging
import uuid

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core import clock
from app.models.models import DietEntry
from app.schemas.diet import DietAnalysis, RecognizedFood
from app.schemas.diet_api import (
    DietEntryOut, DietEntryUpdate, DietTodayResponse, calculate_macros,
)
from app.services.coach.personal_ingest import record_diet

logger = logging.getLogger(__name__)

# 끼니 macros/nutrient 는 DietEntry 를 단일 원본으로 삼는다. 저장 시 유지하는 음식 필드.
_FOOD_STORAGE_FIELDS = ("name", "calories", "sodium_mg", "sugar_g", "source")
# DASH 권고 나트륨 상한(고혈압 특화 코칭 기준).
DASH_SODIUM_LIMIT_MG = 2000


def today_str() -> str:
    return clock.today_iso()


def load_foods(foods_json: str) -> list[dict]:
    """저장된 foods_json → 표시용 음식 목록. 레거시 per-food macro 키는 무시."""
    foods = json.loads(foods_json) if foods_json else []
    return [
        {field: food[field] for field in _FOOD_STORAGE_FIELDS if field in food}
        for food in foods
    ]


def entry_to_analysis(entry: DietEntry) -> DietAnalysis:
    """저장된 DietEntry → 분석 응답용 DietAnalysis(멱등 재시도 응답용).

    coach_comment 는 저장하지 않으므로 재시도 응답에선 비운다(엔트리는 이미 존재).
    끼니 macros/nutrient 합계는 DietEntry 를 단일 원본으로 그대로 반영한다.
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


def _entry_out(entry: DietEntry) -> DietEntryOut:
    return DietEntryOut(
        id=entry.id, meal_type=entry.meal_type, time_label=entry.time_label,
        foods=load_foods(entry.foods_json), total_calories=entry.total_calories,
        carbs_g=entry.carbs_g, protein_g=entry.protein_g, fat_g=entry.fat_g,
        sodium_mg=entry.sodium_mg, sugar_g=entry.sugar_g,
    )


def coach_message(total_sodium_mg: int, has_entries: bool) -> str:
    """오늘 나트륨 기준 코칭 메시지(고혈압 특화). DASH 권고 초과 시 경고."""
    if total_sodium_mg > DASH_SODIUM_LIMIT_MG:
        return "오늘 나트륨 섭취가 많았어요. 저녁은 담백한 구이/샐러드로 균형을 맞춰봐요!"
    if not has_entries:
        return "아직 오늘 식단 기록이 없어요. 첫 끼니를 기록해 볼까요?"
    return "균형 잡힌 하루였어요. 내일도 이대로 가요!"


def build_day(db: Session, user_id: str, date: str) -> DietTodayResponse:
    """지정 날짜 식단 집계(칼로리·나트륨·당류·macros + 코칭 메시지)."""
    rows = db.scalars(
        select(DietEntry)
        .where(DietEntry.user_id == user_id, DietEntry.date == date)
        .order_by(DietEntry.created_at.asc())
    ).all()

    entries: list[DietEntryOut] = [_entry_out(r) for r in rows]
    total_cal = total_na = total_sugar = 0
    total_carbs = total_protein = total_fat = 0.0
    for r in rows:
        total_cal += r.total_calories
        total_carbs += r.carbs_g
        total_protein += r.protein_g
        total_fat += r.fat_g
        total_na += r.sodium_mg
        total_sugar += r.sugar_g

    return DietTodayResponse(
        entries=entries,
        total_calories=total_cal,
        total_sodium_mg=total_na,
        total_sugar_g=total_sugar,
        macros=calculate_macros(total_carbs, total_protein, total_fat),
        ai_coach_message=coach_message(total_na, bool(rows)),
    )


def build_today(db: Session, user_id: str) -> DietTodayResponse:
    """오늘 식단 집계. 기존 today 엔드포인트의 동작을 유지한다."""
    return build_day(db, user_id, today_str())


def find_by_idempotency(db: Session, user_id: str, key: str) -> DietEntry | None:
    return db.scalar(
        select(DietEntry).where(
            DietEntry.user_id == user_id, DietEntry.idempotency_key == key
        )
    )


def save_analyzed_entry(
    db: Session, user_id: str, meal_type: str, analysis: DietAnalysis,
    idempotency_key: str | None,
) -> tuple[DietEntry, bool]:
    """분석 결과를 diet_entries 에 저장. 반환: (entry, is_new).

    동시 재시도가 유니크 제약(user_id, idempotency_key)에 걸리면 이미 저장된 엔트리를
    반환한다(is_new=False, 중복 저장·재적재 방지). 신규 저장 시 개인 RAG 문서로도 적재.
    """
    foods_for_storage = [
        {"name": f.name, "calories": f.calories,
         "sodium_mg": f.sodium_mg, "sugar_g": f.sugar_g, "source": f.source}
        for f in analysis.foods
    ]
    # 날짜와 시각은 같은 시계 스냅샷에서 뽑는다. 따로 읽으면 KST 자정 사이에
    # date 는 어제, time_label 은 오늘이 되어 한 행 안에서 어긋난다.
    recorded_at = clock.now()
    entry = DietEntry(
        id=f"diet-{uuid.uuid4().hex[:12]}",
        user_id=user_id,
        date=recorded_at.date().isoformat(),
        meal_type=meal_type,
        time_label=recorded_at.strftime("%H:%M"),
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
        db.rollback()
        existing = find_by_idempotency(db, user_id, idempotency_key) if idempotency_key else None
        if existing is not None:
            return existing, False
        raise
    db.refresh(entry)

    # 개인 RAG 문서로 적재(코치가 내 최근 식단을 검색하도록). 식단 저장은 이미
    # commit됐으므로 보조 인덱싱 실패가 성공 응답을 500으로 바꾸지 않게 격리한다.
    try:
        record_diet(
            db, user_id, date=entry.date, foods=foods_for_storage,
            total_calories=entry.total_calories, sodium_mg=entry.sodium_mg,
            sugar_g=entry.sugar_g, source_ref=entry.id,
        )
    except Exception as exc:  # noqa: BLE001 — 개인 RAG 적재는 best-effort
        db.rollback()
        logger.warning(
            "개인 RAG 적재 실패(%s) — 식단 저장은 유지",
            type(exc).__name__,
        )
    return entry, True


def get_owned_entry(db: Session, user_id: str, entry_id: str) -> DietEntry | None:
    return db.scalar(
        select(DietEntry).where(DietEntry.id == entry_id, DietEntry.user_id == user_id)
    )


def apply_entry_update(db: Session, entry: DietEntry, payload: DietEntryUpdate) -> DietEntryOut:
    """식단 기록의 끼니 분류/시간 + 영양소 부분 수정."""
    if payload.meal_type is not None:
        entry.meal_type = payload.meal_type
    if payload.time_label is not None:
        entry.time_label = payload.time_label
    for field in ("total_calories", "carbs_g", "protein_g", "fat_g", "sodium_mg", "sugar_g"):
        value = getattr(payload, field)
        if value is not None:
            setattr(entry, field, value)
    db.commit()
    db.refresh(entry)
    out = _entry_out(entry)
    # 코치가 보는 근거도 함께 바뀌어야 한다(#603). 안 바꾸면 나트륨을 정정해도
    # 코치는 계속 옛 수치로 조언한다.
    record_diet(
        db, entry.user_id, date=entry.date, foods=load_foods(entry.foods_json),
        total_calories=entry.total_calories, sodium_mg=entry.sodium_mg,
        sugar_g=entry.sugar_g, source_ref=entry.id, replace=True,
    )
    return out
