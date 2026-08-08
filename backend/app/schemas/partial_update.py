"""부분 수정 요청의 공통 규약. (#495)

`None` 은 두 가지를 뜻할 수 있다 — 항목을 **안 보냈거나**, `null` 을 **보냈거나**.
구분하지 않으면 두 방향으로 어긋난다.

* **조용한 무시**: `{"phone": null}` 이 200 으로 성공하는데 아무것도 바뀌지 않는다.
  클라이언트는 저장됐다고 믿는다.
* **500**: NOT NULL 컬럼에 null 을 그대로 반영하면 `IntegrityError` 가 난다.
  이 규약이 처음 생긴 이유다(#377).

그래서 **누락은 '변경 없음', 명시적 null 은 422** 로 나눈다.

null 이 의미를 갖는 필드는 [nullable_fields] 로 예외를 둔다 — 스케줄의
`member_id` 는 null 이 '배정 해제'다. 컬럼 자체가 nullable 이고 null 을 저장하는
것이 기능인 경우(예: 건강 목표 해제)에는 이 클래스를 쓰지 않는다.
"""
from __future__ import annotations

from typing import ClassVar

from pydantic import BaseModel, model_validator


class PartialUpdate(BaseModel):
    """누락과 명시적 null 을 구분하는 부분 수정 요청의 베이스."""

    #: null 을 허용하는 필드. 값을 지우는 것이 기능인 필드만 넣는다.
    nullable_fields: ClassVar[frozenset[str]] = frozenset()

    @model_validator(mode="after")
    def _reject_null_for_non_nullable_fields(self) -> PartialUpdate:
        for field in self.model_fields_set - self.nullable_fields:
            if getattr(self, field, None) is None:
                raise ValueError(f"{field}에는 null을 사용할 수 없습니다.")
        return self
