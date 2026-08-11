from __future__ import annotations

from datetime import date as Date
from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

ConsultationTargetType = Literal["gym", "trainer"]
ExerciseGoal = Literal[
    "weight_loss", "strength", "fitness", "posture", "health", "other"
]
HealthPurposeType = Literal[
    "weight", "chronic", "rehab", "general", "none", "other"
]
PreferredTimeSlot = Literal["morning", "afternoon", "evening", "flexible"]


class ConsultationCreate(BaseModel):
    target_type: ConsultationTargetType
    gym_id: str | None = Field(default=None, max_length=64)
    trainer_id: str | None = Field(default=None, max_length=64)
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

    @field_validator(
        "gym_id", "trainer_id", "health_purpose_detail", "message", mode="before"
    )
    @classmethod
    def _normalize_optional_text(cls, value: Any) -> Any:
        if isinstance(value, str):
            value = value.strip()
            return value or None
        return value

    @model_validator(mode="after")
    def _validate_target(self) -> ConsultationCreate:
        if self.target_type == "gym":
            if self.gym_id is None:
                raise ValueError("헬스장 상담에는 gym_id가 필요합니다.")
            if self.trainer_id is not None:
                raise ValueError("헬스장 상담에는 trainer_id를 사용할 수 없습니다.")
        else:
            if self.trainer_id is None:
                raise ValueError("트레이너 상담에는 trainer_id가 필요합니다.")
            if self.gym_id is not None:
                raise ValueError("트레이너 상담에는 gym_id를 사용할 수 없습니다.")
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
    target_type: ConsultationTargetType
    gym_id: str | None
    trainer_id: str | None
    #: 목록 카드가 이름을 렌더한다. id 만 주면 앱이 대상마다 상세를 다시 조회해야
    #: 하고, 삭제된 대상은 이름을 영영 못 만든다(#327).
    gym_name: str | None = None
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
    #: 결과와 이유이지 누가 눌렀는지가 아니고, 헬스장으로 보낸 문의는 소속 트레이너
    #: 누구나 처리할 수 있어 id 를 흘리면 지정하지도 않은 트레이너를 알게 된다.
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
    #: 이 요청이 내 앞으로 온 것(False)인지, 내 소속 헬스장으로 온 것(True)인지.
    #: 카드가 "헬스장 문의" 배지를 다는 근거이며, 트레이너 지정 요청과 섞이면
    #: 누구를 향한 요청인지 화면에서 구분할 수 없다.
    via_gym: bool = False
    #: 처리한 트레이너. 헬스장 문의는 소속 트레이너 누구나 받을 수 있어, 인박스
    #: 이력에서 "누가 가져갔는지"가 필요하다. 회원 응답에는 없는 필드다.
    decided_by: str | None = None
