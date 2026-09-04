"""회원앱 헬스장·트레이너 디렉터리 계약. (#324)

프론트 `Gym` / `Trainer` 엔티티와 필드를 맞춘다 — 앱이 mock 에서 실 API 로 넘어갈 때
매핑 코드가 없도록.
"""
from __future__ import annotations

from pydantic import BaseModel


class GymOut(BaseModel):
    id: str
    name: str
    address: str
    #: 요청 좌표 기준. 좌표를 주지 않으면 0.
    distance_km: float
    #: 카카오에서 발견한 헬스장은 평점이 없다 — 0 이면 UI 가 뱃지를 감춘다.
    rating: float
    tags: list[str]
    weekday_hours: str | None
    weekend_hours: str | None
    phone: str | None
    lat: float | None
    lng: float | None
    #: 제휴 표시 값. `GET /gyms?partner_only=true` 필터의 기준이고, 상담·트레이너 노출을
    #: 막지 않는다([GymProfile.is_partner] 참고). 지금 두 앱은 이 값을 읽지 않는다. (#1626)
    is_partner: bool


class TrainerOut(BaseModel):
    id: str
    gym_id: str | None
    name: str
    role: str | None
    #: 추천 사유. 비어 있으면 추천 레일에 올리지 않는다.
    reason: str | None
    #: "7년" 형태의 표시용 문자열 — 앱이 그대로 렌더한다.
    career: str | None
    intro: str | None
    certifications: list[str]
