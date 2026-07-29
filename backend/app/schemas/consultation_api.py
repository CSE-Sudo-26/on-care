from __future__ import annotations

from datetime import date, datetime
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
    preferred_date: date
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


class ConsultationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    member_id: str
    target_type: ConsultationTargetType
    gym_id: str | None
    trainer_id: str | None
    exercise_goal: ExerciseGoal
    health_purpose_type: HealthPurposeType
    health_purpose_detail: str | None
    preferred_date: date
    preferred_time_slot: PreferredTimeSlot
    message: str | None
    status: str
    created_at: datetime
    updated_at: datetime
