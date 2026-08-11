"""트레이너 도메인 — 역할 인증 + /trainer/me.

- role 파싱/기본값은 순수(로컬 실행).
- 엔드포인트 보호(200/403/401)는 DB 필요(로컬 skip, CI 실행).
"""

from __future__ import annotations

from uuid import uuid4

from app.core import clock


def test_user_role_defaults_to_member():
    from app.models.models import User

    # SQLAlchemy 컬럼 default 는 flush 시 적용되므로, 여기선 모델 기본 문자열만 확인.
    assert User.__table__.c.role.default.arg == "member"


def _trainer_token(client) -> str:
    """시드된 데모 트레이너로 로그인."""
    return client.post(
        "/v1/auth/login",
        data={"username": "trainer@oncare.com", "password": "oncare123"},
    ).json()["access_token"]


def _member_token(client) -> str:
    email = f"member-{uuid4().hex[:8]}@oncare.com"
    client.post(
        "/v1/auth/register", json={"email": email, "password": "pw!", "name": "u"}
    )
    return client.post(
        "/v1/auth/login", data={"username": email, "password": "pw!"}
    ).json()["access_token"]


def test_trainer_me_returns_profile(client):
    token = _trainer_token(client)
    r = client.get("/v1/trainer/me", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["name"] == "김트레이너"
    assert body["email"] == "trainer@oncare.com"
    assert body["career"] == "7년"
    assert body["gym"]["name"] == "온케어짐 신촌점"
    assert "생활스포츠지도사 2급" in body["certifications"]


def test_trainer_me_treats_non_list_certifications_as_empty(client, db_session):
    """유효한 JSON이더라도 배열이 아니면 응답 검증 500 대신 빈 자격 목록으로 정규화한다."""
    from sqlalchemy import select

    from app.db.seed_trainer import TRAINER_ID
    from app.models.models import TrainerProfile

    profile = db_session.scalar(
        select(TrainerProfile).where(TrainerProfile.trainer_id == TRAINER_ID)
    )
    assert profile is not None
    original = profile.certifications_json
    profile.certifications_json = '{"unexpected": "object"}'
    db_session.commit()

    try:
        token = _trainer_token(client)
        response = client.get(
            "/v1/trainer/me",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200, response.text
        assert response.json()["certifications"] == []
    finally:
        profile.certifications_json = original
        db_session.commit()


def test_member_cannot_access_trainer_endpoint(client):
    token = _member_token(client)
    r = client.get("/v1/trainer/me", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 403


def test_unauthenticated_trainer_is_rejected(client):
    # require_trainer 는 데모 폴백을 쓰지 않으므로 토큰 없으면 401
    r = client.get("/v1/trainer/me")
    assert r.status_code == 401


def test_demo_trainer_client_links_seeded(client, db_session):
    from sqlalchemy import select

    from app.db.seed_trainer import _MEMBERS, TRAINER_ID
    from app.models.models import TrainerClient

    links = db_session.scalars(
        select(TrainerClient).where(TrainerClient.trainer_id == TRAINER_ID)
    ).all()
    # 명단 크기는 _MEMBERS 에서 읽는다 — 로스터가 늘 때마다 테스트를 고치지 않도록.
    assert len(links) == len(_MEMBERS)
    member_ids = {l.member_id for l in links}
    assert {"user-demo", "user-jisu", "user-sungho"} <= member_ids


# ---- 리뷰 반영: prod 데모 시드 안전장치(순수, DB 불필요) ----


def test_prod_demo_seed_requires_strong_password():
    import pytest

    from app.core.config import Settings

    common = dict(
        _env_file=None,
        env="prod",
        jwt_secret="a-strong-enough-production-secret-value-01234567",
        cors_allow_origins="https://app.example.com",
        auto_create_tables=False,  # 운영 스키마 가드(#288) 충족 — 이 테스트는 데모 비번 강도만 검증
    )
    # 기본값 + 데모 시드 → 기동 거부
    with pytest.raises(ValueError):
        Settings(**common, seed_demo_data=True)
    # 빈 문자열·짧은 문자열·기본값 모두 거부(강도 검증)
    for weak in ("", "short", "oncare123", "abc12345678"):  # 마지막은 11자(<12)
        with pytest.raises(ValueError):
            Settings(**common, seed_demo_data=True, demo_login_password=weak)
    # 기본값이 아니고 12자 이상이면 데이터 든 데모 계정을 운영에도 둘 수 있음
    ok = Settings(**common, seed_demo_data=True, demo_login_password="Str0ng!Demo#Pass")
    assert ok.demo_login_password == "Str0ng!Demo#Pass"
    # 데모 시드를 끄면(운영 기본 권장) 당연히 통과
    off = Settings(**common, seed_demo_data=False)
    assert off.seed_demo_data is False


# ---- 리뷰 반영: 역할 분리(트레이너 토큰의 회원 API 접근 차단) ----


def test_trainer_token_rejected_by_member_api(client):
    token = _trainer_token(client)
    h = {"Authorization": f"Bearer {token}"}
    # 회원 읽기(CurrentUser)와 회원 쓰기(RequireMember) 모두 403
    assert client.get("/v1/users/me", headers=h).status_code == 403
    assert client.get("/v1/diet/days/today", headers=h).status_code == 403


def test_member_api_still_works_without_token(client):
    # 데모 폴백(회원)은 그대로 동작 — 미인증 읽기는 회원 데모로 200
    assert client.get("/v1/users/me").status_code == 200


# ---- 리뷰 반영: 시드 멱등성(이메일 충돌·재실행) ----


def test_trainer_seed_is_idempotent(client, db_session):
    from sqlalchemy import func, select

    from app.db.seed_trainer import _MEMBERS, TRAINER_ID, seed_trainer_domain
    from app.models.models import TrainerClient, User

    # 여러 번 재실행해도 계정/링크 수가 늘지 않는다
    seed_trainer_domain()
    seed_trainer_domain()
    links = db_session.scalar(
        select(func.count())
        .select_from(TrainerClient)
        .where(TrainerClient.trainer_id == TRAINER_ID)
    )
    assert links == len(_MEMBERS)
    trainers = db_session.scalar(
        select(func.count()).select_from(User).where(User.role == "trainer")
    )
    assert trainers >= 1


def test_every_demo_member_can_log_in(client):
    """데모 회원 3명 모두 DEMO_LOGIN_PASSWORD 로 로그인된다.

    김민수(user-demo)는 데모 사용자 시드가 seed_trainer 보다 먼저 돌며 빈 해시로
    만들던 탓에 로그인이 막혀 있었다. 하필 트레이너의 1번 고객이라 시연·통합
    검증에서 가장 먼저 고르는 계정이다(#571).
    """
    from app.core.config import get_settings

    password = get_settings().demo_login_password
    for email in ("minsu@oncare.com", "jisu@oncare.com", "sungho@oncare.com"):
        r = client.post(
            "/v1/auth/login", data={"username": email, "password": password}
        )
        assert r.status_code == 200, f"{email} 로그인 실패: {r.status_code} {r.text}"
        assert r.json().get("access_token")


def test_seed_backfills_an_empty_demo_password(client, db_session):
    """이미 빈 해시로 만들어진 볼륨도 재기동만으로 복구된다.

    그냥 건너뛰면 기존 개발자는 볼륨을 지우기 전까지 계속 로그인할 수 없다.
    """
    from sqlalchemy import select

    from app.core.config import get_settings
    from app.db.seed_trainer import seed_trainer_domain
    from app.models.models import User

    minsu = db_session.scalar(select(User).where(User.id == "user-demo"))
    assert minsu is not None
    minsu.hashed_password = ""  # 회귀 상황 재현
    db_session.commit()

    seed_trainer_domain()

    # 해시가 비어 있지 않은지만 보면 엉뚱한 문자열도 통과한다. 복구의 기준은
    # "로그인이 되는가" 이므로 실제 로그인 계약으로 확인한다(리뷰 지적).
    r = client.post(
        "/v1/auth/login",
        data={
            "username": "minsu@oncare.com",
            "password": get_settings().demo_login_password,
        },
    )
    assert r.status_code == 200, f"백필된 해시로 로그인되지 않는다: {r.text}"
    assert r.json().get("access_token")


def test_backfill_skips_an_account_that_only_shares_the_id(client, db_session):
    """id 만 같고 이메일·역할이 다른 계정에는 데모 비밀번호를 심지 않는다.

    id 만 보고 채우면, 그 id 를 선점한 남의 계정에 널리 알려진 데모 비밀번호로
    로그인할 수단을 새로 만들어 주게 된다(리뷰 지적, PR #577).
    """
    from sqlalchemy import select

    from app.db.seed_trainer import seed_trainer_domain
    from app.models.models import User

    squatter = db_session.scalar(select(User).where(User.id == "user-sungho"))
    assert squatter is not None
    # 해시까지 저장해 뒀다가 직접 되돌린다. 시드가 복구해 주기를 기대하면, 정작
    # 백필에 회귀가 생겼을 때 이 테스트는 통과하면서 뒤따르는 테스트에 빈 비밀번호를
    # 남긴다(리뷰 지적).
    original_email = squatter.email
    original_role = squatter.role
    original_hash = squatter.hashed_password
    squatter.email = "someone-else@example.com"
    squatter.role = "trainer"
    squatter.hashed_password = ""  # 백필 대상으로 보이는 상태
    db_session.commit()

    try:
        seed_trainer_domain()

        db_session.expire_all()
        after = db_session.scalar(select(User).where(User.id == "user-sungho"))
        assert (
            after.hashed_password == ""
        ), "이메일·역할이 다른 계정에는 데모 비밀번호를 심으면 안 된다"
    finally:
        db_session.expire_all()
        restored = db_session.scalar(select(User).where(User.id == "user-sungho"))
        restored.email = original_email
        restored.role = original_role
        restored.hashed_password = original_hash
        db_session.commit()


def test_email_conflict_is_detected(client, db_session):
    """이메일 충돌 감지 로직(시드가 이걸로 안전 스킵). 비파괴 — 임시행만 쓰고 정리."""
    from app.db.seed_trainer import _email_taken_by_other
    from app.models.models import User

    db_session.add(
        User(
            id="tmp-squatter",
            email="conflict-test@oncare.com",
            name="x",
            role="member",
        )
    )
    db_session.commit()
    try:
        # 다른 id 가 같은 이메일을 쓰려 하면 충돌로 감지 → 시드는 스킵한다
        assert (
            _email_taken_by_other(db_session, "conflict-test@oncare.com", "other-id")
            is True
        )
        # 본인 id 는 충돌 아님
        assert (
            _email_taken_by_other(
                db_session, "conflict-test@oncare.com", "tmp-squatter"
            )
            is False
        )
    finally:
        db_session.query(User).filter(User.id == "tmp-squatter").delete()
        db_session.commit()


# ---- #250: 로스터 + 회원 실데이터 공유 ----


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


# 고정 수치 검증은 test_diet 가 건드리지 않는 회원(user-jisu)으로 한다 — user-demo 는
# 데모 폴백 대상이라 다른 테스트가 오늘 식단을 추가해 합계가 흔들린다(리뷰 PR 250-#2).
def test_trainer_clients_roster_aggregates_real_diet(client):
    token = _trainer_token(client)
    r = client.get("/v1/trainer/clients", headers=_auth(token))
    assert r.status_code == 200, r.text
    clients = {c["id"]: c for c in r.json()}
    assert {"user-demo", "user-jisu", "user-sungho"} <= set(clients)

    jisu = clients["user-jisu"]
    # 오늘 3끼 합(회원 실데이터 집계): 280+750+650=1680, 200+980+620=1800, 당류 38
    assert jisu["calories"] == 1680
    assert jisu["sodium_mg"] == 1800
    assert jisu["sugar_g"] == 38
    assert jisu["carbs_g"] == 150
    assert jisu["protein_g"] == 90
    assert jisu["fat_g"] == 48
    assert jisu["name"] == "이지수"
    assert len(jisu["sodium_week"]) == 7
    assert jisu["sodium_week"][-1] == 1800  # 오늘 = 3끼 나트륨 합
    assert len(jisu["week_completion"]) == 7


def test_trainer_client_diet_maps_member_meals(client):
    token = _trainer_token(client)
    r = client.get("/v1/trainer/clients/user-jisu/diet", headers=_auth(token))
    assert r.status_code == 200, r.text
    meals = r.json()
    assert len(meals) == 3
    assert meals[0]["meal"] == "아침"
    assert "그릭요거트" in meals[0]["items"]
    assert meals[0]["calories"] == 280
    assert meals[0]["carbs_g"] == 40
    assert meals[0]["protein_g"] == 15
    assert meals[0]["fat_g"] == 6


def test_trainer_client_macros_are_member_scoped_and_empty_day_is_empty(client):
    token = _trainer_token(client)

    jisu = client.get(
        "/v1/trainer/clients/user-jisu/diet",
        headers=_auth(token),
    ).json()
    sungho = client.get(
        "/v1/trainer/clients/user-sungho/diet",
        headers=_auth(token),
    ).json()
    assert sum(meal["carbs_g"] for meal in jisu) == 150
    assert sum(meal["carbs_g"] for meal in sungho) == 175
    assert jisu != sungho

    empty = client.get(
        "/v1/trainer/clients/user-jisu/diet?date=2099-01-01",
        headers=_auth(token),
    )
    assert empty.status_code == 200
    assert empty.json() == []


def test_trainer_client_without_diet_has_zero_macro_totals(client, db_session):
    from app.db.seed_trainer import TRAINER_ID
    from app.models.models import TrainerClient, User

    member_id = "tmp-member-no-diet"
    db_session.add(
        User(
            id=member_id,
            email="tmp-member-no-diet@oncare.test",
            name="식단없음",
            role="member",
        )
    )
    db_session.flush()
    db_session.add(
        TrainerClient(
            id="tmp-link-no-diet",
            trainer_id=TRAINER_ID,
            member_id=member_id,
            goal="",
            sort_order=999,
        )
    )
    db_session.commit()

    try:
        token = _trainer_token(client)
        roster = client.get("/v1/trainer/clients", headers=_auth(token)).json()
        no_diet = next(item for item in roster if item["id"] == member_id)
        assert no_diet["carbs_g"] == 0
        assert no_diet["protein_g"] == 0
        assert no_diet["fat_g"] == 0
    finally:
        db_session.query(TrainerClient).filter(
            TrainerClient.id == "tmp-link-no-diet"
        ).delete()
        db_session.query(User).filter(User.id == member_id).delete()
        db_session.commit()


def test_trainer_client_history_newest_first(client):
    token = _trainer_token(client)
    r = client.get("/v1/trainer/clients/user-jisu/history", headers=_auth(token))
    assert r.status_code == 200, r.text
    hist = r.json()
    assert len(hist) >= 1
    # 최신 우선: 오늘 기록이 맨 앞. (다른 테스트가 오늘자 PT 기록을 추가할 수 있어
    # hist[0]의 라벨을 고정하지 않고, '오늘이 선두 + 시드 AI 루틴 존재'로 검증한다.)
    assert "(오늘)" in hist[0]["date_label"]
    assert any(h["label"] == "AI 루틴 · 자율 운동" for h in hist)


def test_history_excludes_other_trainers_records(client, db_session):
    """다른 트레이너가 작성한 기록/메모는 이 트레이너의 조회에 노출되지 않는다(PR 250-#1)."""
    from datetime import date

    from app.db.seed_trainer import TRAINER_ID
    from app.models.models import RoutineHistory, User
    from app.services.trainer_service import build_client_history

    db_session.add(
        User(
            id="trainer-other",
            email="other-t@oncare.com",
            name="타트레이너",
            role="trainer",
        )
    )
    db_session.flush()  # RoutineHistory.trainer_id FK 성립을 위해 User 를 먼저 반영
    db_session.add(
        RoutineHistory(
            id="hist-other-secret",
            member_id="user-jisu",
            trainer_id="trainer-other",
            date=clock.today().isoformat(),
            kind_label="PT 세션 · 타트레이너",
            completion_rate=100,
            exercises_json="[]",
            client_feedback="",
            trainer_note="비밀 메모",
        )
    )
    db_session.commit()
    try:
        mine = build_client_history(db_session, "user-jisu", TRAINER_ID)
        assert all(h.trainer_note != "비밀 메모" for h in mine)
        assert all(h.label != "PT 세션 · 타트레이너" for h in mine)
        # 타 트레이너 본인 조회에는 보인다(격리 확인)
        theirs = build_client_history(db_session, "user-jisu", "trainer-other")
        assert any(h.trainer_note == "비밀 메모" for h in theirs)
    finally:
        db_session.query(RoutineHistory).filter(
            RoutineHistory.id == "hist-other-secret"
        ).delete()
        db_session.query(User).filter(User.id == "trainer-other").delete()
        db_session.commit()


def test_trainer_cannot_read_unassigned_client(client):
    token = _trainer_token(client)
    r = client.get("/v1/trainer/clients/user-nobody/diet", headers=_auth(token))
    assert r.status_code == 404


def test_member_cannot_read_roster(client):
    token = _member_token(client)
    r = client.get("/v1/trainer/clients", headers=_auth(token))
    assert r.status_code == 403


def test_trainer_can_read_and_update_member_health_profile(client, db_session):
    from sqlalchemy import select

    from app.models.models import HealthProfile

    token = _trainer_token(client)
    url = "/v1/trainer/clients/user-jisu/health-profile"
    profile_before = db_session.scalar(
        select(HealthProfile).where(HealthProfile.user_id == "user-jisu")
    )
    original = (
        {
            "gender": profile_before.gender,
            "conditions": profile_before.conditions,
            "height_cm": profile_before.height_cm,
            "weight_kg": profile_before.weight_kg,
            "goals": profile_before.goals,
            "weekly_workout_goal": profile_before.weekly_workout_goal,
            "weekly_exercise_minutes_goal": (
                profile_before.weekly_exercise_minutes_goal
            ),
            "weekly_burn_goal": profile_before.weekly_burn_goal,
        }
        if profile_before is not None
        else None
    )

    try:
        response = client.put(
            url,
            headers=_auth(token),
            json={
                "gender": "female",
                "conditions": "고혈압",
                "height_cm": 164.5,
                "weight_kg": 57.2,
                "goals": "근력 향상과 체지방 감량",
                "weekly_workout_goal": 4,
                "weekly_exercise_minutes_goal": 180,
                "weekly_burn_goal": 1600,
            },
        )
        assert response.status_code == 200, response.text
        body = response.json()
        assert body["member_id"] == "user-jisu"
        assert body["gender"] == "female"
        assert body["conditions"] == "고혈압"
        assert body["height_cm"] == 164.5
        assert body["weight_kg"] == 57.2
        assert body["goals"] == "근력 향상과 체지방 감량"
        assert body["weekly_workout_goal"] == 4

        fetched = client.get(url, headers=_auth(token))
        assert fetched.status_code == 200, fetched.text
        fetched_body = fetched.json()
        assert fetched_body["gender"] == "female"
        assert fetched_body["conditions"] == "고혈압"
        assert fetched_body["weekly_exercise_minutes_goal"] == 180
        assert fetched_body["weekly_burn_goal"] == 1600
    finally:
        # The API uses a separate session. Reload its committed row before
        # restoring state; otherwise SQLAlchemy may consider the original
        # in-memory values unchanged and skip the cleanup UPDATE.
        db_session.expire_all()
        profile_after = db_session.scalar(
            select(HealthProfile).where(HealthProfile.user_id == "user-jisu")
        )
        if original is None:
            if profile_after is not None:
                db_session.delete(profile_after)
        else:
            assert profile_after is not None
            for field, value in original.items():
                setattr(profile_after, field, value)
        db_session.commit()


def test_trainer_cannot_read_unassigned_member_health_profile(client):
    token = _trainer_token(client)
    response = client.get(
        "/v1/trainer/clients/user-nobody/health-profile",
        headers=_auth(token),
    )
    assert response.status_code == 404
