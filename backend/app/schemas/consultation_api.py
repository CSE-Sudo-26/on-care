from __future__ import annotations

from datetime import date as Date
from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

#: 요청이 지정할 수 있는 대상. 트레이너 한 사람뿐이다 — 헬스장 전체로 보내는
#: 갈래는 폐지됐고, 그때 만들어진 이력도 남아 있지 않다.
ConsultationCreateTargetType = Literal["trainer"]
ExerciseGoal = Literal[
    "weight_loss", "strength", "fitness", "posture", "health", "other"
]
HealthPurposeType = Literal[
    "weight", "chronic", "rehab", "general", "none", "other"
]
PreferredTimeSlot = Literal["morning", "afternoon", "evening", "flexible"]


class ConsultationCreate(BaseModel):
    """새 상담 요청. 대상은 트레이너 한 사람이다.

    헬스장 전체로 보내는 갈래를 없앤 이유: 소속 트레이너 누구나 받을 수 있는 요청은
    회원이 누구에게 상담을 거는지 모른 채 보내게 되고, 인박스에서도 "내 요청"과
    "우리 헬스장 요청"이 섞여 화면에서 구분이 안 됐다. 헬스장에서 시작하더라도
    회원이 소속 트레이너 중 한 명을 고른 뒤에 요청이 만들어진다.
    """

    #: 생략 가능하다 — 값은 `trainer` 하나뿐이라 클라이언트가 보낼 이유가 없다.
    target_type: ConsultationCreateTargetType = "trainer"
    trainer_id: str = Field(max_length=64)
    exercise_goal: ExerciseGoal
    health_purpose_type: HealthPurposeType
    health_purpose_detail: str | None = Field(default=None, max_length=500)
    preferred_date: Date
    preferred_time_slot: PreferredTimeSlot
    message: str | None = Field(default=None, max_length=2000)

    @model_validator(mode="before")
    @classmethod
    def _reject_status(cls, data: Any) -> Any:
        if isinstance(data, dict) and "status" in data:
            raise ValueError("status는 서버에서 설정합니다.")
        return data

    @field_validator("health_purpose_detail", "message", mode="before")
    @classmethod
    def _normalize_optional_text(cls, value: Any) -> Any:
        if isinstance(value, str):
            value = value.strip()
            return value or None
        return value

    @field_validator("trainer_id", mode="before")
    @classmethod
    def _normalize_trainer_id(cls, value: Any) -> Any:
        """공백만 보낸 trainer_id 는 누락으로 본다 — 대상 없는 요청은 만들 수 없다."""
        if isinstance(value, str):
            value = value.strip()
            if not value:
                raise ValueError("상담을 요청할 트레이너를 지정해야 합니다.")
        return value

    @model_validator(mode="after")
    def _validate_target(self) -> ConsultationCreate:
        if self.health_purpose_type == "other" and self.health_purpose_detail is None:
            raise ValueError("기타 건강관리 목적에는 상세 내용이 필요합니다.")
        return self


#: 트레이너 인박스가 걸 수 있는 상태 필터. `all` 은 처리 이력까지 함께 본다.
ConsultationStatusFilter = Literal["pending", "accepted", "rejected", "all"]


class ConsultationDecision(BaseModel):
    """승인·거절 본문. 거절 사유는 회원 알림 본문에 그대로 실린다."""

    note: str | None = Field(default=None, max_length=500)

    @field_validator("note", mode="before")
    @classmethod
    def _normalize_note(cls, value: Any) -> Any:
        if isinstance(value, str):
            value = value.strip()
            return value or None
        return value


class ConsultationAccept(ConsultationDecision):
    """Accept a request and optionally book its first consultation session.

    Older clients may still send only ``note``.  The trainer schedule inbox
    sends the complete schedule tuple so accepting and booking are atomic.
    """

    date: Date | None = None
    time: str | None = Field(default=None, pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    type: str | None = Field(default=None, min_length=1, max_length=30)
    duration_minutes: int | None = Field(default=None, ge=15, le=600)

    @model_validator(mode="after")
    def _schedule_is_complete(self) -> ConsultationAccept:
        values = (self.date, self.time, self.type, self.duration_minutes)
        if any(value is not None for value in values) and not all(
            value is not None for value in values
        ):
            raise ValueError(
                "일정을 등록하려면 date, time, type, duration_minutes가 모두 필요합니다."
            )
        return self


class ConsultationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    member_id: str
    trainer_id: str | None
    #: 목록 카드가 이름을 렌더한다. id 만 주면 앱이 트레이너마다 상세를 다시 조회해야
    #: 하고, 대상이 지워지면 이름을 영영 못 만든다(#327).
    trainer_name: str | None = None
    exercise_goal: ExerciseGoal
    health_purpose_type: HealthPurposeType
    health_purpose_detail: str | None
    preferred_date: Date
    preferred_time_slot: PreferredTimeSlot
    message: str | None
    status: str
    #: 거절 사유. 트레이너가 남긴 문장이 그대로 온다. (#473)
    #:
    #: 처리자 id(`decided_by`)는 **회원 응답에 싣지 않는다** — 회원에게 필요한 것은
    #: 결과와 이유이지 누가 눌렀는지가 아니다.
    decision_note: str | None = None
    #: 처리 시각. 화면이 "언제 답을 받았는지"를 보여 준다.
    decided_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class TrainerConsultationOut(ConsultationOut):
    """트레이너 인박스 카드. 회원용 [ConsultationOut] 에 처리 정보를 더한다.

    회원 응답과 스키마를 나누는 이유: 회원에게는 **누가 처리했는지**가 필요 없고,
    트레이너에게는 요청자 이름이 반드시 필요하다(회원 id 만으로는 카드를 못 그린다).
    한 스키마에 다 담으면 회원 응답에도 처리자 id 가 실린다.
    """

    #: 요청한 회원 이름. 대상 이름과 같은 이유로 id 대신 함께 내려준다.
    member_name: str | None = None
    #: 처리한 트레이너. 지금은 요청 대상(`trainer_id`)과 항상 같지만, 인박스 이력이
    #: "누가 언제 처리했는지"를 그대로 보여 줘야 해 응답에 남긴다. 회원 응답에는
    #: 없는 필드다.
    decided_by: str | None = None
