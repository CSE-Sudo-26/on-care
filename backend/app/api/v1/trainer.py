"""
트레이너 라우터 — 트레이너 앱 전용(role == 'trainer').

  GET /trainer/me   -> 로그인한 트레이너의 프로필(Figma MY / seedTrainerProfile)

이후 이슈에서 /trainer/clients, /trainer/clients/{id}/diet(회원 실데이터 공유),
채팅·루틴·스케줄이 이 라우터에 추가된다. 모든 엔드포인트는 RequireTrainer 로
보호되며 데모 폴백이 없다(회원 데모 사용자 유입 차단).
"""
from __future__ import annotations

import json
import re
from datetime import date as _date
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import RequireTrainer
from app.db.session import get_db
from app.models.models import TrainerClient, TrainerProfile
from app.schemas.trainer_api import (
    ChatMessageOut, ChatSendRequest, ClientDietEntryOut, RoutineAssignRequest, RoutineOut,
    RoutineHistoryOut, RoutineOptionsOut, RoutineOptionsRequest,
    ScheduleCompleteRequest, ScheduleCreateRequest, ScheduleSessionOut,
    ScheduleUpdateRequest, TrainerClientOut, TrainerGymOut, TrainerMe,
)
from app.services import trainer_routine_options_service, trainer_service

router = APIRouter(tags=["trainer"])

# 계약 형식은 정확히 YYYY-MM-DD. date.fromisoformat 는 3.11+ 에서 basic ISO·주 날짜도 받으므로
# 정규식으로 먼저 좁힌 뒤 달력 유효성을 확인한다(schedule 라우트와 동일 규약).
_YMD_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def _is_ymd(v: str) -> bool:
    if not _YMD_RE.fullmatch(v):
        return False
    try:
        _date.fromisoformat(v)
        return True
    except ValueError:
        return False


def _require_client(db: Session, trainer_id: str, member_id: str) -> TrainerClient:
    """(trainer, member) 담당 링크를 확인. 남의 고객/미담당이면 404(소유권 경계)."""
    link = db.scalar(
        select(TrainerClient).where(
            TrainerClient.trainer_id == trainer_id,
            TrainerClient.member_id == member_id,
        )
    )
    if link is None:
        raise HTTPException(status_code=404, detail="담당 고객을 찾을 수 없습니다.")
    return link


@router.get("/trainer/me", response_model=TrainerMe)
def trainer_me(
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> TrainerMe:
    profile = db.scalar(
        select(TrainerProfile).where(TrainerProfile.trainer_id == trainer.id)
    )
    if profile is None:
        raise HTTPException(status_code=404, detail="트레이너 프로필이 없습니다.")

    try:
        certs = json.loads(profile.certifications_json) if profile.certifications_json else []
    except json.JSONDecodeError:
        certs = []
    if not isinstance(certs, list) or not all(
        isinstance(cert, str) for cert in certs
    ):
        certs = []

    return TrainerMe(
        id=trainer.id,
        name=trainer.name,
        email=trainer.email,
        phone=profile.phone,
        specialty=profile.specialty,
        career=f"{profile.career_years}년",
        intro=profile.intro,
        certifications=certs,
        gym=TrainerGymOut(
            name=profile.gym_name,
            address=profile.gym_address,
            hours=profile.gym_hours,
            phone=profile.gym_phone,
        ),
    )


@router.get("/trainer/clients", response_model=list[TrainerClientOut])
def trainer_clients(
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> list[TrainerClientOut]:
    """담당 고객 로스터. 각 카드의 오늘 칼로리/나트륨/당류와 나트륨 추세는
    회원의 실제 식단 기록(DietEntry)에서 집계한다 — 트레이너↔회원 실데이터 공유."""
    return trainer_service.build_roster(db, trainer.id)


@router.get("/trainer/clients/{member_id}/diet", response_model=list[ClientDietEntryOut])
def trainer_client_diet(
    member_id: str,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
    date: str | None = Query(None, description="YYYY-MM-DD (기본: 오늘)"),
) -> list[ClientDietEntryOut]:
    """담당 고객의 식단(회원이 회원 앱에서 기록한 실제 데이터)."""
    _require_client(db, trainer.id, member_id)
    day = date or trainer_service.today_iso()
    # 형식 검증 — 잘못된 date 가 조용히 빈 목록으로 나가지 않게 422(캘린더 라우트와 일관, #278).
    if not _is_ymd(day):
        raise HTTPException(status_code=422, detail="date 는 YYYY-MM-DD 형식이어야 합니다.")
    return trainer_service.build_client_diet(db, member_id, day)


@router.get("/trainer/clients/{member_id}/history", response_model=list[RoutineHistoryOut])
def trainer_client_history(
    member_id: str,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> list[RoutineHistoryOut]:
    """담당 고객의 운동 완료 기록(최신순). 타 트레이너 기록/메모는 제외한다."""
    _require_client(db, trainer.id, member_id)
    return trainer_service.build_client_history(db, member_id, trainer.id)


# ---- 채팅 (트레이너↔회원) ----

@router.get("/trainer/chat/unread", response_model=dict[str, int])
def trainer_chat_unread(
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> dict[str, int]:
    """회원별 미확인 메시지 수(회원 발신·미읽음). 고객 목록 배지용."""
    return trainer_service.unread_counts_for_trainer(db, trainer.id)


@router.get("/trainer/clients/{member_id}/chat", response_model=list[ChatMessageOut])
def trainer_client_chat(
    member_id: str,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
    limit: int = Query(50, ge=1, le=100, description="한 번에 가져올 최신 메시지 수"),
    before: str | None = Query(
        None, description="ISO datetime 커서 — 이전 페이지 요청(응답 created_at 사용)"
    ),
    before_id: str | None = Query(
        None, description="복합 커서 tie-break — 이전 페이지 가장 오래된 메시지의 id"
    ),
) -> list[ChatMessageOut]:
    """담당 고객과의 채팅 스레드(오래된→최신). 기본 최신 50건, (before, before_id)로 이전 페이지."""
    _require_client(db, trainer.id, member_id)
    before_dt: datetime | None = None
    if before:
        try:
            before_dt = datetime.fromisoformat(before)
        except ValueError as e:
            raise HTTPException(
                status_code=422, detail="before 는 ISO datetime 형식이어야 합니다."
            ) from e
    return trainer_service.build_chat_thread(
        db, trainer.id, member_id, limit=limit, before=before_dt, before_id=before_id
    )


@router.post("/trainer/clients/{member_id}/chat", response_model=ChatMessageOut, status_code=201)
def trainer_send_chat(
    member_id: str,
    payload: ChatSendRequest,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> ChatMessageOut:
    """트레이너가 담당 고객에게 메시지 발신."""
    _require_client(db, trainer.id, member_id)
    text = payload.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="빈 메시지는 보낼 수 없습니다.")
    return trainer_service.send_message(db, trainer.id, member_id, "trainer", text)


@router.post("/trainer/clients/{member_id}/chat/read")
def trainer_mark_chat_read(
    member_id: str,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    """트레이너가 해당 고객 스레드를 읽음 처리."""
    _require_client(db, trainer.id, member_id)
    n = trainer_service.mark_thread_read(db, trainer.id, member_id, "trainer")
    return {"marked_read": n}


# ---- 루틴 배정 (트레이너/AI → 회원) ----

@router.get("/trainer/clients/{member_id}/routines", response_model=list[RoutineOut])
def trainer_client_routines(
    member_id: str,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> list[RoutineOut]:
    """담당 고객에게 배정된 루틴 목록."""
    _require_client(db, trainer.id, member_id)
    return trainer_service.build_routines(db, member_id, trainer.id)


@router.post("/trainer/clients/{member_id}/routines", response_model=RoutineOut, status_code=201)
def trainer_assign_routine(
    member_id: str,
    payload: RoutineAssignRequest,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> RoutineOut:
    """담당 고객에게 루틴 배정(트레이너 직접 또는 AI 추천)."""
    _require_client(db, trainer.id, member_id)
    # type/source/길이·범위는 RoutineAssignRequest(Field/Literal)가 이미 422 로 거른다.
    # 공백만 있는 이름은 trim 후 400.
    if not payload.name.strip():
        raise HTTPException(status_code=400, detail="루틴 이름이 필요합니다.")
    return trainer_service.assign_routine(
        db, trainer.id, member_id,
        name=payload.name.strip(), minutes=payload.minutes,
        type_=payload.type, reason=payload.reason, source=payload.source,
    )


@router.post(
    "/trainer/clients/{member_id}/routine-options",
    response_model=RoutineOptionsOut,
)
def trainer_routine_options(
    member_id: str,
    payload: RoutineOptionsRequest,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> RoutineOptionsOut:
    """회원 실데이터를 LLM에 전달해 두 개의 맞춤 루틴 후보를 생성한다.

    설정된 AI 공급자를 사용할 수 없거나 응답 계약이 잘못되면 동일 응답 형태의
    규칙 기반 후보로 폴백한다.
    """
    _require_client(db, trainer.id, member_id)
    return trainer_routine_options_service.generate_routine_options(
        db,
        trainer.id,
        member_id,
        payload,
    )


# ---- 스케줄 (트레이너 타임라인 + 예약→수업→기록 완료 루프) ----

@router.get("/trainer/schedule/booked-dates", response_model=list[str])
def trainer_booked_dates(
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> list[str]:
    """예약이 있는(공백 아닌) 날짜 목록 — 주간 스트립 도트용."""
    return trainer_service.booked_dates(db, trainer.id)


@router.get("/trainer/schedule", response_model=list[ScheduleSessionOut])
def trainer_schedule(
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
    date: str | None = Query(None, description="YYYY-MM-DD (기본: 오늘)"),
) -> list[ScheduleSessionOut]:
    """하루 타임라인(시간순, 공백 포함)."""
    day = date or trainer_service.today_iso()
    return trainer_service.build_schedule(db, trainer.id, day)


@router.post("/trainer/schedule", response_model=ScheduleSessionOut, status_code=201)
def trainer_create_session(
    payload: ScheduleCreateRequest,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> ScheduleSessionOut:
    """예약 추가(status 예정). member_id 를 주면 담당 고객이어야 한다(아니면 404)."""
    if payload.member_id:
        _require_client(db, trainer.id, payload.member_id)
    return trainer_service.create_session(
        db, trainer.id,
        date=payload.date, time=payload.time, client_name=payload.client_name,
        member_id=payload.member_id, type_=payload.type,
        duration_minutes=payload.duration_minutes, note=payload.note,
        program=payload.program,
    )


@router.put("/trainer/schedule/{session_id}", response_model=ScheduleSessionOut)
def trainer_update_session(
    session_id: str,
    payload: ScheduleUpdateRequest,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> ScheduleSessionOut:
    """예약 수정(제공된 필드만). member_id 변경 시 담당 고객이어야 한다.
    완료된 세션은 기록과의 정합성을 위해 수정 불가(409)."""
    fields = payload.model_dump(exclude_unset=True)
    if fields.get("member_id"):
        _require_client(db, trainer.id, fields["member_id"])
    try:
        out = trainer_service.update_session(db, trainer.id, session_id, fields)
    except trainer_service.ScheduleConflict as e:
        raise HTTPException(status_code=409, detail=str(e)) from e
    if out is None:
        raise HTTPException(status_code=404, detail="일정을 찾을 수 없습니다.")
    return out


@router.delete("/trainer/schedule/{session_id}")
def trainer_delete_session(
    session_id: str,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    """예약 삭제."""
    if not trainer_service.delete_session(db, trainer.id, session_id):
        raise HTTPException(status_code=404, detail="일정을 찾을 수 없습니다.")
    return {"status": "deleted"}


@router.post("/trainer/schedule/{session_id}/complete", response_model=ScheduleSessionOut)
def trainer_complete_session(
    session_id: str,
    payload: ScheduleCompleteRequest,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> ScheduleSessionOut:
    """세션 완료(예정→완료). 매칭된 회원이 있으면 운동기록으로 적재."""
    try:
        out = trainer_service.complete_session(db, trainer.id, session_id, payload.note)
    except trainer_service.ScheduleError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    if out is None:
        raise HTTPException(status_code=404, detail="일정을 찾을 수 없습니다.")
    return out
