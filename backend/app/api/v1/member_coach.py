"""
회원측 트레이너 미러 — 회원 앱이 '내 담당 코치'와 상호작용하는 엔드포인트.

트레이너 앱(#251/#252)이 쓰는 것과 같은 공유 테이블(ChatMessage, TrainerRoutine,
TrainerSchedule, TrainerClient)을 회원 관점으로 읽고 쓴다. 이로써 트레이너↔회원
상호작용이 양방향으로 닫힌다(트레이너 발신→회원 수신, 회원 발신→트레이너 로스터 반영).

읽기는 CurrentUser(회원, 데모 폴백 허용, 트레이너 토큰 403)로, 쓰기는 RequireMember
(엄격, 트레이너 계정 차단)로 보호한다.
"""
from __future__ import annotations

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.deps import CurrentUser, RequireMember
from app.db.session import get_db
from app.schemas.trainer_api import (
    ChatMessageOut, ChatSendRequest, MemberCoachOut, RoutineOut, ScheduleSessionOut,
)
from app.services import trainer_service

router = APIRouter(tags=["member-coach"])


def _my_trainer_or_404(db: Session, member_id: str) -> str:
    trainer_id = trainer_service.get_member_trainer_id(db, member_id)
    if trainer_id is None:
        raise HTTPException(status_code=404, detail="담당 트레이너가 없습니다.")
    return trainer_id


@router.get("/me/coach", response_model=MemberCoachOut)
def my_coach(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> MemberCoachOut:
    """내 담당 트레이너 요약."""
    coach = trainer_service.build_member_coach(db, current_user.id)
    if coach is None:
        raise HTTPException(status_code=404, detail="담당 트레이너가 없습니다.")
    return coach


@router.delete("/me/coach", status_code=204)
def disconnect_my_coach(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> None:
    """코치 관계 전체 해제 — MY 탭의 **헬스장** 휴지통.

    `GET /me/coach` 가 트레이너와 헬스장을 함께 돌려주듯, 이 삭제도 둘 다 끊는다.
    떠난 헬스장의 트레이너를 담당으로 남길 수는 없기 때문이다. 트레이너만 끊으려면
    `DELETE /me/coach/trainer` 를 쓴다. (#444)

    이미 연결이 없으면 404 가 아니라 204 다. 해제는 멱등이어야 하고, 두 번 눌렀다고
    오류 화면을 보일 이유가 없다.
    """
    trainer_service.disconnect_member_gym(db, current_user.id)


@router.delete("/me/coach/trainer", status_code=204)
def disconnect_my_trainer(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> None:
    """담당 트레이너만 해제 — 헬스장 연결은 남는다. MY 탭의 **트레이너** 휴지통.

    헬스장은 그대로 두고 담당만 바꾸는 흐름(트레이너 교체)이 있어야 하므로 전체
    해제와 나눈다. 전체 해제와 마찬가지로 멱등이다. (#444)
    """
    trainer_service.disconnect_member_coach(db, current_user.id)


@router.get("/me/coach/routines", response_model=list[RoutineOut])
def my_routines(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> list[RoutineOut]:
    """트레이너/AI가 나에게 배정한 루틴."""
    return trainer_service.build_member_routines(db, current_user.id)


@router.get("/me/coach/sessions", response_model=list[ScheduleSessionOut])
def my_sessions(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> list[ScheduleSessionOut]:
    """내 PT 세션(담당 트레이너 스케줄에서 나와 매칭된 것), 최신순."""
    return trainer_service.build_member_sessions(db, current_user.id)


@router.get("/me/coach/chat", response_model=list[ChatMessageOut])
def my_chat(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
    limit: int = Query(50, ge=1, le=100),
    before: str | None = Query(None, description="ISO datetime 커서(이전 페이지, 응답 created_at)"),
    before_id: str | None = Query(None, description="복합 커서 tie-break — 이전 페이지 가장 오래된 id"),
) -> list[ChatMessageOut]:
    """담당 트레이너와의 채팅(오래된→최신). 발신자는 회원 관점(me|trainer)."""
    trainer_id = _my_trainer_or_404(db, current_user.id)
    before_dt: datetime | None = None
    if before:
        try:
            before_dt = datetime.fromisoformat(before)
        except ValueError as e:
            raise HTTPException(status_code=422, detail="before 는 ISO datetime 이어야 합니다.") from e
    return trainer_service.build_chat_thread(
        db, trainer_id, current_user.id,
        limit=limit, before=before_dt, before_id=before_id, viewer="member",
    )


@router.get("/me/coach/chat/unread", response_model=dict)
def my_unread(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    """트레이너가 보낸 미확인 메시지 수."""
    trainer_id = trainer_service.get_member_trainer_id(db, current_user.id)
    count = trainer_service.member_unread_count(db, trainer_id, current_user.id) if trainer_id else 0
    return {"unread": count}


@router.post("/me/coach/chat", response_model=ChatMessageOut, status_code=201)
def send_to_coach(
    payload: ChatSendRequest,
    member: RequireMember,
    db: Annotated[Session, Depends(get_db)],
) -> ChatMessageOut:
    """회원이 담당 트레이너에게 메시지 발신(트레이너 로스터 last_message 에 자동 반영)."""
    trainer_id = _my_trainer_or_404(db, member.id)
    text = payload.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="빈 메시지는 보낼 수 없습니다.")
    return trainer_service.send_message(
        db, trainer_id, member.id, "member", text, viewer="member",
    )


@router.post("/me/coach/chat/read")
def mark_coach_chat_read(
    member: RequireMember,
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    """담당 트레이너 스레드를 읽음 처리(트레이너 발신 메시지)."""
    trainer_id = _my_trainer_or_404(db, member.id)
    n = trainer_service.mark_thread_read(db, trainer_id, member.id, "member")
    return {"marked_read": n}
