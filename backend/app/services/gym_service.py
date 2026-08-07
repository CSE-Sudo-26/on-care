"""헬스장·트레이너 디렉터리 조회. (#324)

헬스장은 `places`(category='fitness') 이고 부가 정보는 `gym_profiles` 에 있다.
프로필이 없는 헬스장(기존 데모 시드, 카카오 발견분)도 목록에는 나와야 하므로 outer
조인으로 읽고 빈 값을 채운다.
"""
from __future__ import annotations

import json
import math

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.models import GymProfile, Place, TrainerProfile, User
from app.schemas.gym_api import GymOut, TrainerOut


def _haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> int:
    """`places.py` 의 `_haversine_m` 과 같은 계산(절삭)."""
    r = 6371000
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return int(r * 2 * math.asin(math.sqrt(a)))


def _tags(profile: GymProfile | None) -> list[str]:
    if profile is None or not profile.tags_json:
        return []
    try:
        parsed = json.loads(profile.tags_json)
    except json.JSONDecodeError:
        return []
    return [str(t) for t in parsed] if isinstance(parsed, list) else []


def _to_gym(
    place: Place, profile: GymProfile | None, lat: float | None, lng: float | None
) -> GymOut:
    distance_km = 0.0
    if lat is not None and lng is not None and place.lat is not None and place.lng is not None:
        distance_km = _haversine_m(lat, lng, place.lat, place.lng) / 1000
    return GymOut(
        id=place.id,
        name=place.name,
        address=place.address,
        distance_km=distance_km,
        # 평점 없음을 0 으로 내린다 — 프론트 Gym.rating 이 non-null 이고 0 이면
        # 뱃지를 감추기로 이미 합의돼 있다(#329).
        rating=profile.rating if profile and profile.rating is not None else 0.0,
        tags=_tags(profile),
        weekday_hours=(profile.weekday_hours or None) if profile else None,
        weekend_hours=(profile.weekend_hours or None) if profile else None,
        phone=(profile.phone or None) if profile else None,
        lat=place.lat,
        lng=place.lng,
        is_partner=bool(profile.is_partner) if profile else False,
    )


def list_gyms(
    db: Session,
    *,
    lat: float | None = None,
    lng: float | None = None,
    partner_only: bool = False,
) -> list[GymOut]:
    """헬스장 목록. 좌표를 주면 거리순, 아니면 이름순."""
    query = (
        select(Place, GymProfile)
        .outerjoin(GymProfile, GymProfile.place_id == Place.id)
        .where(Place.category == "fitness")
    )
    if partner_only:
        query = query.where(GymProfile.is_partner.is_(True))

    gyms = [_to_gym(place, profile, lat, lng) for place, profile in db.execute(query)]
    if lat is not None and lng is not None:
        # 좌표를 모르는 헬스장은 distance_km 가 0 이라 그냥 정렬하면 '가장 가까운 곳'
        # 으로 맨 앞에 온다. 뒤로 보내고 그 안에서는 이름순으로 둔다.
        gyms.sort(
            key=lambda g: (
                g.lat is None or g.lng is None,
                g.distance_km,
                g.name,
            )
        )
    else:
        gyms.sort(key=lambda g: g.name)
    return gyms


def get_gym(
    db: Session, gym_id: str, *, lat: float | None = None, lng: float | None = None
) -> GymOut | None:
    row = db.execute(
        select(Place, GymProfile)
        .outerjoin(GymProfile, GymProfile.place_id == Place.id)
        .where(Place.id == gym_id, Place.category == "fitness")
    ).first()
    if row is None:
        return None
    place, profile = row
    return _to_gym(place, profile, lat, lng)


def _to_trainer(user: User, profile: TrainerProfile) -> TrainerOut:
    try:
        certs = json.loads(profile.certifications_json or "[]")
    except json.JSONDecodeError:
        certs = []
    return TrainerOut(
        id=user.id,
        gym_id=profile.gym_id,
        name=user.name,
        role=profile.specialty or None,
        reason=profile.recommend_reason or None,
        # 앱은 "7년" 문자열을 그대로 렌더한다. 0 이면 표시할 게 없으므로 None.
        career=f"{profile.career_years}년" if profile.career_years else None,
        intro=profile.intro or None,
        certifications=[str(c) for c in certs] if isinstance(certs, list) else [],
    )


def _trainer_query():
    return (
        select(User, TrainerProfile)
        .join(TrainerProfile, TrainerProfile.trainer_id == User.id)
        .where(User.role == "trainer", User.is_active.is_(True))
    )


def list_trainers(db: Session, *, gym_id: str | None = None) -> list[TrainerOut]:
    query = _trainer_query()
    if gym_id is not None:
        query = query.where(TrainerProfile.gym_id == gym_id)
    return [_to_trainer(user, profile) for user, profile in db.execute(query)]


def list_recommended_trainers(db: Session) -> list[TrainerOut]:
    """추천 사유가 붙은 트레이너만. 사유가 비면 레일에 올리지 않는다."""
    query = _trainer_query().where(TrainerProfile.recommend_reason != "")
    return [_to_trainer(user, profile) for user, profile in db.execute(query)]


def get_trainer(db: Session, trainer_id: str) -> TrainerOut | None:
    row = db.execute(_trainer_query().where(User.id == trainer_id)).first()
    if row is None:
        return None
    user, profile = row
    return _to_trainer(user, profile)
