"""트레이너 리포트 · 프로필 수정 · 고객 AI 코칭 엔드포인트.

순수 로직(주 경계, 리포트 문구)은 DB 없이 돌고, 엔드포인트는 DB 필요
(로컬 skip, CI 실행).
"""
from __future__ import annotations

from datetime import date
from uuid import uuid4


def _trainer_token(client) -> str:
    return client.post(
        "/v1/auth/login",
        data={"username": "trainer@oncare.com", "password": "oncare123"},
    ).json()["access_token"]


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


# ---- 순수 로직 ----

def test_week_start_of_normalises_any_day_to_monday():
    from app.services.trainer_service import week_start_of

    monday = date(2026, 8, 3)
    for offset in range(7):
        assert week_start_of(date(2026, 8, 3 + offset)) == monday


def test_report_message_omits_figures_without_data():
    """기록이 없는 항목은 빈 값을 적지 않고 아예 뺀다 — '이행률 0%'는 거짓말."""
    from app.schemas.trainer_api import WeeklyReportOut
    from app.services.trainer_service import report_message

    report = WeeklyReportOut(
        member_id="m", member_name="김민수",
        week_start="2026-08-03", week_end="2026-08-09",
        sessions_booked=0, sessions_done=0,
        completion_avg=None, sodium_over_days=0, sodium_avg=None,
        message="",
    )
    text = report_message(report)
    assert "주간 리포트" in text
    assert "이행률" not in text
    assert "나트륨" not in text


def test_report_message_praises_only_a_genuinely_good_week():
    from app.schemas.trainer_api import WeeklyReportOut
    from app.services.trainer_service import report_message

    def message(completion: int, over_days: int) -> str:
        return report_message(WeeklyReportOut(
            member_id="m", member_name="김민수",
            week_start="2026-08-03", week_end="2026-08-09",
            sessions_booked=2, sessions_done=2,
            completion_avg=completion, sodium_over_days=over_days,
            sodium_avg=1500, message="",
        ))

    assert "잘하셨어요" in message(80, 1)
    # 이행률이 좋아도 식단이 무너졌으면 칭찬만 하고 넘어가지 않는다.
    assert "잘하셨어요" not in message(80, 4)
    assert "잘하셨어요" not in message(40, 0)


# ---- 엔드포인트 ----

def test_report_returns_the_week_containing_the_requested_day(client):
    token = _trainer_token(client)
    r = client.get(
        "/v1/trainer/clients/user-jisu/report",
        params={"week_start": "2026-08-05"},  # 수요일
        headers=_auth(token),
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["week_start"] == "2026-08-03"
    assert body["week_end"] == "2026-08-09"
    assert body["member_id"] == "user-jisu"
    # 미리보기와 전송 본문이 갈라지지 않도록 메시지를 함께 내려준다.
    assert body["message"]


def test_report_rejects_a_malformed_week_start(client):
    token = _trainer_token(client)
    r = client.get(
        "/v1/trainer/clients/user-jisu/report",
        params={"week_start": "2026-08"},
        headers=_auth(token),
    )
    assert r.status_code == 422


def test_report_of_someone_elses_client_is_404(client):
    token = _trainer_token(client)
    r = client.get("/v1/trainer/clients/user-nobody/report", headers=_auth(token))
    assert r.status_code == 404


def test_send_report_lands_in_the_member_chat_thread(client):
    token = _trainer_token(client)
    r = client.post(
        "/v1/trainer/clients/user-jisu/report/send",
        json={"week_start": "2026-08-05"},
        headers=_auth(token),
    )
    assert r.status_code == 201, r.text
    assert "주간 리포트" in r.json()["body"]

    thread = client.get(
        "/v1/trainer/clients/user-jisu/chat", headers=_auth(token)
    ).json()
    assert any("주간 리포트" in m["body"] for m in thread)


def test_send_report_uses_the_trainers_own_edit_when_given(client):
    token = _trainer_token(client)
    r = client.post(
        "/v1/trainer/clients/user-jisu/report/send",
        json={"message": "이번 주 컨디션 어땠어요? 다음 주 계획 같이 봐요."},
        headers=_auth(token),
    )
    assert r.status_code == 201, r.text
    assert r.json()["body"] == "이번 주 컨디션 어땠어요? 다음 주 계획 같이 봐요."


# ---- 프로필 수정 ----

def test_put_me_updates_only_the_sent_fields(client):
    token = _trainer_token(client)
    before = client.get("/v1/trainer/me", headers=_auth(token)).json()

    try:
        r = client.put(
            "/v1/trainer/me",
            json={"phone": "010-9999-0000", "career_years": 9},
            headers=_auth(token),
        )
        assert r.status_code == 200, r.text
        body = r.json()
        assert body["phone"] == "010-9999-0000"
        assert body["career"] == "9년"
        # 보내지 않은 값은 그대로 — 부분 수정이 나머지를 지우면 안 된다.
        assert body["specialty"] == before["specialty"]
        assert body["gym"]["name"] == before["gym"]["name"]
    finally:
        # 실패해도 되돌린다 — 오염된 시드는 같은 파일의 뒤 테스트를 연달아
        # 무너뜨린다.
        client.put(
            "/v1/trainer/me",
            json={
                "phone": before["phone"],
                "career_years": int(before["career"].rstrip("년")),
            },
            headers=_auth(token),
        )


def test_put_me_rejects_an_explicit_null(client):
    """NOT NULL 컬럼에 null 을 반영하면 IntegrityError 500 이 된다.
    누락(변경 없음)과 null(잘못된 값)을 구분한다."""
    token = _trainer_token(client)
    r = client.put("/v1/trainer/me", json={"phone": None}, headers=_auth(token))
    assert r.status_code == 422


def test_put_me_replaces_certifications_wholesale(client):
    token = _trainer_token(client)
    before = client.get("/v1/trainer/me", headers=_auth(token)).json()

    try:
        r = client.put(
            "/v1/trainer/me",
            json={"certifications": ["  스포츠 영양사  ", "", "  "]},
            headers=_auth(token),
        )
        assert r.status_code == 200, r.text
        # 공백만 있는 항목은 버리고 나머지는 trim.
        assert r.json()["certifications"] == ["스포츠 영양사"]
    finally:
        client.put(
            "/v1/trainer/me",
            json={"certifications": before["certifications"]},
            headers=_auth(token),
        )


def test_put_me_with_no_fields_is_rejected(client):
    """빈 본문을 200 으로 돌려주면 클라이언트가 저장됐다고 오해한다."""
    token = _trainer_token(client)
    r = client.put("/v1/trainer/me", json={}, headers=_auth(token))
    assert r.status_code == 400


# ---- 고객 AI 코칭 ----

def test_client_ai_coach_answers_about_the_member(client):
    token = _trainer_token(client)
    r = client.post(
        "/v1/trainer/clients/user-jisu/ai-coach",
        json={"message": "이번 주 식단에서 뭘 조정하면 좋을까요?"},
        headers=_auth(token),
    )
    # LLM 키가 없어도 검색 기반 폴백이 답을 돌려준다.
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["member_id"] == "user-jisu"
    assert body["reply"]


def test_client_ai_coach_rejects_an_empty_message(client):
    token = _trainer_token(client)
    r = client.post(
        "/v1/trainer/clients/user-jisu/ai-coach",
        json={"message": "   "},
        headers=_auth(token),
    )
    assert r.status_code == 400


def test_client_ai_coach_of_someone_elses_client_is_404(client):
    """남의 고객이면 존재조차 드러내지 않는다(권한 경계)."""
    token = _trainer_token(client)
    r = client.post(
        "/v1/trainer/clients/user-nobody/ai-coach",
        json={"message": "안녕하세요"},
        headers=_auth(token),
    )
    assert r.status_code == 404


# ---- 비밀번호 변경 ----

def test_password_change_requires_the_current_password(client):
    """토큰만으로 비밀번호를 바꿀 수 있으면 탈취 = 계정 탈취가 된다."""
    token = _trainer_token(client)
    r = client.post(
        "/v1/trainer/me/password",
        json={"current_password": "wrong-password", "new_password": "newpass123"},
        headers=_auth(token),
    )
    # 401 이 아니라 400 — 토큰은 유효하므로 클라이언트가 로그아웃으로 오인하면 안 된다.
    assert r.status_code == 400, r.text
    assert "현재 비밀번호" in r.json()["detail"]


def test_password_change_rejects_the_same_password(client):
    token = _trainer_token(client)
    r = client.post(
        "/v1/trainer/me/password",
        json={"current_password": "oncare123", "new_password": "oncare123"},
        headers=_auth(token),
    )
    assert r.status_code == 400, r.text


def test_password_change_rejects_a_short_password(client):
    token = _trainer_token(client)
    r = client.post(
        "/v1/trainer/me/password",
        json={"current_password": "oncare123", "new_password": "short"},
        headers=_auth(token),
    )
    assert r.status_code == 422


def test_password_change_takes_effect_and_can_be_reverted(client):
    token = _trainer_token(client)
    r = client.post(
        "/v1/trainer/me/password",
        json={"current_password": "oncare123", "new_password": "oncare45678"},
        headers=_auth(token),
    )
    assert r.status_code == 200, r.text

    try:
        # 옛 비밀번호로는 더 이상 로그인되지 않고, 새 비밀번호로는 된다.
        old = client.post(
            "/v1/auth/login",
            data={"username": "trainer@oncare.com", "password": "oncare123"},
        )
        assert old.status_code == 401
        new = client.post(
            "/v1/auth/login",
            data={"username": "trainer@oncare.com", "password": "oncare45678"},
        )
        assert new.status_code == 200, new.text
    finally:
        # 반드시 되돌린다 — 시드 비밀번호가 남으면 이 파일의 다른 테스트가
        # _trainer_token() 에서 KeyError 로 줄줄이 죽는다. 토큰도 여기서
        # 새로 얻는다(위 로그인이 실패했을 수 있다).
        recovered = client.post(
            "/v1/auth/login",
            data={"username": "trainer@oncare.com", "password": "oncare45678"},
        )
        if recovered.status_code == 200:
            revert = client.post(
                "/v1/trainer/me/password",
                json={
                    "current_password": "oncare45678",
                    "new_password": "oncare123",
                },
                headers=_auth(recovered.json()["access_token"]),
            )
            assert revert.status_code == 200, revert.text


def test_password_change_needs_a_trainer_account(client):
    """회원 계정은 /trainer/* 전체가 403 이다."""
    email = f"member-{uuid4().hex[:8]}@oncare.com"
    client.post("/v1/auth/register", json={"email": email, "password": "pw!", "name": "u"})
    member = client.post(
        "/v1/auth/login", data={"username": email, "password": "pw!"}
    ).json()["access_token"]
    r = client.post(
        "/v1/trainer/me/password",
        json={"current_password": "pw!", "new_password": "newpass123"},
        headers=_auth(member),
    )
    assert r.status_code == 403


# ---- 알림 수신 설정 (#379) ----

def test_settings_defaults_come_from_the_server(client):
    """클라이언트마다 기본값을 들고 있으면 기기별로 갈라진다."""
    token = _trainer_token(client)
    r = client.get("/v1/trainer/me/settings", headers=_auth(token))
    assert r.status_code == 200, r.text
    body = r.json()
    assert set(body) == {
        "notify_new_message", "notify_session_reminder", "reminder_lead_minutes",
    }
    assert body["notify_new_message"] is True
    assert body["notify_session_reminder"] is True
    assert body["reminder_lead_minutes"] == 30


def test_settings_update_persists_and_is_partial(client):
    token = _trainer_token(client)
    before = client.get("/v1/trainer/me/settings", headers=_auth(token)).json()
    try:
        r = client.put(
            "/v1/trainer/me/settings",
            json={"notify_new_message": False},
            headers=_auth(token),
        )
        assert r.status_code == 200, r.text
        assert r.json()["notify_new_message"] is False
        # 보내지 않은 값은 그대로.
        assert r.json()["reminder_lead_minutes"] == before["reminder_lead_minutes"]

        # 다시 읽어도 유지된다(기기가 아니라 계정에 붙어 있다).
        again = client.get("/v1/trainer/me/settings", headers=_auth(token)).json()
        assert again["notify_new_message"] is False
    finally:
        client.put("/v1/trainer/me/settings", json=before, headers=_auth(token))


def test_settings_reject_a_lead_time_outside_the_options(client):
    token = _trainer_token(client)
    r = client.put(
        "/v1/trainer/me/settings",
        json={"reminder_lead_minutes": 45},
        headers=_auth(token),
    )
    assert r.status_code == 422


def test_settings_reject_an_explicit_null(client):
    """명시적 null 은 422 — NOT NULL 컬럼에 그대로 넣으면 500 이 난다.

    누락(변경 없음)과 null(잘못된 값)을 구분한다. TrainerMeUpdate ·
    ScheduleUpdateRequest 와 같은 규약.
    """
    token = _trainer_token(client)
    for payload in (
        {"notify_new_message": None},
        {"notify_session_reminder": None},
        {"reminder_lead_minutes": None},
    ):
        r = client.put("/v1/trainer/me/settings", json=payload, headers=_auth(token))
        assert r.status_code == 422, (payload, r.status_code, r.text)


def test_settings_update_with_no_fields_is_rejected(client):
    token = _trainer_token(client)
    r = client.put("/v1/trainer/me/settings", json={}, headers=_auth(token))
    assert r.status_code == 400


def test_settings_need_a_trainer_account(client):
    email = f"member-{uuid4().hex[:8]}@oncare.com"
    client.post("/v1/auth/register", json={"email": email, "password": "pw!", "name": "u"})
    member = client.post(
        "/v1/auth/login", data={"username": email, "password": "pw!"}
    ).json()["access_token"]
    assert client.get("/v1/trainer/me/settings", headers=_auth(member)).status_code == 403
