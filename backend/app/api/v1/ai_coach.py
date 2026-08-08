"""
AI 코치 라우터 — 프론트 계약 정렬.

  GET  /ai-coach/feedback  -> { greeting, suggestions[] }
  GET  /ai-coach/messages  -> 저장된 대화 복원
  POST /ai-coach/chat      -> RAG 근거 기반 답변 + 대화 저장

도메인(식단/운동)별 코치를 각각 생성해 합친 결과.
STEP 7에서 내부가 RAG+LLM 으로 교체되지만 응답 형식은 동일.
"""
from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import CurrentUser
from app.core.config import get_settings
from app.core.rate_limit import rate_limit
from app.db.session import get_db
from app.schemas.misc_api import (
    AiCoachFeedback,
    ChatHistory,
    ChatMessageOut,
    ChatReply,
    ChatRequest,
)
from app.services.coach import conversation
from app.services.coach.chat import answer
from app.services.coach_service import build_feedback

router = APIRouter(tags=["ai-coach"])


@router.get("/ai-coach/feedback", response_model=AiCoachFeedback)
def ai_coach_feedback(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> AiCoachFeedback:
    return build_feedback(db, current_user.id, current_user.name)


@router.get("/ai-coach/messages", response_model=ChatHistory)
def ai_coach_messages(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> ChatHistory:
    """저장된 대화 복원 — 재접속·다기기에서 히스토리를 잇는다.

    아직 한 마디도 나누지 않았으면 빈 목록이다(이 경로는 대화 스레드를 만들지 않는다).
    """
    rows = conversation.load_messages(db, current_user.id)
    return ChatHistory(
        messages=[
            ChatMessageOut(
                role=m.role,
                content=m.content,
                sources=conversation.parse_sources(m.sources_json),
                created_at=m.created_at,
            )
            for m in rows
        ]
    )


@router.post(
    "/ai-coach/chat",
    response_model=ChatReply,
    dependencies=[
        Depends(rate_limit("coach-chat", get_settings().coach_chat_per_minute))
    ],
)
def ai_coach_chat(
    payload: ChatRequest,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> ChatReply:
    """대화형 코칭: RAG 근거 기반 답변(개인/공공 격리). LLM 키 없으면 검색 기반 폴백.

    대화는 서버에 저장된다. 히스토리도 서버 저장분을 우선 쓰므로 클라이언트가
    `history` 를 보내지 않아도 맥락이 이어진다. 다만 저장분이 아직 없을 때는
    요청에 실려 온 `history` 를 쓴다 — 목업 모드로 대화하다 실 서버로 전환한
    클라이언트의 맥락을 버리지 않기 위해서다.
    """
    message = payload.message.strip()
    if not message:
        raise HTTPException(status_code=400, detail="메시지가 비어 있습니다.")

    stored = conversation.load_messages(db, current_user.id)
    history = stored or payload.history

    reply, sources = answer(db, current_user.id, message, history)
    conversation.append_exchange(
        db, current_user.id, question=message, reply=reply, sources=sources
    )
    return ChatReply(reply=reply, sources=sources)
