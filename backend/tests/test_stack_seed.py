"""스택 시드 통합 — 이메일 충돌 시 하위 건강 데이터 시드가 FK 오류로 죽지 않는지(#250).

#249(계정/링크 시드)와 #250(건강 데이터 시드)을 이메일 충돌 상황에서 연속 실행해도
기동이 실패하지 않고, 링크가 성립하지 않은 회원은 시드에서 안전하게 제외되는지 검증한다.
DB 필요(로컬 skip, CI 실행). 공유 DB 를 잠시 바꾸지만 finally 에서 원복한다.
"""
from __future__ import annotations

from sqlalchemy import select


def test_email_conflict_seed_is_safe(client, db_session):
    from app.db.seed_member_data import seed_member_health_data
    from app.db.seed_trainer import seed_trainer_domain
    from app.models.models import DietEntry, TrainerClient, User

    victim = "user-sungho"
    squatter_id = "sq-sungho"
    squatter_email = "sungho@oncare.com"

    v = db_session.get(User, victim)
    assert v is not None
    # victim 계정 제거(FK CASCADE 로 링크·식단·기록·채팅·루틴 정리). 이메일 유니크 충돌을
    # 피하려 삭제를 먼저 커밋한 뒤, 같은 이메일을 선점하는 계정을 만든다.
    db_session.delete(v)
    db_session.commit()
    db_session.add(User(id=squatter_id, email=squatter_email, name="선점", role="member"))
    db_session.commit()
    try:
        # 이메일 충돌 상태에서 두 시드를 연속 실행 — FK 오류로 죽으면 여기서 예외 발생
        seed_trainer_domain()        # victim 재생성 실패(이메일 선점) + 링크 스킵
        seed_member_health_data()    # 링크 없는 victim/squatter 는 시드 대상에서 제외
        db_session.expire_all()

        # 크래시 없이 도달 + victim/squatter 의 링크·식단이 만들어지지 않음
        assert db_session.scalar(
            select(TrainerClient.id).where(TrainerClient.member_id == victim).limit(1)
        ) is None
        assert db_session.scalar(
            select(DietEntry.id).where(DietEntry.user_id == victim).limit(1)
        ) is None
        assert db_session.scalar(
            select(DietEntry.id).where(DietEntry.user_id == squatter_id).limit(1)
        ) is None
    finally:
        # 원복: 선점 계정 제거 → 시드 재실행으로 victim 계정·링크·데이터 복구
        db_session.query(User).filter(User.id == squatter_id).delete()
        db_session.commit()
        seed_trainer_domain()
        seed_member_health_data()
        db_session.expire_all()
        assert db_session.get(User, victim) is not None
