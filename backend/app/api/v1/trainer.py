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
from app.core.security import hash_password, verify_password
from app.db.session import get_db
from app.models.models import TrainerClient, TrainerProfile
from app.schemas.consultation_api import (
    ConsultationDecision,
    ConsultationStatusFilter,
    TrainerConsultationOut,
)
from app.schemas.trainer_api import (
    ChatMessageOut, ChatSendRequest, ClientCoachOut, ClientCoachRequest, ClientDietEntryOut,
    ReportSendRequest, RoutineAssignRequest, RoutineOut, RoutineHistoryOut,
    RoutineOptionsOut, RoutineOptionsRequest,
    ScheduleCompleteRequest, ScheduleCreateRequest, ScheduleSessionOut, ScheduleUpdateRequest,
    TrainerClientOut, TrainerGymAffiliation, TrainerMe, TrainerMeUpdate,
    TrainerNotificationSettings, TrainerNotificationSettingsUpdate,
    TrainerPasswordChange, WeeklyReportOut,
)
from app.services import (
    consultation_service,
    notification_service,
    trainer_routine_options_service,
    trainer_service,
)
from app.services.coach.chat import answer as coach_answer

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


def _require_profile(db: Session, trainer_id: str) -> TrainerProfile:
    profile = db.scalar(
        select(TrainerProfile).where(TrainerProfile.trainer_id == trainer_id)
    )
    if profile is None:
        raise HTTPException(status_code=404, detail="트레이너 프로필이 없습니다.")
    return profile


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


def _decide(
    action,
    db: Session,
    trainer_id: str,
    consultation_id: str,
    payload: ConsultationDecision,
) -> TrainerConsultationOut:
    """승인·거절 공통 예외 매핑. 두 라우트가 같은 실패 모드를 갖는다. (#467)

    남의 헬스장 요청을 404 로 돌리는 것은 의도다 — 403 은 그 id 의 요청이 존재한다는
    사실을 알려 주어 id 를 훑는 것만으로 남의 상담 건수를 셀 수 있다.
    """
    try:
        return action(db, trainer_id, consultation_id, payload.note)
    except consultation_service.ConsultationNotFound as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except consultation_service.ConsultationAlreadyDecided as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except consultation_service.MemberAlreadyCoached as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc


@router.get("/trainer/me", response_model=TrainerMe)
def trainer_me(
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> TrainerMe:
    profile = _require_profile(db, trainer.id)
    return trainer_service.build_trainer_me(trainer, profile)


@router.put("/trainer/me", response_model=TrainerMe)
def trainer_update_me(
    payload: TrainerMeUpdate,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> TrainerMe:
    """프로필 부분 수정. 보낸 필드만 반영하고, 이름/이메일은 계정 소관이라 건드리지 않는다."""
    profile = _require_profile(db, trainer.id)
    fields = payload.model_dump(exclude_unset=True)
    if not fields:
        # 빈 PATCH 를 성공으로 처리하면 클라이언트가 저장됐다고 오해한다.
        raise HTTPException(status_code=400, detail="수정할 항목이 없습니다.")
    try:
        return trainer_service.update_trainer_profile(db, trainer, profile, fields)
    except trainer_service.GymTextLockedByAffiliation as e:
        # 값이 틀린 게 아니라 소속이 설정된 상태와 충돌하는 것이라 422 가 아니라 409.
        raise HTTPException(
            status_code=409,
            detail="소속 헬스장이 설정돼 있어 헬스장 정보를 직접 수정할 수 없습니다. "
                   "PUT /trainer/me/gym 으로 소속을 바꾸세요.",
        ) from e


@router.put("/trainer/me/gym", response_model=TrainerMe)
def trainer_set_gym(
    payload: TrainerGymAffiliation,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> TrainerMe:
    """소속 헬스장 설정·변경. (#452)

    시드(`seed_gyms`)의 이름 매칭 백필 말고는 `gym_id` 를 채울 길이 없었다. 자기
    프로필만 바꿀 수 있고(`RequireTrainer` 가 토큰의 트레이너로 고정), 실재하는
    fitness Place 가 아니면 404 다.
    """
    profile = _require_profile(db, trainer.id)
    me = trainer_service.set_trainer_gym(db, trainer, profile, payload.gym_id)
    if me is None:
        raise HTTPException(status_code=404, detail="헬스장을 찾을 수 없습니다.")
    return me


@router.delete("/trainer/me/gym", response_model=TrainerMe)
def trainer_clear_gym(
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> TrainerMe:
    """소속 해제. 원래 소속이 없어도 200 — 해제는 두 번 눌러도 오류가 아니다.

    갱신된 프로필을 그대로 돌려주므로 클라이언트가 다시 GET 하지 않아도 된다.
    """
    profile = _require_profile(db, trainer.id)
    return trainer_service.clear_trainer_gym(db, trainer, profile)


@router.post("/trainer/me/password", status_code=200)
def trainer_change_password(
    payload: TrainerPasswordChange,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    """비밀번호 변경. 현재 비밀번호가 맞아야 하고, 같은 값으로는 바꿀 수 없다."""
    if not verify_password(payload.current_password, trainer.hashed_password):
        # 현재 비밀번호 불일치는 401 이 아니라 400 — 토큰은 유효하므로
        # 클라이언트가 로그아웃 처리로 오인하면 안 된다.
        raise HTTPException(status_code=400, detail="현재 비밀번호가 일치하지 않습니다.")
    if verify_password(payload.new_password, trainer.hashed_password):
        raise HTTPException(status_code=400, detail="현재와 다른 비밀번호를 입력해 주세요.")
    trainer.hashed_password = hash_password(payload.new_password)
    db.commit()
    return {"status": "changed"}


@router.delete("/trainer/me")
def trainer_delete_me(
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    """트레이너 탈퇴. 담당 회원에게 알린 뒤 계정과 딸린 데이터를 지운다. (#505)

    회원 탈퇴(`DELETE /users/me`)와 대칭이다. 담당 회원이 남아 있어도 막지 않는다 —
    막으면 담당이 있는 트레이너는 계정을 영영 지울 수 없다.
    """
    trainer_service.delete_trainer_account(db, trainer)
    return {"status": "deleted"}


@router.get("/trainer/me/settings", response_model=TrainerNotificationSettings)
def trainer_settings(
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> TrainerNotificationSettings:
    """알림 수신 설정. 기본값은 서버가 소유한다 — 클라이언트마다 기본값을
    들고 있으면 기기별로 갈라진다."""
    return trainer_service.build_notification_settings(
        _require_profile(db, trainer.id)
    )


@router.put("/trainer/me/settings", response_model=TrainerNotificationSettings)
def trainer_update_settings(
    payload: TrainerNotificationSettingsUpdate,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> TrainerNotificationSettings:
    """알림 수신 설정 부분 수정."""
    fields = payload.model_dump(exclude_unset=True)
    if not fields:
        raise HTTPException(status_code=400, detail="수정할 항목이 없습니다.")
    return trainer_service.update_notification_settings(
        db, _require_profile(db, trainer.id), fields
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
    return trainer_service.send_message(
        db, trainer.id, member_id, "trainer", text,
        notify=notification_service.TRAINER_MESSAGE,
    )


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
    from_: str | None = Query(
        None, alias="from", description="구간 시작 YYYY-MM-DD (to 와 함께)"
    ),
    to: str | None = Query(None, description="구간 끝 YYYY-MM-DD (from 과 함께)"),
    member_id: str | None = Query(None, description="담당 고객의 세션만"),
) -> list[ScheduleSessionOut]:
    """타임라인. 기본은 하루(`date`), `from`/`to` 를 주면 그 구간 전체.

    주 캘린더가 7일치를 한 번에 읽기 위해 구간 조회를 지원한다 — 하루짜리
    요청을 요일마다 반복하면 요청이 7배가 된다.

    `member_id` 만 주면 날짜 제한 없이 그 고객의 전체 세션을 준다. 고객
    상세의 루틴 이력이 필요로 하는 것이고, 구간으로 흉내내면 그 구간보다
    오래된 기록이 조용히 사라진다.
    """
    if member_id is not None:
        _require_client(db, trainer.id, member_id)

    if from_ is not None or to is not None:
        # 한쪽만 오면 어느 구간인지 알 수 없다 — 조용히 하루로 떨어뜨리면
        # 클라이언트는 구간을 받았다고 믿는다.
        if from_ is None or to is None:
            raise HTTPException(
                status_code=422, detail="from 과 to 는 함께 지정해야 합니다."
            )
        if not _is_ymd(from_) or not _is_ymd(to):
            raise HTTPException(
                status_code=422, detail="from/to 는 YYYY-MM-DD 형식이어야 합니다."
            )
        if from_ > to:
            raise HTTPException(status_code=422, detail="from 은 to 보다 늦을 수 없습니다.")
        return trainer_service.build_schedule_range(
            db, trainer.id, from_, to, member_id=member_id
        )

    if member_id is not None and date is None:
        return trainer_service.build_client_schedule(db, trainer.id, member_id)

    day = date or trainer_service.today_iso()
    if not _is_ymd(day):
        raise HTTPException(status_code=422, detail="date 는 YYYY-MM-DD 형식이어야 합니다.")
    return trainer_service.build_schedule_range(
        db, trainer.id, day, day, member_id=member_id
    )


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
    try:
        deleted = trainer_service.delete_session(db, trainer.id, session_id)
    except trainer_service.ScheduleConflict as e:
        raise HTTPException(status_code=409, detail=str(e)) from e
    if not deleted:
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


# ---- AI 코칭 (담당 고객 데이터 기반) ----

@router.post("/trainer/clients/{member_id}/ai-coach", response_model=ClientCoachOut)
def trainer_client_ai_coach(
    member_id: str,
    payload: ClientCoachRequest,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> ClientCoachOut:
    """담당 고객의 데이터를 근거로 AI에게 코칭을 묻는다.

    회원 앱의 `/ai-coach/chat` 과 같은 RAG 파이프라인이지만, 검색 스코프가
    호출자(트레이너)가 아니라 **담당 회원**이다 — 트레이너가 자기 자신의 (비어
    있는) 기록으로 코칭받는 일이 없도록. 담당 링크 확인이 접근 경계이며,
    남의 고객이면 404 로 존재조차 드러내지 않는다.
    """
    _require_client(db, trainer.id, member_id)
    message = payload.message.strip()
    if not message:
        raise HTTPException(status_code=400, detail="메시지가 비어 있습니다.")
    reply, sources = coach_answer(db, member_id, message, [])
    return ClientCoachOut(member_id=member_id, reply=reply, sources=sources)


# ---- 주간 리포트 (트레이너 → 회원) ----

@router.get("/trainer/clients/{member_id}/report", response_model=WeeklyReportOut)
def trainer_client_report(
    member_id: str,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
    week_start: str | None = Query(None, description="YYYY-MM-DD (기본: 이번 주)"),
) -> WeeklyReportOut:
    """담당 고객의 주간 리포트. 아무 요일을 줘도 그 주의 월요일로 정규화한다."""
    _require_client(db, trainer.id, member_id)
    day = week_start or trainer_service.today_iso()
    if not _is_ymd(day):
        raise HTTPException(status_code=422, detail="week_start 는 YYYY-MM-DD 형식이어야 합니다.")
    return trainer_service.build_weekly_report(
        db, trainer.id, member_id, _date.fromisoformat(day)
    )


@router.post(
    "/trainer/clients/{member_id}/report/send",
    response_model=ChatMessageOut,
    status_code=201,
)
def trainer_send_report(
    member_id: str,
    payload: ReportSendRequest,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> ChatMessageOut:
    """리포트를 회원의 채팅 스레드로 보낸다.

    별도 리포트 함을 만들지 않는 이유: 회원이 이미 읽고 있는 대화에 도착해야
    실제로 읽힌다. 본문을 직접 주면 트레이너가 손본 버전이 나가고, 없으면
    서버가 생성한 것이 나간다.
    """
    _require_client(db, trainer.id, member_id)
    day = payload.week_start or trainer_service.today_iso()
    if not _is_ymd(day):
        raise HTTPException(status_code=422, detail="week_start 는 YYYY-MM-DD 형식이어야 합니다.")
    text = (payload.message or "").strip()
    if not text:
        report = trainer_service.build_weekly_report(
            db, trainer.id, member_id, _date.fromisoformat(day)
        )
        text = report.message
    return trainer_service.send_message(
        db, trainer.id, member_id, "trainer", text,
        notify=notification_service.WEEKLY_REPORT,
    )


# ---------------------------------------------------------------------------
# 상담 인박스 — 회원↔트레이너 관계가 성립하는 지점. (#467)
#
# 회원이 보낸 상담 요청(POST /consultations)은 지금까지 pending 으로 저장된 뒤
# 아무도 볼 수 없었다. 승인이 곧 담당 링크(trainer_clients) 생성이고, 그 링크 위에서
# 고객 목록·루틴·리포트·채팅이 동작한다.
# ---------------------------------------------------------------------------


@router.get("/trainer/consultations", response_model=list[TrainerConsultationOut])
def trainer_consultations(
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
    status: Annotated[ConsultationStatusFilter, Query()] = "pending",
) -> list[TrainerConsultationOut]:
    """나를 지정한 요청 + 내 소속 헬스장으로 온 요청. 기본은 미처리만."""
    return consultation_service.list_for_trainer(db, trainer.id, status)


@router.get("/trainer/consultations/pending-count", response_model=dict[str, int])
def trainer_consultations_pending_count(
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> dict[str, int]:
    """인박스 배지용 미처리 건수."""
    return {"count": consultation_service.pending_count_for_trainer(db, trainer.id)}


@router.post(
    "/trainer/consultations/{consultation_id}/accept",
    response_model=TrainerConsultationOut,
)
def trainer_accept_consultation(
    consultation_id: str,
    payload: ConsultationDecision,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> TrainerConsultationOut:
    """상담을 승인하고 회원을 담당 고객으로 편입한다."""
    return _decide(consultation_service.accept, db, trainer.id, consultation_id, payload)


@router.post(
    "/trainer/consultations/{consultation_id}/reject",
    response_model=TrainerConsultationOut,
)
def trainer_reject_consultation(
    consultation_id: str,
    payload: ConsultationDecision,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> TrainerConsultationOut:
    """상담을 거절한다. 사유는 회원 알림 본문에 그대로 실린다."""
    return _decide(consultation_service.reject, db, trainer.id, consultation_id, payload)
