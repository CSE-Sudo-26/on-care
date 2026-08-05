"""
트레이너 API 스키마 — 트레이너 프론트 계약(seedTrainerProfile / TrainerProfile) 정렬.

GET /trainer/me 응답:
  { id, name, email, phone, specialty, career, intro, certifications[], gym{...} }
"""
from __future__ import annotations

from datetime import date as _date, datetime as _datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator


def _validate_ymd(v: str) -> str:
    try:
        _date.fromisoformat(v)  # 2026-99-99 / 2026-02-31 등 달력상 불가능한 값 거부
    except ValueError as e:
        raise ValueError("유효한 날짜(YYYY-MM-DD)가 아닙니다.") from e
    return v


def _validate_hhmm(v: str) -> str:
    try:
        _datetime.strptime(v, "%H:%M")  # 25:99 / 빈 문자열 등 거부
    except ValueError as e:
        raise ValueError("유효한 시간(HH:MM)이 아닙니다.") from e
    return v


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
    sugar_g: float               # 오늘 총 당류(소수)
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


# 채팅 sender 출력 허용값 — 뷰어 관점(_sender_out): 트레이너 앱은 trainer|client,
# 회원 앱은 me|trainer.
ChatSender = Literal["trainer", "client", "me"]


class ChatMessageOut(BaseModel):
    """채팅 메시지 — 프론트 ClientChatMessage 계약 정렬.

    sender 는 프론트 계약에 맞춰 'trainer'|'client' 로 노출(백엔드 저장값 member→client).
    created_at(ISO)은 프론트 createdAt 이자 페이지네이션 커서다. 이전 페이지는 이 스레드
    가장 오래된 메시지의 (created_at, id)를 before/before_id 로 넘겨 요청한다.
    """
    id: str
    sender: ChatSender  # trainer|client(트레이너 뷰) | me|trainer(회원 뷰)
    body: str
    time_label: str    # "18:10"
    created_at: str    # ISO datetime — 커서/정렬용


class ChatSendRequest(BaseModel):
    # 상한만 둔다(빈/공백은 라우터에서 trim 후 400). 과도한 길이는 여기서 422.
    text: str = Field(max_length=2000)


RoutineType = Literal["걷기", "유산소", "근력", "요가", "스트레칭", "기타"]
RoutineSource = Literal["ai", "trainer"]  # ai 추천 | 트레이너 직접 배정


class RoutineOut(BaseModel):
    """배정 루틴 — 프론트 ClientAiRoutine 계약 정렬."""
    id: str
    name: str
    minutes: int
    type: RoutineType
    reason: str
    source: RoutineSource


class RoutineAssignRequest(BaseModel):
    """루틴 배정 입력. 잘못된 값은 DB 500 이 아니라 422 로 거른다.

    type/source 는 허용값(Literal)만, 길이·범위는 Field 로 제한한다.
    """
    name: str = Field(min_length=1, max_length=100)
    minutes: int = Field(default=0, ge=0, le=600)   # 0..600분(현실적 상한)
    type: RoutineType
    reason: str = Field(default="", max_length=200)
    source: RoutineSource = "trainer"


RoutineIntensityPreference = Literal["low", "moderate", "high"]
RoutineOptionGenerator = Literal["ai", "rule"]


class RoutineOptionsRequest(BaseModel):
    """회원 데이터 기반 맞춤 루틴 후보 생성 조건."""

    available_minutes: int = Field(ge=10, le=180)
    intensity_preference: RoutineIntensityPreference = "moderate"
    trainer_note: str = Field(default="", max_length=500)


class RoutineOptionAnalysisOut(BaseModel):
    goal: str
    sodium_today_mg: int = Field(ge=0)
    sodium_over_target: bool
    avg_completion_rate: int = Field(ge=0, le=100)
    latest_routine: str
    note: str


class RoutineOptionExerciseOut(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    minutes: int = Field(ge=1, le=180)
    type: RoutineType


class RoutineOptionPlanOut(BaseModel):
    key: Literal["A", "B"]
    label: str = Field(min_length=1, max_length=50)
    total_minutes: int = Field(ge=1, le=180)
    intensity: str = Field(min_length=1, max_length=20)
    exercises: list[RoutineOptionExerciseOut] = Field(min_length=1, max_length=12)
    reason: str = Field(min_length=1, max_length=200)
    rationale: str = Field(min_length=1, max_length=500)

    @model_validator(mode="after")
    def _total_matches_exercises(self) -> RoutineOptionPlanOut:
        total = sum(exercise.minutes for exercise in self.exercises)
        if total != self.total_minutes:
            raise ValueError("total_minutes 는 exercises 시간 합계와 같아야 합니다.")
        return self


class RoutineOptionsOut(BaseModel):
    analysis: RoutineOptionAnalysisOut
    plan_a: RoutineOptionPlanOut
    plan_b: RoutineOptionPlanOut
    generated_by: RoutineOptionGenerator

    @model_validator(mode="after")
    def _requires_distinct_a_and_b(self) -> RoutineOptionsOut:
        if self.plan_a.key != "A" or self.plan_b.key != "B":
            raise ValueError("plan_a/plan_b key 는 각각 A/B여야 합니다.")
        return self


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
    date: str = Field(max_length=10)
    time: str = Field(max_length=10)
    client_name: str = Field(default="", max_length=100)
    member_id: str | None = Field(default=None, max_length=64)
    type: str = Field(default="", max_length=30)
    duration_minutes: int = Field(default=0, ge=0, le=600)
    note: str = Field(default="", max_length=500)
    program: list[ProgramItem] = Field(default_factory=list, max_length=30)

    _v_date = field_validator("date")(_validate_ymd)
    _v_time = field_validator("time")(_validate_hhmm)


class ScheduleUpdateRequest(BaseModel):
    """부분 수정 — 제공된 필드만 반영."""
    time: str | None = Field(default=None, max_length=10)
    client_name: str | None = Field(default=None, max_length=100)
    member_id: str | None = Field(default=None, max_length=64)
    type: str | None = Field(default=None, max_length=30)
    duration_minutes: int | None = Field(default=None, ge=0, le=600)
    note: str | None = Field(default=None, max_length=500)
    program: list[ProgramItem] | None = Field(default=None, max_length=30)

    @field_validator("time")
    @classmethod
    def _v_time(cls, v: str | None) -> str | None:
        return _validate_hhmm(v) if v is not None else v

    @model_validator(mode="after")
    def _reject_null_for_non_nullable_fields(self) -> ScheduleUpdateRequest:
        """부분 수정에서 명시적 null은 member_id(배정 해제)에만 허용한다.

        나머지 필드는 DB NOT NULL 컬럼이므로 null을 그대로 반영하면 IntegrityError 500이
        발생한다. 누락은 변경 없음, member_id null은 배정 해제, 그 외 null은 422로 구분한다.
        """
        nullable = {"member_id"}
        for field in self.model_fields_set - nullable:
            if getattr(self, field) is None:
                raise ValueError(f"{field}에는 null을 사용할 수 없습니다.")
        return self


class ScheduleCompleteRequest(BaseModel):
    note: str = Field(default="", max_length=500)


# ---- 회원측 미러 (내 담당 코치 / 받은 루틴 / 채팅) ----

class MemberCoachOut(BaseModel):
    """회원 앱의 '내 담당 트레이너' 요약."""
    trainer_id: str
    name: str
    specialty: str
    career: str          # "7년"
    intro: str
    gym: TrainerGymOut
    goal: str            # 트레이너가 설정한 내 코칭 목표(TrainerClient.goal)


# ---- 트레이너 프로필 수정 ----

class TrainerMeUpdate(BaseModel):
    """PUT /trainer/me — 보낸 필드만 반영(부분 수정).

    이름/이메일은 계정(User)에 속하므로 여기서 바꾸지 않는다. 프로필 화면에서
    바꿀 수 있는 값만 노출한다.
    """
    phone: str | None = Field(default=None, max_length=20)
    specialty: str | None = Field(default=None, max_length=50)
    career_years: int | None = Field(default=None, ge=0, le=80)
    intro: str | None = Field(default=None, max_length=1000)
    certifications: list[str] | None = Field(default=None, max_length=30)
    gym_name: str | None = Field(default=None, max_length=100)
    gym_address: str | None = Field(default=None, max_length=300)
    gym_hours: str | None = Field(default=None, max_length=50)
    gym_phone: str | None = Field(default=None, max_length=20)

    @model_validator(mode="after")
    def _reject_explicit_null(self) -> TrainerMeUpdate:
        """명시적 null 을 422 로 거른다.

        여기 필드는 전부 DB NOT NULL 컬럼이라 null 을 그대로 반영하면
        IntegrityError 500 이 난다. 누락은 '변경 없음', null 은 '잘못된 값'
        으로 구분한다(ScheduleUpdateRequest 와 같은 규약).
        """
        for field in self.model_fields_set:
            if getattr(self, field) is None:
                raise ValueError(f"{field}에는 null을 사용할 수 없습니다.")
        return self


# ---- 트레이너용 AI 코칭 (회원 데이터 기반) ----

class ClientCoachRequest(BaseModel):
    """트레이너가 담당 고객에 대해 AI에게 묻는 질문."""
    message: str = Field(min_length=1, max_length=1000)


class ClientCoachOut(BaseModel):
    """AI 답변 + 근거.

    회원 앱의 `/ai-coach/chat` 과 같은 RAG 파이프라인이지만, 검색 스코프가
    **호출한 트레이너가 아니라 담당 회원**이라는 점이 다르다 — 트레이너가
    자기 자신의(비어 있는) 기록으로 코칭받는 일이 없도록.
    """
    member_id: str
    reply: str
    sources: list[str] = []


# ---- 주간 리포트 (트레이너 → 회원) ----

class WeeklyReportOut(BaseModel):
    """담당 고객 한 명의 한 주 — 트레이너가 회원에게 보낼 수 있는 요약."""
    member_id: str
    member_name: str
    week_start: str              # YYYY-MM-DD (월요일)
    week_end: str                # YYYY-MM-DD (일요일)
    sessions_booked: int
    sessions_done: int
    completion_avg: int | None   # 기록이 없으면 null (0% 아님)
    sodium_over_days: int
    sodium_avg: int | None
    message: str                 # 회원에게 전송될 본문(미리보기와 동일)


class ReportSendRequest(BaseModel):
    """리포트 전송 — 본문을 직접 주면 그것을, 없으면 서버 생성본을 보낸다."""
    week_start: str | None = Field(default=None, description="YYYY-MM-DD (기본: 이번 주)")
    message: str | None = Field(default=None, max_length=2000)


class TrainerPasswordChange(BaseModel):
    """비밀번호 변경 — 현재 비밀번호 확인 후 교체.

    현재 비밀번호를 요구하는 이유: 토큰이 탈취된 상태에서 비밀번호까지
    바꿔 계정을 완전히 뺏기는 경로를 막는다.
    """
    current_password: str = Field(min_length=1, max_length=200)
    new_password: str = Field(min_length=8, max_length=200)


# ---- 알림 수신 설정 (#379) ----

#: 세션 알림 시점 선택지(분). 앱의 SegmentedSwitch 와 같은 목록 — 서버가
#: 계약을 소유하고, 클라이언트는 이 중에서만 고른다.
REMINDER_LEAD_OPTIONS: tuple[int, ...] = (10, 30, 60)


class TrainerNotificationSettings(BaseModel):
    """트레이너 알림 수신 설정."""
    notify_new_message: bool
    notify_session_reminder: bool
    reminder_lead_minutes: int


class TrainerNotificationSettingsUpdate(BaseModel):
    """부분 수정 — 보낸 필드만 반영."""
    notify_new_message: bool | None = None
    notify_session_reminder: bool | None = None
    reminder_lead_minutes: int | None = None

    @field_validator("reminder_lead_minutes")
    @classmethod
    def _v_lead(cls, v: int | None) -> int | None:
        if v is not None and v not in REMINDER_LEAD_OPTIONS:
            raise ValueError(
                f"reminder_lead_minutes 는 {list(REMINDER_LEAD_OPTIONS)} 중 하나여야 합니다."
            )
        return v

    @model_validator(mode="after")
    def _reject_explicit_null(self) -> TrainerNotificationSettingsUpdate:
        """명시적 null 을 422 로 거른다.

        세 컬럼 모두 DB NOT NULL 이라 null 을 그대로 반영하면 IntegrityError
        500 이 난다. 누락은 '변경 없음', null 은 '잘못된 값' 으로 구분한다
        (TrainerMeUpdate · ScheduleUpdateRequest 와 같은 규약).
        """
        for field in self.model_fields_set:
            if getattr(self, field) is None:
                raise ValueError(f"{field}에는 null을 사용할 수 없습니다.")
        return self
