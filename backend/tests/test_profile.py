"""프로필 / 온보딩 / 건강 목표 / 회원 탈퇴 — DB 필요(로컬 skip, CI 실행)."""
from __future__ import annotations

from uuid import uuid4


def _register_and_login(client, name: str = "테스터") -> tuple[str, str]:
    """가입+로그인 후 (access_token, email) 반환."""
    email = f"prof-{uuid4().hex[:8]}@oncare.com"
    password = "pw-12345!"
    r = client.post("/v1/auth/register", json={"email": email, "password": password, "name": name})
    assert r.status_code == 201, r.text
    login = client.post("/v1/auth/login", data={"username": email, "password": password})
    assert login.status_code == 200, login.text
    return login.json()["access_token"], email


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_onboarding_saves_profile_and_marks_done(client):
    token, email = _register_and_login(client)
    body = {
        "name": "온보딩유저",
        "birth_date": "1990-01-15",
        "gender": "male",
        "height_cm": 175.0,
        "weight_kg": 82.0,
        "conditions": "고혈압, 당뇨 전단계",
        "goals": "혈압 정상화",
        "goal_weight_kg": 70.0,
        "goal_bp_systolic": 120,
        "daily_sodium_mg": 2000,
    }
    r = client.post("/v1/users/me/onboarding", json=body, headers=_auth(token))
    assert r.status_code == 200, r.text
    p = r.json()
    assert p["onboarded"] is True
    assert p["name"] == "온보딩유저"
    assert p["conditions"] == "고혈압, 당뇨 전단계"
    assert p["height_cm"] == 175.0
    assert p["goal_bp_systolic"] == 120

    # GET 으로도 동일하게 조회돼야 한다
    got = client.get("/v1/users/me/profile", headers=_auth(token))
    assert got.status_code == 200
    assert got.json()["onboarded"] is True
    assert got.json()["goal_weight_kg"] == 70.0


def test_update_me_changes_name_and_phone(client):
    token, _ = _register_and_login(client)
    r = client.put(
        "/v1/users/me",
        json={"name": "새이름", "phone": "010-1234-5678", "birth_date": "1988-03-03"},
        headers=_auth(token),
    )
    assert r.status_code == 200, r.text
    assert r.json()["name"] == "새이름"
    assert r.json()["phone"] == "010-1234-5678"

    me = client.get("/v1/users/me", headers=_auth(token))
    assert me.json()["name"] == "새이름"


def test_update_me_duplicate_email_conflicts_409(client):
    token_a, email_a = _register_and_login(client)
    token_b, _ = _register_and_login(client)
    r = client.put("/v1/users/me", json={"email": email_a}, headers=_auth(token_b))
    assert r.status_code == 409


def test_update_health_goals(client):
    token, _ = _register_and_login(client)
    r = client.put(
        "/v1/users/me/health-goals",
        json={
            "goal_weight_kg": 68.0,
            "goal_bp_systolic": 118,
            "goal_blood_sugar": 100,
            "daily_calories": 2000,
            "daily_sodium_mg": 1800,
            "daily_sugar_g": 30,
        },
        headers=_auth(token),
    )
    assert r.status_code == 200, r.text
    p = r.json()
    assert p["goal_weight_kg"] == 68.0
    assert p["daily_sodium_mg"] == 1800
    assert p["daily_sugar_g"] == 30

    # 저장 후 재조회에서도 값이 유지되어야 한다(실서버 영속 계약).
    me = client.get("/v1/users/me/profile", headers=_auth(token))
    assert me.json()["daily_sugar_g"] == 30


def test_delete_me_removes_account(client):
    token, email = _register_and_login(client)
    r = client.delete("/v1/users/me", headers=_auth(token))
    assert r.status_code == 200, r.text
    assert r.json()["status"] == "deleted"

    # 계정이 사라졌으므로 재로그인 불가
    again = client.post("/v1/auth/login", data={"username": email, "password": "pw-12345!"})
    assert again.status_code == 401


def test_profile_writes_require_auth(client):
    # require_auth 는 데모 폴백을 쓰지 않으므로 토큰 없으면 401
    assert client.post("/v1/users/me/onboarding", json={}).status_code == 401
    assert client.put("/v1/users/me", json={"name": "x"}).status_code == 401
    assert client.put("/v1/users/me/health-goals", json={}).status_code == 401
    assert client.delete("/v1/users/me").status_code == 401
