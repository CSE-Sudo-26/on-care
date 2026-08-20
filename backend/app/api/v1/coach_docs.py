"""
RAG 문서 관리 라우터.

  POST /coach/documents/public  -> 공공문서 적재 (user_id=NULL, 전체 공유)
       body: { content, domain, title }

개인 환자 데이터는 식단/운동 기록 생성 시 자동 적재하는 방식을 권장하므로
여기서는 공공문서 업로드만 노출합니다. (스크립트 scripts/ingest_public 도 동일 기능)

관리자 전용입니다 — 비관리자는 403, 미인증은 401. 적재는 감사 로그에 남습니다.
"""
from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.deps import RequireAdmin
from app.db.session import get_db
from app.services.audit import client_ip, record as audit
from app.services.coach.rag import ingest_document

router = APIRouter(tags=["coach-docs"])


class PublicDocIn(BaseModel):
    content: str
    domain: str = "general"  # diet|exercise|general
    title: str = ""
    source: str = "public"


@router.post("/coach/documents/public", status_code=201)
def upload_public_doc(
    payload: PublicDocIn,
    admin: RequireAdmin,  # 관리자 전용(비관리자 403, 미인증 401)
    request: Request,
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    if not payload.content.strip():
        raise HTTPException(status_code=400, detail="content 가 비어 있습니다.")
    try:
        n = ingest_document(
            db, payload.content, user_id=None,
            domain=payload.domain, source=payload.source, title=payload.title,
        )
    except RuntimeError as e:
        # 임베딩 키 미설정 등
        raise HTTPException(status_code=503, detail=f"임베딩 불가: {e}")
    except Exception as e:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"적재 실패: {e}")
    audit(
        db, event="admin.public_doc_upload", user_id=admin.id,
        ip=client_ip(request), success=True, detail=f"{payload.domain}:{payload.title}",
    )
    return {"ingested_chunks": n, "domain": payload.domain, "title": payload.title}
