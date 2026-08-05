"""식단 기록을 개인 RAG 문서로 적재(best-effort).

원칙: 적재 실패(임베딩 오류 등)가 절대 원 기록 저장이나 응답을 깨뜨리지 않는다.
실패 시 조용히 넘어가고 세션을 롤백해 정리한다. RAG_AUTO_INGEST=false 로 끌 수 있다.
"""
from __future__ import annotations

import logging

from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.services.coach.rag import ingest_personal_text

log = logging.getLogger(__name__)


def _safe(db: Session, user_id: str, text: str, *, domain: str, source: str) -> None:
    if not get_settings().rag_auto_ingest or not user_id or not text.strip():
        return
    try:
        ingest_personal_text(db, user_id, text, domain=domain, source=source, title="")
    except Exception as e:  # noqa: BLE001 — 적재 실패가 원 기록을 깨면 안 됨
        log.warning("개인 RAG 적재 실패(무시): %s", e)
        try:
            db.rollback()
        except Exception:  # noqa: BLE001
            pass


def record_diet(
    db: Session, user_id: str, *, date: str, foods: list[dict],
    total_calories: int, sodium_mg: int, sugar_g: float,
) -> None:
    names = ", ".join(f.get("name", "") for f in foods if f.get("name")) or "식단"
    text = (
        f"{date} 식단 기록: {names}. "
        f"총 {total_calories}kcal, 나트륨 {sodium_mg}mg, 당류 {sugar_g}g."
    )
    _safe(db, user_id, text, domain="diet", source="diet")
