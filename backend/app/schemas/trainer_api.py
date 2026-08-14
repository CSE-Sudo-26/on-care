"""
트레이너 API 스키마 — 트레이너 프론트 계약(seedTrainerProfile / TrainerProfile) 정렬.

GET /trainer/me 응답:
  { id, name, email, phone, specialty, career, intro, certifications[], gym{...} }
"""
from __future__ import annotations

from datetime import date as _date, datetime as _datetime
from typing import ClassVar, Literal

from pydantic import BaseModel, Field, field_validator, model_validator

from app.schemas.partial_update import PartialUpdate


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
    #: 소속 헬스장 id(`places.id`). 회원앱이 "내 헬스장" 카드에서 헬스장 상세로
    #: 이동하고 상담 대상을 지정하는 데 필요하다 — 이름만으로는 목록의 헬스장과
    #: 이어붙일 수 없다(#324). 아직 gym_id 가 없는 프로필은 None.
    id: str | None = None
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

    id 는 회원 User id(하위 엔드포인트 키). 영양소 필드는 회원의
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
    carbs_g: float               # 오늘 총 탄수화물(g)
    protein_g: float             # 오늘 총 단백질(g)
    fat_g: float                 # 오늘 총 지방(g)
    last_routine: str            # 마지막 루틴 전송 라벨(오늘/어제/N일 전)
    week_completion: list[int]   # 이번 주 일별 완료율 7개(월→일)
    sodium_week: list[int]       # 최근 7일 일별 나트륨(오래된→오늘)


class DashboardCoachingClientOut(BaseModel):
    """대시보드 AI 요약에 노출할 고객별 실행 가능한 코칭 인사이트."""

    member_id: str
    member_name: str
    priority: Literal["high", "medium", "low"]
    status_summary: str = Field(min_length=1, max_length=300)
    evidence: list[str] = Field(default_factory=list, max_length=3)
    exercise_focus: str = Field(min_length=1, max_length=300)
    caution: str = Field(default="", max_length=200)


class DashboardCoachingSummaryOut(BaseModel):
    """트레이너 대시보드의 오늘 AI 코칭 요약."""

    headline: str = Field(min_length=1, max_length=300)
    clients: list[DashboardCoachingClientOut] = Field(
        default_factory=list,
        max_length=3,
    )
    generated_by: Literal["ai", "rule"]
    data_as_of: _date


class MemberHealthProfileOut(BaseModel):
    member_id: str
    member_name: str
    height_cm: float | None = None
    weight_kg: float | None = None
    gender: str = ""
    conditions: str = ""
    goals: str = ""
    daily_calories: int | None = None
    daily_sodium_mg: int | None = None
    daily_sugar_g: int | None = None
    daily_carbs_g: int | None = None
    daily_protein_g: int | None = None
    daily_fat_g: int | None = None
    weekly_workout_goal: int | None = None
    weekly_exercise_minutes_goal: int | None = None
    weekly_burn_goal: int | None = None


class MemberHealthProfileUpdate(PartialUpdate):
    height_cm: float | None = Field(default=None, ge=50, le=300)
    weight_kg: float | None = Field(default=None, ge=20, le=500)
    gender: str | None = Field(default=None, pattern="^(male|female|other|)$")
    conditions: str | None = Field(default=None, max_length=1000)
    goals: str | None = Field(default=None, max_length=500)
    daily_calories: int | None = Field(default=None, ge=500, le=10000)
    daily_sodium_mg: int | None = Field(default=None, ge=0, le=50000)
    daily_sugar_g: int | None = Field(default=None, ge=0, le=1000)
    daily_carbs_g: int | None = Field(default=None, ge=0, le=2000)
    daily_protein_g: int | None = Field(default=None, ge=0, le=1000)
    daily_fat_g: int | None = Field(default=None, ge=0, le=1000)
    weekly_workout_goal: int | None = Field(default=None, ge=0, le=21)
    weekly_exercise_minutes_goal: int | None = Field(default=None, ge=0, le=10080)
    weekly_burn_goal: int | None = Field(default=None, ge=0, le=100000)

    nullable_fields: ClassVar[frozenset[str]] = frozenset(
        {
            "height_cm",
            "weight_kg",
            "daily_calories",
            "daily_sodium_mg",
            "daily_sugar_g",
            "daily_carbs_g",
            "daily_protein_g",
            "daily_fat_g",
            "weekly_workout_goal",
            "weekly_exercise_minutes_goal",
            "weekly_burn_goal",
        }
    )


class ClientDietEntryOut(BaseModel):
    """고객 식단 서브탭 한 끼 — 프론트 ClientDietEntry 계약 정렬."""
    meal: str        # 아침|점심|저녁|간식
    items: str       # 음식명 나열
    calories: int
    sodium_mg: int
    carbs_g: float
    protein_g: float
    fat_g: float
    # 회원이 올린 끼니 사진 경로(API base 기준 상대 경로). 담당 트레이너 전용
    # 경로라 회원 앱이 받는 값과 다르다. 사진이 없으면 null. (#699)
    photo_url: str | None = None


class RoutineHistoryOut(BaseModel):
    """고객 운동기록 서브탭 항목 — 프론트 RoutineHistoryEntry 계약 정렬."""
    id: str = ""
    date_label: str          # "7/12 (오늘)"
    label: str               # "PT 세션 · 트레이너 지도"
    completion_rate: int     # 0..100
    exercises: list[str]
    client_feedback: str
    trainer_note: str
    assigned_routine_id: str | None = None
    completed_at: _datetime | None = None


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
    # 발신 시도당 한 번 만들고 재시도에서 재사용한다. 선택값이라 구버전 앱도
    # 기존처럼 전송할 수 있다.
    client_request_id: str | None = Field(default=None, min_length=1, max_length=64)


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
    completed: bool = False
    completed_at: _datetime | None = None
    completed_minutes: int | None = None
    completed_intensity: str | None = None
    member_note: str = ""
    trainer_feedback: str = ""


class RoutineAssignRequest(BaseModel):
    """루틴 배정 입력. 잘못된 값은 DB 500 이 아니라 422 로 거른다.

    type/source 는 허용값(Literal)만, 길이·범위는 Field 로 제한한다.
    """
    name: str = Field(min_length=1, max_length=100)
    minutes: int = Field(default=0, ge=0, le=600)   # 0..600분(현실적 상한)
    type: RoutineType
    reason: str = Field(default="", max_length=200)
    source: RoutineSource = "trainer"
    #: 전송 시도당 클라이언트가 만드는 멱등키. 재시도 시 **같은 키를 다시 보내야**
    #: 중복 배정이 막힌다. 없으면 기존처럼 매 요청이 새 배정이다(#581).
    client_request_id: str | None = Field(default=None, max_length=64)


class RoutineUpdateRequest(PartialUpdate):
    """루틴 부분 수정. 보낸 필드만 반영한다. (#504)

    `source` 는 없다 — 그 값은 "누가 만들었나"(trainer|ai)라는 사실이지 트레이너가
    고칠 값이 아니다. AI 가 만든 루틴을 손봤다고 해서 트레이너가 만든 것이 되지는
    않는다.

    null 을 허용하는 필드가 없다. 이름·시간·종류·사유 어느 것도 '지우는 것'이
    기능이 아니라, 명시적 null 은 422 다(#495 규약).
    """

    name: str | None = Field(default=None, min_length=1, max_length=100)
    minutes: int | None = Field(default=None, ge=0, le=600)
    type: RoutineType | None = None
    reason: str | None = Field(default=None, max_length=200)


class RoutineFeedbackRequest(BaseModel):
    feedback: str = Field(min_length=1, max_length=2000)


RoutineIntensityPreference = Literal["low", "moderate", "high"]
RoutineOptionGenerator = Literal["ai", "rule"]

#: 계획의 강도 라벨. 트레이너 앱이 이 세 값을 그대로 화면에 뿌리므로 열어 두면
#: LLM 이 "아주높음" 같은 값을 반환해도 통과해 UI 가 깨진다(#585). 규칙형 생성기
#: (`routine_ai._B_LABEL`)가 내는 값과 같아야 한다 — 어긋나면 폴백이 422 가 된다.
RoutineIntensityLabel = Literal["낮음", "보통", "높음"]


class RoutineOptionsRequest(BaseModel):
    """회원 데이터 기반 맞춤 루틴 후보 생성 조건."""

    available_minutes: int = Field(ge=10, le=180)
    intensity_preference: RoutineIntensityPreference = "moderate"
    trainer_note: str = Field(default="", max_length=500)


#: 분석에 싣는 최근 대화 최대 건수. 서비스의 조회 limit 이 이 값을 그대로 쓴다 —
#: 따로 두면 서비스 쪽만 올렸을 때 여기서 ValidationError 가 나는데, 그 생성은
#: LLM 폴백 try 블록 밖이라 500 이 된다.
ROUTINE_CHAT_MAX_MESSAGES = 10


class RoutineOptionAnalysisOut(BaseModel):
    goal: str
    member_goal: str = ""
    conditions: str = ""
    gender: str = ""
    height_cm: float | None = None
    weight_kg: float | None = None
    weekly_workout_goal: int | None = None
    weekly_exercise_minutes_goal: int | None = None
    weekly_burn_goal: int | None = None
    sodium_today_mg: int = Field(ge=0)
    sodium_over_target: bool
    avg_completion_rate: int = Field(ge=0, le=100)
    latest_routine: str
    note: str
    #: 최근 트레이너↔회원 대화(오래된→최신). "회원: …" / "트레이너: …" 라벨이
    #: 붙은 한 줄씩이며, 통증·컨디션 언급을 루틴 생성 근거로 쓴다(#580).
    #: 트레이너가 어떤 발화가 반영됐는지 확인할 수 있도록 응답에도 함께 내보낸다.
    recent_messages: list[str] = Field(
        default_factory=list, max_length=ROUTINE_CHAT_MAX_MESSAGES
    )


class RoutineOptionExerciseOut(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    minutes: int = Field(ge=1, le=180)
    type: RoutineType


class RoutineOptionPlanOut(BaseModel):
    key: Literal["A", "B"]
    label: str = Field(min_length=1, max_length=50)
    total_minutes: int = Field(ge=1, le=180)
    intensity: RoutineIntensityLabel
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
    client_request_id: str | None = Field(default=None, min_length=1, max_length=64)

    _v_date = field_validator("date")(_validate_ymd)
    _v_time = field_validator("time")(_validate_hhmm)


class ScheduleProgramRegisterRequest(BaseModel):
    """AI coaching command to attach a program or create its PT session."""

    date: str = Field(max_length=10)
    time: str = Field(max_length=10)
    client_name: str = Field(default="", max_length=100)
    program: list[ProgramItem] = Field(min_length=1, max_length=30)

    _v_date = field_validator("date")(_validate_ymd)
    _v_time = field_validator("time")(_validate_hhmm)


class ScheduleProgramRegisterOut(BaseModel):
    session: ScheduleSessionOut
    attached_to_existing: bool


class ScheduleUpdateRequest(PartialUpdate):
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

    #: null 은 '배정 해제'를 뜻하는 member_id 에만 허용한다. 규약 본문은
    #: `PartialUpdate` 에 있다(#495).
    nullable_fields: ClassVar[frozenset[str]] = frozenset({"member_id"})


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

class TrainerMeUpdate(PartialUpdate):
    """PUT /trainer/me — 보낸 필드만 반영(부분 수정).

    이름/이메일은 계정(User)에 속하므로 여기서 바꾸지 않는다. 프로필 화면에서
    바꿀 수 있는 값만 노출한다.

    모든 항목이 DB NOT NULL 이라 null 로 바꿀 수 있는 값이 아니다(#495).
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


class TrainerGymAffiliation(BaseModel):
    """PUT /trainer/me/gym — 소속 헬스장 설정·변경. (#452)

    위 `gym_*` 문자열과 달리 실재하는 `places` 행을 가리킨다. 해제는 값 대신
    DELETE 로 표현한다 — 이 필드에 null 을 허용하면 "안 보냈다"와 "지워라"가
    같은 요청으로 섞인다.
    """
    gym_id: str = Field(min_length=1, max_length=64)


# ---- 트레이너용 AI 코칭 (회원 데이터 기반) ----

class ClientCoachRequest(BaseModel):
    """트레이너가 담당 고객에 대해 AI에게 묻는 질문."""
    message: str = Field(min_length=1, max_length=1000)


class ClientCoachMessageOut(BaseModel):
    """복원된 문답 한 줄 (#588).

    `role` 은 저장값을 그대로 쓴다(user|coach). 회원 앱의 채팅 계약과 같은 값이라
    프론트가 두 화면에서 같은 분기를 쓸 수 있다.
    """
    role: str
    content: str
    sources: list[str] = Field(default_factory=list)


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


class TrainerNotificationOut(BaseModel):
    """트레이너 알림함 항목. (#503)

    `category` 는 회원 알림의 집합(reminder|health_check|achievement|system)이 아니라
    트레이너 전용 값이다 — `message`|`consultation`|`reservation`. 한 테이블을
    공유하지만 읽는 화면과 이동할 곳이 다르다.
    """

    id: str
    title: str
    body: str
    category: str
    read: bool
    created_at: _datetime
    time_ago: str


class TrainerNotificationSettings(BaseModel):
    """트레이너 알림 수신 설정."""
    notify_new_message: bool
    notify_session_reminder: bool
    reminder_lead_minutes: int


class TrainerNotificationSettingsUpdate(PartialUpdate):
    """부분 수정 — 보낸 필드만 반영.

    세 항목 모두 DB NOT NULL 이라 null 로 바꿀 수 있는 값이 아니다(#495).
    """
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
