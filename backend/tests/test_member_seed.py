"""회원 데모 시드(운동·건강프로필)의 주간 경계·멱등성 — 리뷰 반영(#311).

DB 필요(로컬 skip, CI 의 Postgres 서비스에서 실행). client 픽스처가 init_db →
seed_member_health_data 를 먼저 돌린 상태를 검증한다.
"""
from __future__ import annotations

from datetime import date, timedelta

from sqlalchemy import func, select


_MEMBER_ID = "user-demo"


def _this_monday_iso() -> str:
    today = date.today()
    return (today - timedelta(days=today.weekday())).isoformat()


def test_exercise_seed_has_this_week_start(client, db_session):
    """시드된 운동 세션의 week_start 는 이번 주 월요일이다."""
    from app.models.models import ExerciseSession

    rows = db_session.scalars(
        select(ExerciseSession).where(ExerciseSession.user_id == _MEMBER_ID)
    ).all()
    assert rows, "운동 시드가 없습니다."
    assert all(r.week_start == _this_monday_iso() for r in rows)


def test_exercise_seed_skips_future_weekdays(client, db_session):
    """미래 요일은 이번 주 합계·streak 에 잡히지 않도록 시드하지 않는다(#311)."""
    from app.db.seed_member_data import _WEEKDAY_INDEX
    from app.models.models import ExerciseSession

    today_idx = date.today().weekday()
    labels = db_session.scalars(
        select(ExerciseSession.day_label).where(
            ExerciseSession.user_id == _MEMBER_ID,
            ExerciseSession.week_start == _this_monday_iso(),
        )
    ).all()
    assert labels, "이번 주 운동 시드가 없습니다."
    # 시드된 모든 요일은 오늘(포함) 이전이어야 한다.
    assert all(_WEEKDAY_INDEX[label] <= today_idx for label in labels)


def test_exercise_seed_is_idempotent(client, db_session):
    """재실행해도 세션 수가 늘지 않는다(세션 id 단위 멱등)."""
    from app.db.seed_member_data import _seed_exercise
    from app.models.models import ExerciseSession

    def _count() -> int:
        return db_session.scalar(
            select(func.count())
            .select_from(ExerciseSession)
            .where(
                ExerciseSession.user_id == _MEMBER_ID,
                ExerciseSession.week_start == _this_monday_iso(),
            )
        )

    before = _count()
    assert before > 0
    _seed_exercise(db_session, _MEMBER_ID)
    _seed_exercise(db_session, _MEMBER_ID)
    assert _count() == before


def test_health_profile_seeded_once(client, db_session):
    """건강 프로필은 시드되어 있고, 재실행해도 중복 생성되지 않는다(멱등)."""
    from app.db.seed_member_data import _seed_health_profile
    from app.models.models import HealthProfile

    def _count() -> int:
        return db_session.scalar(
            select(func.count())
            .select_from(HealthProfile)
            .where(HealthProfile.user_id == _MEMBER_ID)
        )

    assert _count() == 1
    _seed_health_profile(db_session, _MEMBER_ID)
    assert _count() == 1


def test_health_profile_goals_persisted(client, db_session):
    """프로필이 없던 회원에 시드하면 위험도·활동 관련 필드가 저장된다."""
    from app.models.models import HealthProfile

    profile = db_session.scalar(
        select(HealthProfile).where(HealthProfile.user_id == _MEMBER_ID)
    )
    assert profile is not None
    assert profile.risk_level == "medium"
    assert profile.risk_title
