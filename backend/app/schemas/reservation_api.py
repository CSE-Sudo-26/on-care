from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field, model_validator


class TrainerSlotOut(BaseModel):
    id: str
    trainer_id: str
    starts_at: datetime
    capacity: int
    remaining: int
    is_closed: bool = False


class TrainerSlotCreate(BaseModel):
    starts_at: datetime
    capacity: int = Field(ge=1, le=100)

    @model_validator(mode="after")
    def require_timezone(self) -> TrainerSlotCreate:
        if self.starts_at.tzinfo is None or self.starts_at.utcoffset() is None:
            raise ValueError("starts_at에는 시간대가 포함되어야 합니다.")
        return self


class TrainerSlotUpdate(BaseModel):
    starts_at: datetime | None = None
    capacity: int | None = Field(default=None, ge=1, le=100)
    is_closed: bool | None = None

    @model_validator(mode="after")
    def validate_update(self) -> TrainerSlotUpdate:
        if not self.model_fields_set:
            raise ValueError("수정할 항목이 없습니다.")
        if "starts_at" in self.model_fields_set:
            if self.starts_at is None:
                raise ValueError("starts_at은 null일 수 없습니다.")
            if self.starts_at.tzinfo is None or self.starts_at.utcoffset() is None:
                raise ValueError("starts_at에는 시간대가 포함되어야 합니다.")
        for field in self.model_fields_set:
            if getattr(self, field) is None:
                raise ValueError(f"{field}은 null일 수 없습니다.")
        return self


class ReservationCreate(BaseModel):
    slot_id: str = Field(min_length=1, max_length=64)


class ReservationOut(BaseModel):
    id: str
    slot_id: str
    schedule_id: str
    status: str
    created_at: datetime
