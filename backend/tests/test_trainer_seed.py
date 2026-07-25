"""트레이너 시드의 역할/이메일 충돌 안전성 — 리뷰 반영(#249).

기존 ID 가 기대와 다른 역할로 선점돼 있어도 트레이너 프로필·담당 링크를
잘못 만들지 않는지 검증한다. 공유 DB 를 잠시 바꾸지만 finally 에서 원복한다.
DB 필요(로컬 skip, CI 실행).
"""
from __future__ import annotations

from sqlalchemy import select


def test_trainer_id_role_conflict_skips_profile(client, db_session):
    """trainer-demo ID 가 회원 역할로 선점돼 있으면 프로필을 붙이지 않는다."""
    from app.db.seed_trainer import TRAINER_ID, _seed_trainer_account
    from app.models.models import TrainerProfile, User

    trainer = db_session.get(User, TRAINER_ID)
    orig_role = trainer.role
    # 프로필 제거 + 역할을 member 로 위장(선점 상황 재현)
    db_session.query(TrainerProfile).filter(
        TrainerProfile.trainer_id == TRAINER_ID
    ).delete()
    trainer.role = "member"
    db_session.commit()
    try:
        _seed_trainer_account(db_session)
        # 역할 불일치 → 프로필 재생성 스킵
        prof = db_session.scalar(
            select(TrainerProfile).where(TrainerProfile.trainer_id == TRAINER_ID)
        )
        assert prof is None
    finally:
        trainer = db_session.get(User, TRAINER_ID)
        trainer.role = orig_role
        db_session.commit()
        _seed_trainer_account(db_session)  # 원복: 프로필 재생성
        assert db_session.scalar(
            select(TrainerProfile).where(TrainerProfile.trainer_id == TRAINER_ID)
        ) is not None


def test_member_id_role_conflict_skips_link(client, db_session):
    """회원 ID 가 트레이너 역할로 선점돼 있으면 담당 링크를 만들지 않는다."""
    from app.db.seed_trainer import TRAINER_ID, _seed_client_links
    from app.models.models import TrainerClient, User

    member_id = "user-sungho"  # 로스터 테스트가 값 검증에 쓰는 jisu/demo 는 피한다
    member = db_session.get(User, member_id)
    orig_role = member.role
    link_id = f"tc-{TRAINER_ID}-{member_id}"

    db_session.query(TrainerClient).filter(TrainerClient.id == link_id).delete()
    member.role = "trainer"  # 회원이 아닌 역할로 위장
    db_session.commit()
    try:
        _seed_client_links(db_session)
        # 역할 불일치 → 링크 재생성 스킵
        assert db_session.scalar(
            select(TrainerClient).where(TrainerClient.id == link_id)
        ) is None
    finally:
        member = db_session.get(User, member_id)
        member.role = orig_role
        db_session.commit()
        _seed_client_links(db_session)  # 원복: 링크 재생성
        assert db_session.scalar(
            select(TrainerClient).where(TrainerClient.id == link_id)
        ) is not None
