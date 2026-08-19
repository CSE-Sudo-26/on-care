"""로스터 성별 — 시드가 채우고, 로스터 카드가 그대로 내려준다. (#960)

성별을 내려 주지 않던 시절에는 트레이너 앱이 회원 id 로 표시값을 지어냈고,
데모(`seed-client-8`)와 실 API(`user-sera`)가 서로 다른 id 를 써서 같은 회원이
모드에 따라 다른 성별로 떴다.
"""

from __future__ import annotations


def _trainer_token(client) -> str:
    return client.post(
        "/v1/auth/login",
        data={"username": "trainer@oncare.com", "password": "oncare123"},
    ).json()["access_token"]


def test_seeded_members_have_a_gender(client, db_session):
    from sqlalchemy import select

    from app.db.seed_trainer import _MEMBER_GENDERS
    from app.models.models import HealthProfile

    for user_id, gender in _MEMBER_GENDERS.items():
        stored = db_session.scalar(
            select(HealthProfile.gender).where(HealthProfile.user_id == user_id)
        )
        assert stored == gender, f"{user_id} 성별 시드 누락: {stored!r}"


def test_roster_card_carries_the_stored_gender(client):
    token = _trainer_token(client)
    r = client.get("/v1/trainer/clients", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200

    by_id = {row["id"]: row for row in r.json()}
    assert by_id["user-sera"]["gender"] == "female"   # 오세라
    assert by_id["user-jiho"]["gender"] == "male"     # 한지호
    assert by_id["user-yuna"]["gender"] == "female"   # 신유나
    assert by_id["user-gayoung"]["gender"] == "female"  # 문가영


def test_gender_seed_keeps_a_value_someone_entered(client, db_session):
    """화면에서 고친 값은 재기동으로 되돌아가지 않는다."""
    from sqlalchemy import select

    from app.db.seed_trainer import seed_member_genders
    from app.models.models import HealthProfile

    profile = db_session.scalar(
        select(HealthProfile).where(HealthProfile.user_id == "user-sera")
    )
    assert profile is not None
    profile.gender = "other"
    db_session.commit()

    seed_member_genders()

    db_session.expire_all()
    assert db_session.scalar(
        select(HealthProfile.gender).where(HealthProfile.user_id == "user-sera")
    ) == "other"

    # 뒷 테스트를 위해 시드 값으로 되돌린다.
    profile = db_session.scalar(
        select(HealthProfile).where(HealthProfile.user_id == "user-sera")
    )
    profile.gender = "female"
    db_session.commit()


def test_health_profile_seed_survives_the_gender_seed(client, db_session):
    """성별 시드가 김민수의 위험도·영양 목표를 덮거나 막지 않는다.

    성별만 든 프로필 행이 먼저 생기면, 위험도·목표를 넣는 시드가 "이미 행이
    있다"며 통째로 건너뛴다. 순서를 지키는지 그 결과로 확인한다.
    """
    from sqlalchemy import select

    from app.models.models import HealthProfile

    profile = db_session.scalar(
        select(HealthProfile).where(HealthProfile.user_id == "user-demo")
    )
    assert profile is not None
    assert profile.gender == "male"
    assert profile.risk_title  # 위험 카드 문구가 살아 있다
    assert profile.daily_calories  # 일일 영양 목표도 남아 있다
