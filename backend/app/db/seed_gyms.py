"""제휴 헬스장 데모 시드 — 회원앱 헬스장·트레이너 디렉터리의 실데이터. (#324)

헬스장은 `places`(category='fitness') 에 넣는다. 상담 검증
(`consultation_service._validate_target`)이 그 테이블을 보므로, 여기 없는 헬스장은
상담 신청이 404 가 난다.

부가 정보(평점·영업시간·전화·태그)는 `gym_profiles` 에 둔다 — `places` 는 병원·약국·
건강식이 함께 쓰는 테이블이라 헬스장 전용 컬럼을 붙이면 오염된다.

멱등: 존재하면 건너뛴다. `seed_demo_data` 가 켜졌을 때만 호출된다.
"""
from __future__ import annotations

import json
import logging

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.session import SessionLocal
from app.models import models

logger = logging.getLogger(__name__)

#: 프론트 `MockGymRepository` 와 같은 id·좌표를 쓴다 — 앱이 mock 에서 실 API 로
#: 넘어갈 때 id 가 바뀌면 진행 중인 상담·연결이 끊긴다.
_GYMS: tuple[tuple[str, str, str, float, float, float, str, str, str, list[str]], ...] = (
    (
        "gym-oncare-sinchon", "온케어짐 신촌점", "서울 서대문구 신촌로 120",
        37.5559, 126.9368, 4.7, "06:00 – 23:00", "08:00 - 20:00", "02-1234-5678",
        ["다이어트", "재활운동"],
    ),
    (
        "gym-healthmate", "헬스메이트 신촌점", "서울 서대문구 신촌로 83",
        37.5548, 126.9385, 4.5, "05:30 - 24:00", "07:00 - 22:00", "02-2345-6789",
        ["근력운동", "만성질환 관리"],
    ),
    (
        "gym-bodyandsoul", "바디앤소울 피트니스", "서울 마포구 백범로 23",
        37.5455, 126.9425, 4.8, "06:00 - 22:00", "09:00 - 18:00", "02-3456-7890",
        ["PT", "식단 상담"],
    ),
)


def seed_partner_gyms() -> None:
    db: Session = SessionLocal()
    try:
        created = 0
        # 장소를 먼저 flush 해야 gym_profiles 의 FK 가 성립한다. 한 번에 add 하면
        # 같은 flush 안에서 gym_profiles 가 먼저 나가 FK 위반이 난다.
        for gym_id, name, address, lat, lng, *_ in _GYMS:
            if db.get(models.Place, gym_id) is None:
                db.add(models.Place(
                    id=gym_id, name=name, category="fitness", address=address,
                    lat=lat, lng=lng,
                ))
                created += 1
        db.flush()

        for (
            gym_id, _name, _address, _lat, _lng, rating,
            weekday, weekend, phone, tags,
        ) in _GYMS:
            if db.get(models.GymProfile, gym_id) is None:
                db.add(models.GymProfile(
                    place_id=gym_id, rating=rating, weekday_hours=weekday,
                    weekend_hours=weekend, phone=phone,
                    tags_json=json.dumps(tags, ensure_ascii=False),
                    is_partner=True,
                ))
        db.commit()

        # 기존 트레이너의 소속을 gym_id 로 잇는다. 시드된 트레이너는 gym_name 만
        # 들고 있어 헬스장 상세의 "소속 트레이너"가 비어 있었다.
        linked = 0
        profiles = db.scalars(
            select(models.TrainerProfile).where(
                models.TrainerProfile.gym_id.is_(None)
            )
        ).all()
        by_name = {name: gid for gid, name, *_ in _GYMS}
        for profile in profiles:
            gym_id = by_name.get(profile.gym_name)
            if gym_id is None:
                continue
            profile.gym_id = gym_id
            linked += 1
        db.commit()

        if created or linked:
            logger.info(
                "제휴 헬스장 시드: 신규 %d곳, 트레이너 소속 연결 %d명", created, linked
            )
    finally:
        db.close()
