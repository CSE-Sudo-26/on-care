"""
트레이너 API 스키마 — 트레이너 프론트 계약(seedTrainerProfile / TrainerProfile) 정렬.

GET /trainer/me 응답:
  { id, name, email, phone, specialty, career, intro, certifications[], gym{...} }
"""
from __future__ import annotations

from datetime import date as _date, datetime as _datetime
from typing import Annotated, ClassVar, Literal

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
    #: 트레이너 화면의 활성/휴면 배지. 담당 관계가 살아 있고(`TrainerClient.active`)
    #: 트레이너가 휴면으로 내리지 않은(`dormant=False`) 회원만 True 다. (#707)
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
    #: 최근 7일 일별 칼로리·당류. 나트륨과 같은 창이라 세 지표를 한 그래프에서
    #: 바꿔 가며 볼 수 있다(#746). 당류만 소수를 유지한다.
    calories_week: list[int] = Field(default_factory=list)
    sugar_week: list[float] = Field(default_factory=list)


class TrainerClientStatusUpdate(BaseModel):
    """회원 활성/휴면 전환 입력. (#707)

    `active=False` 는 **담당 관계 해제가 아니다** — 트레이너가 이 회원을 당분간
    관리하지 않는다는 표시이고, 기록·식단·운동·채팅과 담당 링크는 그대로 남는다.
    """
    active: bool


class TrainerClientStatusOut(BaseModel):
    """전환 후의 상태. 로스터 카드의 `active` 와 같은 값이다."""
    member_id: str
    active: bool


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


class ChatAttachmentOut(BaseModel):
    """#778 전용 PDF attachment. 다른 파일 형식은 계약에 포함하지 않는다."""
    type: Literal["pdf"]
    file_name: str
    file_id: str
    file_size: int
    download_path: str


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
    attachment: ChatAttachmentOut | None = None


class ChatSendRequest(BaseModel):
    # 상한만 둔다(빈/공백은 라우터에서 trim 후 400). 과도한 길이는 여기서 422.
    text: str = Field(max_length=2000)
    # 발신 시도당 한 번 만들고 재시도에서 재사용한다. 선택값이라 구버전 앱도
    # 기존처럼 전송할 수 있다.
    client_request_id: str | None = Field(default=None, min_length=1, max_length=64)


RoutineType = Literal["걷기", "유산소", "근력", "요가", "스트레칭", "기타"]
RoutineSource = Literal["ai", "trainer"]  # ai 추천 | 트레이너 직접 배정

#: 운동 항목의 출처. 'ai' 는 AI 제안을 편집기에 반영한 것, 'trainer' 는 트레이너가
#: 직접 추가한 것. 저장·복원 후에도 이 구분이 남아야 화면이 같은 배지를 그린다.
ProgramExerciseSource = Literal["ai", "trainer"]


class ProgramDraftExercise(BaseModel):
    """초안의 운동 한 항목 — 편집기 `ProgramExerciseDraft` 계약 정렬.

    세트·횟수·중량·시간은 **문자열 그대로** 둔다. 편집기가 "10회"·"60"·"20kg"
    같은 자유 입력을 받으므로 숫자로 정규화하면 트레이너가 적어 둔 표현이 사라진다
    — 저장·복원에서 값이 손실되지 않는 것이 이 기능의 요구다.
    """
    id: str = Field(min_length=1, max_length=64)
    name: str = Field(min_length=1, max_length=100)
    sets: str = Field(default="", max_length=30)
    reps: str = Field(default="", max_length=30)
    weight: str = Field(default="", max_length=30)
    duration: str = Field(default="", max_length=30)
    distance: str = Field(default="", max_length=30)
    rest: str = Field(default="", max_length=30)
    rpe: str = Field(default="", max_length=30)
    memo: str = Field(default="", max_length=300)
    type: RoutineType = "근력"
    source: ProgramExerciseSource = "trainer"




class RoutineOut(BaseModel):
    """배정 루틴 — 프론트 ClientAiRoutine 계약 정렬.

    다중 세션 프로그램은 세션당 한 건이다(#709). `program_name` 이 같은 건들이
    한 프로그램이고 `session_order` 가 순서다. 단일 배정은 세 값이 비어 있어
    예전 계약과 같다.
    """
    id: str
    name: str
    minutes: int
    type: RoutineType
    reason: str
    source: RoutineSource
    #: 여러 세션을 묶는 프로그램 이름. 단일 배정은 빈 문자열.
    program_name: str = ""
    #: 이 루틴이 어느 세션인가. 세션이 하나뿐인 프로그램은 빈 문자열.
    session_name: str = ""
    #: 프로그램 안에서의 세션 순서(0부터).
    session_order: int = 0
    #: 그 세션의 운동 구성. 예전에는 이름만 `reason` 에 이어 붙였다.
    exercises: list[ProgramDraftExercise] = Field(default_factory=list)
    #: 이 추천이 무엇을 보고 만들어졌나 — 트레이너 검토용 근거 문구(#790).
    #: 트레이너가 직접 배정한 루틴은 비어 있다.
    evidence: list[str] = Field(default_factory=list)
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


class RoutineSuggestionCreateRequest(BaseModel):
    """AI 개인운동 후보 등록. 검토 대기 상태로만 만들어진다.

    승인 전에는 회원에게 닿지 않으므로 알림도 나가지 않는다.
    """

    name: str = Field(min_length=1, max_length=100)
    minutes: int = Field(ge=0, le=600)
    type: RoutineType
    reason: str = Field(default="", max_length=200)
    #: 이 후보의 근거 문구. 트레이너가 승인 판단에 쓰는 재료이고 회원에게는
    #: 전달되지 않는다. 개수·길이를 묶는 이유는 카드 한 장이 읽히는 분량을
    #: 넘기면 근거가 오히려 판단을 방해하기 때문이다 — AI 내부 분석을 길게
    #: 노출하지 않는 것이 이 기능의 요구다(#790).
    evidence: list[Annotated[str, Field(min_length=1, max_length=40)]] = Field(
        default_factory=list, max_length=4
    )
    #: 재전송 중복 생성 방지용 멱등키. 배정(`AssignRoutineRequest`)과 같은 규약이다.
    client_request_id: str | None = Field(default=None, max_length=64)


class RoutineSuggestionApproveRequest(PartialUpdate):
    """제안 승인. 필드를 주면 그것으로 고쳐서 승인한다(수정 후 추천).

    아무 필드도 주지 않으면 그대로 승인이다. `RoutineUpdateRequest` 와 같은 이유로
    명시적 null 은 422 다 — 이름·시간을 '지우는 것'은 기능이 아니다.
    """

    name: str | None = Field(default=None, min_length=1, max_length=100)
    minutes: int | None = Field(default=None, ge=0, le=600)
    type: RoutineType | None = None
    reason: str | None = Field(default=None, max_length=200)


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


# ---- 프로그램 초안 (#708) ----

#: 세션 하나가 담는 운동 수 상한. 화면이 한 세션에 넣을 수 있는 현실적인 개수를
#: 훨씬 넘는 값이며, 한 요청이 DB 에 무한정 밀어 넣는 것을 막는다.
_PROGRAM_DRAFT_MAX_EXERCISES = 50

#: 한 프로그램의 세션 수 상한. 주 단위 분할(A/B/C…)을 충분히 담는 값이다.
_PROGRAM_MAX_SESSIONS = 12


class ProgramDraftSession(BaseModel):
    """프로그램의 세션 하나 — 편집기 `ProgramSessionDraft` 계약 정렬. (#709)

    순서는 배열 순서다. 별도 정렬 값을 두면 배열과 어긋날 수 있고, 편집기는
    이미 순서를 가진 목록을 들고 있다.
    """
    id: str = Field(min_length=1, max_length=64)
    name: str = Field(default="", max_length=100)
    exercises: list[ProgramDraftExercise] = Field(
        default_factory=list, max_length=_PROGRAM_DRAFT_MAX_EXERCISES
    )


class TrainerProgramDraftOut(BaseModel):
    """저장된 프로그램 초안. 세션은 저장한 순서 그대로 돌아온다."""
    id: str
    name: str
    goal: str
    period: str
    memo: str
    sessions: list[ProgramDraftSession]
    created_at: _datetime
    updated_at: _datetime


class TrainerProgramDraftSummary(BaseModel):
    """목록용 요약 — 운동 구성 전체를 싣지 않는다.

    목록은 "무엇을 저장해 뒀나"만 보여 주고, 편집기로 불러올 때 상세를 읽는다.
    초안 수가 늘어도 목록 응답이 함께 커지지 않는다.
    """
    id: str
    name: str
    goal: str
    period: str
    session_count: int
    exercise_count: int
    updated_at: _datetime


class TrainerProgramDraftCreate(BaseModel):
    """초안 저장 입력."""
    name: str = Field(min_length=1, max_length=100)
    goal: str = Field(default="", max_length=200)
    period: str = Field(default="", max_length=100)
    memo: str = Field(default="", max_length=2000)
    #: 운동이 하나도 없는 초안도 저장할 수 있다 — 이름과 목표만 잡아 둔 상태가
    #: 초안으로서 의미가 있고, 그 상태를 저장하지 못하면 기능이 반쪽이 된다.
    sessions: list[ProgramDraftSession] = Field(
        default_factory=list, max_length=_PROGRAM_MAX_SESSIONS
    )


class TrainerProgramDraftUpdate(PartialUpdate):
    """초안 부분 수정. 보낸 필드만 반영한다.

    `sessions` 는 통째로 교체한다 — 편집기가 항목 단위 diff 가 아니라 현재
    구성 전체를 들고 있고, 부분 병합은 순서가 어긋날 여지만 만든다.
    """

    name: str | None = Field(default=None, min_length=1, max_length=100)
    goal: str | None = Field(default=None, max_length=200)
    period: str | None = Field(default=None, max_length=100)
    memo: str | None = Field(default=None, max_length=2000)
    sessions: list[ProgramDraftSession] | None = Field(
        default=None, max_length=_PROGRAM_MAX_SESSIONS
    )


class ProgramAssignRequest(BaseModel):
    """다중 세션 프로그램을 담당 회원에게 배정하는 입력. (#709)

    세션 하나당 루틴 하나가 만들어진다. 세션이 하나뿐이면 예전 단일 배정과
    같은 모양의 루틴 하나가 되고 세션 라벨이 붙지 않는다 — 회원 화면에 없던
    구분이 갑자기 생기지 않게 하려는 것이다.
    """
    name: str = Field(min_length=1, max_length=100)
    sessions: list[ProgramDraftSession] = Field(
        min_length=1, max_length=_PROGRAM_MAX_SESSIONS
    )
    #: 전송 시도당 클라이언트가 만드는 멱등키. 재시도에 같은 키를 다시 보내면
    #: 프로그램 전체가 두 번 배정되지 않는다(단일 배정과 같은 규약, #581).
    #:
    #: 단건 배정(64)보다 짧다. 서버가 세션마다 `{key}#{index}` 로 나눠 저장하는데
    #: 그 값이 들어갈 컬럼이 `String(64)` 라, 접미사 자리를 남겨 두지 않으면 긴
    #: 키가 저장 단계에서 길이 초과로 터진다.
    client_request_id: str | None = Field(default=None, max_length=48)


#: 메모 출처. 'trainer' 는 회원 상세에서 직접 쓴 메모, 'chat_insight' 는 채팅에서
#: 감지한 신호를 저장한 메모다. 회원 상세는 두 종류를 한 목록으로 보여 준다.
TrainerMemoSource = Literal["trainer", "chat_insight"]


class TrainerMemoOut(BaseModel):
    """회원별 트레이너 메모. (#706)"""
    id: str
    body: str
    source: TrainerMemoSource
    #: 채팅 인사이트에서 만든 메모만 값을 갖는다(중복 저장 방지 키).
    insight_id: str | None = None
    #: 인사이트 종류(discomfort|negativeFeedback). 직접 쓴 메모는 빈 문자열.
    insight_kind: str = ""
    created_at: _datetime
    updated_at: _datetime


class TrainerMemoCreateRequest(BaseModel):
    """메모 작성 입력.

    `insight_id` 를 보내면 그 인사이트에 대해 멱등하다 — 같은 채팅 신호를 다시
    저장해도 메모가 늘지 않고 먼저 저장된 메모가 그대로 돌아온다. 직접 쓴 메모는
    이 값을 보내지 않으므로 같은 내용을 여러 번 남길 수 있다(그것이 기능이다).
    """
    body: str = Field(min_length=1, max_length=2000)
    source: TrainerMemoSource = "trainer"
    insight_id: str | None = Field(default=None, max_length=64)
    insight_kind: str = Field(default="", max_length=32)

    @model_validator(mode="after")
    def _reject_mismatched_source(self) -> TrainerMemoCreateRequest:
        """출처와 중복 방지 키가 짝을 이루는지 본다.

        어긋난 두 조합이 조용히 통과하면 각각 다른 방식으로 망가진다 —
        키 없는 인사이트 메모는 반복 저장 때마다 늘어나고, 직접 쓴 메모가
        `insight_id` 를 가지면 그 인사이트의 유니크 키를 대신 차지한다.
        """
        if self.source == "chat_insight" and not self.insight_id:
            raise ValueError("chat_insight 메모에는 insight_id가 필요합니다.")
        if self.source == "trainer" and self.insight_id:
            raise ValueError("trainer 메모에는 insight_id를 보낼 수 없습니다.")
        return self


class TrainerMemoUpdateRequest(PartialUpdate):
    """메모 부분 수정. 본문만 고칠 수 있다.

    `source`·`insight_id` 는 "이 메모가 어디서 왔나"라는 사실이라 고칠 값이 아니다 —
    채팅에서 생긴 메모를 손봤다고 직접 쓴 메모가 되지는 않고, `insight_id` 를
    바꿀 수 있으면 중복 방지 키가 무너진다.
    """

    body: str | None = Field(default=None, min_length=1, max_length=2000)


#: 후속 관리 할 일이 가리키는 업무 갈래. 할 일에서 어느 화면으로 갈지를 고르는
#: 값이라 열어 두지 않는다 — 앱이 모르는 값이 오면 이동할 곳이 없다. 새 갈래는
#: 앱의 route 매핑과 **함께** 늘린다.
FollowUpTaskContext = Literal[
    "general", "diet", "exercise", "message", "program", "schedule"
]

#: 할 일 상태. 완료는 되돌리지 않으므로 두 값이면 충분하다.
FollowUpTaskStatus = Literal["pending", "completed"]


#: 대시보드/목록이 고르는 조회 범위. `due` 는 오늘까지 처리해야 할 미완료(지난
#: 항목 포함), `open` 은 예정일과 무관한 미완료 전체.
FollowUpScope = Literal["due", "open"]


class TrainerFollowUpTaskOut(BaseModel):
    """고객별 후속 관리 할 일. (#869)"""
    id: str
    member_id: str
    #: 대시보드가 "누구의 할 일인가"를 함께 보여 준다. 트레이너 웹이 할 일마다
    #: 회원을 다시 조회하지 않도록 서버가 채워 준다.
    member_name: str = ""
    title: str
    #: 확인 예정일 `YYYY-MM-DD`(KST).
    due_date: str
    status: FollowUpTaskStatus
    context_type: FollowUpTaskContext
    created_at: _datetime
    updated_at: _datetime
    #: 완료 처리 시각. 미완료는 None.
    completed_at: _datetime | None = None


class TrainerFollowUpTaskCreateRequest(BaseModel):
    """후속 관리 할 일 등록 입력.

    고객은 경로(`/trainer/clients/{member_id}/follow-ups`)가 정하므로 본문에
    두지 않는다 — 두 곳에서 오면 어긋난 조합을 검증할 자리가 생긴다.

    `client_request_id` 를 보내면 그 시도에 대해 멱등하다. 저장 응답을 못 받고
    재시도한 등록이 같은 할 일을 두 번 만들면 대시보드에 같은 줄이 겹쳐 뜬다.
    """
    title: str = Field(min_length=1, max_length=200)
    due_date: str = Field(max_length=10)
    context_type: FollowUpTaskContext = "general"
    client_request_id: str | None = Field(default=None, max_length=64)

    _check_due_date = field_validator("due_date")(_validate_ymd)


class TrainerFollowUpTaskUpdateRequest(PartialUpdate):
    """할 일 부분 수정. 내용과 예정일만 고칠 수 있다.

    상태는 여기서 받지 않는다 — 완료는 완료 시각까지 함께 남기는 상태 전이라
    전용 경로(`POST .../complete`)를 지난다. 고객(`member_id`)도 고치지 않는다:
    다른 고객의 할 일로 옮기는 것은 수정이 아니라 새 할 일이다.
    """

    title: str | None = Field(default=None, min_length=1, max_length=200)
    due_date: str | None = Field(default=None, max_length=10)

    _check_due_date = field_validator("due_date")(
        lambda v: v if v is None else _validate_ymd(v)
    )


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
    """세션 프로그램 한 항목 — 프론트 ProgramItem 계약({name,sets,reps,weight}).

    `session` 은 다중 세션 프로그램을 일정에 등록할 때 그 항목이 속한 세션
    이름이다(#709). 기존 행에는 이 키가 없고, 없으면 빈 문자열이라 예전처럼
    세션 구분 없는 목록으로 읽힌다.
    """
    name: str = Field(min_length=1, max_length=100)
    sets: int = Field(default=0, ge=0, le=99)
    reps: str = Field(default="", max_length=30)
    weight: str = Field(default="", max_length=30)
    session: str = Field(default="", max_length=100)


#: 취소 주체. 트레이너 사정의 취소를 회원의 미이행으로 읽지 않으려면 남아 있어야
#: 한다. 빈 문자열은 "취소가 아님"(예정·완료·노쇼)이다. (#871)
CancellationSource = Literal["", "member", "trainer", "other"]


class ScheduleSessionOut(BaseModel):
    """스케줄 슬롯 — 프론트 ScheduleSession 계약 정렬."""
    id: str
    date: str
    time: str
    client_name: str
    type: str
    duration_minutes: int
    status: str          # 예정|완료|취소|노쇼|공백
    note: str
    program: list[ProgramItem]
    #: 완료한 세션의 프로그램을 회원에게 보냈는가. 보낸 적 없는 세션과 이미
    #: 보낸 세션은 화면에서 다른 것을 말해야 한다(#822).
    program_sent: bool = False
    #: 취소·노쇼로 마무리된 세션의 기록. 예정·완료는 전부 비어 있다(#871).
    cancelled_at: _datetime | None = None
    cancellation_source: CancellationSource = ""
    cancellation_reason: str = ""
    no_show_at: _datetime | None = None


class ScheduleProgramSendRequest(BaseModel):
    """완료한 세션의 프로그램을 회원에게 보내는 입력. (#822)

    본문은 멱등키뿐이다 — 무엇을 보낼지는 세션 행이 이미 알고 있고, 클라이언트가
    다시 실어 보내면 화면과 저장된 프로그램이 갈릴 수 있다. 재시도에 같은 키를
    다시 보내면 배정이 두 번 만들어지지 않는다(단일·프로그램 배정과 같은 규약).
    """
    client_request_id: str | None = Field(default=None, max_length=48)


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


class ScheduleRecurringRequest(BaseModel):
    """주간 반복으로 PT 회차를 한 번에 잡는 입력. (#870)

    이번 범위는 **주간 반복**뿐이다 — PT 운영에서 실제로 쓰이는 형태이고, 월 N번째
    요일 같은 규칙까지 받으면 화면과 검증이 함께 커진다.

    종료 기준은 `count` 또는 `until` **중 하나**다. 둘 다 없으면 끝이 없고, 둘 다
    있으면 어느 쪽이 이겼는지 화면과 서버의 해석이 갈린다.
    """

    date: str = Field(max_length=10)
    time: str = Field(max_length=10)
    client_name: str = Field(default="", max_length=100)
    member_id: str | None = Field(default=None, max_length=64)
    type: str = Field(default="", max_length=30)
    duration_minutes: int = Field(default=0, ge=0, le=600)
    note: str = Field(default="", max_length=500)
    #: 반복할 요일(ISO: 월=1 … 일=7).
    weekdays: list[int] = Field(min_length=1, max_length=7)
    #: 반복 횟수로 끝내기.
    count: int | None = Field(default=None, ge=1, le=52)
    #: 종료일로 끝내기(포함).
    until: str | None = Field(default=None, max_length=10)
    client_request_id: str | None = Field(default=None, min_length=1, max_length=64)

    _v_date = field_validator("date")(_validate_ymd)
    _v_time = field_validator("time")(_validate_hhmm)

    @field_validator("weekdays")
    @classmethod
    def _check_weekdays(cls, value: list[int]) -> list[int]:
        if any(day < 1 or day > 7 for day in value):
            raise ValueError("요일은 1(월)~7(일) 사이여야 합니다.")
        # 같은 요일을 두 번 보내도 회차가 두 배가 되지 않게 여기서 눕힌다.
        return sorted(set(value))

    @model_validator(mode="after")
    def _check_end(self) -> ScheduleRecurringRequest:
        if (self.count is None) == (self.until is None):
            raise ValueError("반복 횟수 또는 종료일 중 하나만 지정해 주세요.")
        if self.until is not None:
            _validate_ymd(self.until)
            if self.until < self.date:
                raise ValueError("종료일은 시작일 이후여야 합니다.")
        return self


class ScheduleRecurringPreviewOut(BaseModel):
    """저장 전에 보여 줄 회차와 충돌. (#870)"""

    #: 생성될 날짜들(`YYYY-MM-DD`, 오름차순).
    dates: list[str]
    #: 그 자리에 이미 있는 세션. 비어 있지 않으면 생성은 409 로 막힌다.
    conflicts: list[ScheduleSessionOut]


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


class ScheduleCancelRequest(BaseModel):
    """일정 취소 입력. (#871)

    `source` 를 받는 까닭은 지표 때문이다 — 트레이너 사정의 취소와 고객 취소를
    구분하지 않으면 나중에 회원의 낮은 완료율을 잘못 읽는다. 기본값을 두지 않고
    화면이 고르게 한다: 무엇이든 기본으로 저장되면 그 값이 사실인지 알 수 없다.

    `reason` 은 트레이너가 보는 내부 기록이라 선택이다. 회원에게 나가는 알림에는
    싣지 않는다.
    """
    source: Literal["member", "trainer", "other"]
    reason: str = Field(default="", max_length=200)


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

class WeeklyReportDayOut(BaseModel):
    """리포트의 하루 — 그날의 이행률과 실제로 배정된 운동.

    이행률만으로는 67% 가 어디서 나온 값인지 화면에서 알 수 없다. 배정된
    운동과 건너뛴 운동을 함께 내려 주면 분모·분자가 드러난다(#754).
    """
    completion: int              # 0..100 (0 = 그날 기록 없음)
    #: 운동 이름. 끝의 '✓'/'✗' 는 수행 여부를 나타내는 저장 규칙이며 화면은
    #: 그 표시를 읽어 아이콘으로 바꿔 그린다(운동 기록 탭과 같은 규칙).
    exercises: list[str] = Field(default_factory=list)


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
    #: 그 주(월→일)의 요일별 값. 로스터의 같은 이름 필드는 **이번 주** 것이라
    #: 과거 주 화면에 쓸 수 없다 — 리포트는 자기 주의 계열을 직접 들고 온다(#752).
    week_completion: list[int] = Field(default_factory=list)
    sodium_week: list[int] = Field(default_factory=list)
    calories_week: list[int] = Field(default_factory=list)
    sugar_week: list[float] = Field(default_factory=list)
    #: 월→일 7칸. 이행률과 함께 그날의 운동 내역을 담는다(#754).
    days: list[WeeklyReportDayOut] = Field(default_factory=list)
    message: str                 # 회원에게 전송될 본문(미리보기와 동일)


class ReportSummaryOut(BaseModel):
    """리포트 요약 — 트레이너가 피드백 초안으로 가져다 고칠 재료."""
    member_id: str
    week_start: str              # YYYY-MM-DD (월요일)
    headline: str                # 이번 주를 한 문장으로
    #: 근거가 된 수치 문장. 리포트 화면이 이미 보여 주는 값만 담는다 — 요약과
    #: 그래프가 다른 값을 말하면 트레이너가 어느 쪽을 믿어야 할지 모른다.
    points: list[str] = Field(default_factory=list)
    #: `llm` | `rule`. 공급자 장애·미설정이면 규칙 기반으로 되돌아간다.
    generated_by: str


class ReportSendRequest(BaseModel):
    """리포트 전송 — 본문을 직접 주면 그것을, 없으면 서버 생성본을 보낸다."""
    week_start: str | None = Field(default=None, description="YYYY-MM-DD (기본: 이번 주)")
    message: str | None = Field(default=None, max_length=2000)


class ReportFeedbackOut(BaseModel):
    """그 주 리포트에 저장돼 있는 트레이너 피드백 초안. (#821)

    저장한 적이 없으면 `body` 가 빈 문자열이고 `updated_at` 이 null 이다 —
    404 로 답하지 않는 이유는, 초안이 없는 것이 오류가 아니라 정상 상태이고
    화면은 그때 자동 생성 문구를 쓰기 때문이다.
    """
    member_id: str
    week_start: str              # YYYY-MM-DD (월요일)
    body: str
    updated_at: _datetime | None = None


class ReportFeedbackSaveRequest(BaseModel):
    """피드백 초안 저장. 보낸 본문으로 그 주의 초안을 통째로 바꾼다.

    `max_length` 는 전송 본문(`ReportSendRequest.message`)과 같은 2000 자다 —
    저장은 됐는데 보낼 수 없는 길이가 생기면 안 된다.
    """
    week_start: str | None = Field(default=None, description="YYYY-MM-DD (기본: 이번 주)")
    body: str = Field(default="", max_length=2000)


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
