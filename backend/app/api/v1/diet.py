"""
식단 라우터 — 프론트 계약 정렬(얇은 라우터).

  GET  /diet/days/today          -> 오늘 식단 집계(나트륨·당류·macros + 코칭 메시지)
  POST /diet/analyze             -> 사진 → 인식 → diet_entries 저장
  POST /diet/analyze?engine=yolo -> 엔진 강제(비교실험)
  PUT/DELETE /diet/entries/{id}  -> 끼니/영양소 수정·삭제(본인 소유만)

집계·코칭·저장 등 도메인 로직은 diet_service 로 이관했다(exercise_service 등과 일관).
라우터는 HTTP 관심사(업로드 검증·인식기 디스패치·에러 매핑)만 담당한다.
"""
from __future__ import annotations

import logging
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from sqlalchemy.orm import Session

from app.api.deps import CurrentUser
from app.core.config import get_settings
from app.db.session import get_db
from app.schemas.diet_api import DietAnalyzeResponse, DietEntryOut, DietEntryUpdate, DietTodayResponse
from app.services import diet_service
from app.services.nutrition.enrich import enrich_analysis
from app.services.recognizer.factory import get_recognizer

router = APIRouter(tags=["diet"])
logger = logging.getLogger(__name__)

_ALLOWED_MIME = {"image/jpeg", "image/png", "image/webp"}


@router.get("/diet/days/today", response_model=DietTodayResponse)
def diet_today(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> DietTodayResponse:
    return diet_service.build_today(db, current_user.id)


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
        existing = diet_service.find_by_idempotency(db, current_user.id, idempotency_key)
        if existing is not None:
            return DietAnalyzeResponse(
                entry_id=existing.id, analysis=diet_service.entry_to_analysis(existing)
            )

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

    entry, is_new = diet_service.save_analyzed_entry(
        db, current_user.id, meal_type, analysis, idempotency_key
    )
    if not is_new:
        # 동시 재시도가 유니크 제약에 걸려 기존 엔트리를 받은 경우(중복 저장 방지)
        return DietAnalyzeResponse(
            entry_id=entry.id, analysis=diet_service.entry_to_analysis(entry)
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
    """식단 기록의 끼니 분류/시간·영양소 수정(본인 소유만, 아니면 404)."""
    row = diet_service.get_owned_entry(db, current_user.id, entry_id)
    if row is None:
        raise HTTPException(status_code=404, detail="식단 기록을 찾을 수 없습니다.")
    return diet_service.apply_entry_update(db, row, payload)


@router.delete("/diet/entries/{entry_id}")
def delete_entry(
    entry_id: str,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    """식단 기록 삭제. 본인 소유 엔트리만 삭제 가능(아니면 404)."""
    row = diet_service.get_owned_entry(db, current_user.id, entry_id)
    if row is None:
        raise HTTPException(status_code=404, detail="식단 기록을 찾을 수 없습니다.")
    db.delete(row)
    db.commit()
    return {"status": "deleted"}
