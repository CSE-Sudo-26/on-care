"""
시스템 엔드포인트 — 프론트 LocalApiInterceptor 의 _ping/_healthz/_version 과 정확히 일치.

프론트 기대 응답:
  GET /ping     -> { "message": "pong (...)" }
  GET /healthz  -> { "status": "ok", "backend": "..." }
  GET /version  -> { "api_version": "v1", "app_version": "..." }
"""
from __future__ import annotations

import logging
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.session import get_db

router = APIRouter(tags=["system"])
settings = get_settings()
logger = logging.getLogger("app.system")


@router.get("/ping")
def ping() -> dict[str, str]:
    return {"message": "pong"}


@router.get("/healthz")
def healthz() -> dict[str, str]:
    """Liveness — 프로세스 생존만 확인(DB 무관). App Runner liveness 용."""
    return {"status": "ok", "backend": "fastapi"}


@router.get("/readyz")
def readyz(db: Annotated[Session, Depends(get_db)]) -> dict[str, str]:
    """Readiness — DB 연결 가능 여부까지 확인. 실패 시 내부 상세를 숨긴 503.

    배포 검증/로드밸런서가 '트래픽 받을 준비'를 판정하는 데 쓴다(liveness 와 분리).
    """
    try:
        db.execute(text("SELECT 1"))
    except Exception:
        # 실패한 트랜잭션 상태를 롤백해 정리한다 — 같은 세션/커넥션이 이후 재사용될 때
        # 'aborted transaction' 이 남지 않도록(리뷰 #291).
        db.rollback()
        # 원인(접속 문자열 등)은 서버 로그에만. 클라이언트엔 일반화된 503.
        logger.exception("readiness check failed — DB unavailable")
        raise HTTPException(status_code=503, detail="서비스가 아직 준비되지 않았습니다.")
    return {"status": "ready"}


@router.get("/version")
def version() -> dict[str, str]:
    return {"api_version": "v1", "app_version": settings.app_version}
