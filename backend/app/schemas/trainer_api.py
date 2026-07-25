"""
트레이너 API 스키마 — 트레이너 프론트 계약(seedTrainerProfile / TrainerProfile) 정렬.

GET /trainer/me 응답:
  { id, name, email, phone, specialty, career, intro, certifications[], gym{...} }
"""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class TrainerGymOut(BaseModel):
    name: str
    address: str
    hours: str
    phone: str


class TrainerMe(BaseModel):
    id: str
    name: str
    email: str
    phone: str
    specialty: str
    career: str          # "7년" (career_years 파생)
    intro: str
    certifications: list[str]
    gym: TrainerGymOut


class TrainerClientOut(BaseModel):
    """고객 로스터 카드 — 프론트 TrainerClient 계약 정렬.

    id 는 회원 User id(하위 엔드포인트 키). calories/sodium_mg/sugar_g 는 회원의
    실제 오늘 식단(DietEntry)에서 집계한 값이다(진짜 데이터 공유).
    """
    id: str                      # member_id — /trainer/clients/{id}/... 키
    name: str
    avatar: str
    goal: str
    last_message: str
    last_time: str
    active: bool
    calories: int                # 오늘 총 칼로리(회원 실데이터)
    sodium_mg: int               # 오늘 총 나트륨
    sugar_g: int                 # 오늘 총 당류
    last_routine: str            # 마지막 루틴 전송 라벨(오늘/어제/N일 전)
    week_completion: list[int]   # 이번 주 일별 완료율 7개(월→일)
    sodium_week: list[int]       # 최근 7일 일별 나트륨(오래된→오늘)


class ClientDietEntryOut(BaseModel):
    """고객 식단 서브탭 한 끼 — 프론트 ClientDietEntry 계약 정렬."""
    meal: str        # 아침|점심|저녁|간식
    items: str       # 음식명 나열
    calories: int
    sodium_mg: int


class RoutineHistoryOut(BaseModel):
    """고객 운동기록 서브탭 항목 — 프론트 RoutineHistoryEntry 계약 정렬."""
    date_label: str          # "7/12 (오늘)"
    label: str               # "PT 세션 · 트레이너 지도"
    completion_rate: int     # 0..100
    exercises: list[str]
    client_feedback: str
    trainer_note: str


class ChatMessageOut(BaseModel):
    """채팅 메시지 — 프론트 ClientChatMessage 계약 정렬.

    sender 는 프론트 계약에 맞춰 'trainer'|'client' 로 노출(백엔드 저장값 member→client).
    created_at(ISO)은 프론트 createdAt 이자 페이지네이션 커서다. 이전 페이지는 이 스레드
    가장 오래된 메시지의 (created_at, id)를 before/before_id 로 넘겨 요청한다.
    """
    id: str
    sender: str        # trainer|client
    body: str
    time_label: str    # "18:10"
    created_at: str    # ISO datetime — 커서/정렬용


class ChatSendRequest(BaseModel):
    # 상한만 둔다(빈/공백은 라우터에서 trim 후 400). 과도한 길이는 여기서 422.
    text: str = Field(max_length=2000)


RoutineType = Literal["유산소", "근력", "스트레칭"]


class RoutineOut(BaseModel):
    """배정 루틴 — 프론트 ClientAiRoutine 계약 정렬."""
    id: str
    name: str
    minutes: int
    type: str          # 유산소|근력|스트레칭
    reason: str
    source: str        # ai|trainer


class RoutineAssignRequest(BaseModel):
    """루틴 배정 입력. 잘못된 값은 DB 500 이 아니라 422 로 거른다.

    type/source 는 허용값(Literal)만, 길이·범위는 Field 로 제한한다.
    """
    name: str = Field(min_length=1, max_length=100)
    minutes: int = Field(default=0, ge=0, le=600)   # 0..600분(현실적 상한)
    type: RoutineType
    reason: str = Field(default="", max_length=200)
    source: Literal["trainer", "ai"] = "trainer"


# ---- 스케줄 (트레이너 타임라인 + 예약→수업→기록 루프) ----

ScheduleStatus = Literal["예정", "완료", "공백"]


class ProgramItem(BaseModel):
    """세션 프로그램 한 항목 — 프론트 ProgramItem 계약({name,sets,reps,weight})."""
    name: str = Field(min_length=1, max_length=100)
    sets: int = Field(default=0, ge=0, le=99)
    reps: str = Field(default="", max_length=30)
    weight: str = Field(default="", max_length=30)


class ScheduleSessionOut(BaseModel):
    """스케줄 슬롯 — 프론트 ScheduleSession 계약 정렬."""
    id: str
    date: str
    time: str
    client_name: str
    type: str
    duration_minutes: int
    status: str          # 예정|완료|공백
    note: str
    program: list[ProgramItem]


class ScheduleCreateRequest(BaseModel):
    date: str = Field(pattern=r"^\d{4}-\d{2}-\d{2}$")
    time: str = Field(max_length=10)
    client_name: str = Field(default="", max_length=100)
    member_id: str | None = Field(default=None, max_length=64)
    type: str = Field(default="", max_length=30)
    duration_minutes: int = Field(default=0, ge=0, le=600)
    note: str = Field(default="", max_length=500)
    program: list[ProgramItem] = Field(default_factory=list, max_length=30)


class ScheduleUpdateRequest(BaseModel):
    """부분 수정 — 제공된 필드만 반영."""
    time: str | None = Field(default=None, max_length=10)
    client_name: str | None = Field(default=None, max_length=100)
    member_id: str | None = Field(default=None, max_length=64)
    type: str | None = Field(default=None, max_length=30)
    duration_minutes: int | None = Field(default=None, ge=0, le=600)
    note: str | None = Field(default=None, max_length=500)
    program: list[ProgramItem] | None = Field(default=None, max_length=30)


class ScheduleCompleteRequest(BaseModel):
    note: str = Field(default="", max_length=500)
