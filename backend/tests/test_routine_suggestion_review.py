"""AI 개인운동 제안의 검토·승인·거절. (#790) DB 필요.

핵심 계약은 하나다 — **트레이너가 승인하기 전에는 회원에게 닿지 않는다.**
AI 가 만든 후보가 곧바로 배정되면, 트레이너가 알고 있는 부상·회복 상태가
반영되지 않은 운동이 회원 화면에 뜬다.
"""
from __future__ import annotations

from uuid import uuid4

import pytest


def _trainer_token(client) -> str:
    return client.post(
        "/v1/auth/login",
        data={"username": "trainer@oncare.com", "password": "oncare123"},
    ).json()["access_token"]


def _member_token(client) -> str:
    return client.post(
        "/v1/auth/login",
        data={"username": "jisu@oncare.com", "password": "oncare123"},
    ).json()["access_token"]


def _h(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


MEMBER = "user-jisu"


@pytest.fixture()
def suggestion(client):
    """검토 대기 제안 하나. 테스트가 끝나면 지운다."""
    token = _trainer_token(client)
    created = client.post(
        f"/v1/trainer/clients/{MEMBER}/routine-suggestions",
        headers=_h(token),
        json={
            "name": f"어깨 스트레칭 {uuid4().hex[:6]}",
            "minutes": 8,
            "type": "스트레칭",
            "reason": "최근 PT 피드백 반영",
        },
    )
    assert created.status_code == 201, created.text
    row = created.json()
    yield token, row
    client.delete(
        f"/v1/trainer/clients/{MEMBER}/routines/{row['id']}", headers=_h(token)
    )


def test_pending_suggestion_is_invisible_to_the_member(client, suggestion):
    _, row = suggestion

    mine = client.get("/v1/me/coach/routines", headers=_h(_member_token(client)))

    assert mine.status_code == 200, mine.text
    assert row["id"] not in {r["id"] for r in mine.json()}


def test_pending_suggestion_is_not_in_the_assigned_list(client, suggestion):
    token, row = suggestion

    assigned = client.get(
        f"/v1/trainer/clients/{MEMBER}/routines", headers=_h(token)
    )

    # 배정 목록은 '이미 회원이 보는 것'이다. 아직 검토 전인 후보가 섞이면
    # 어느 쪽이 회원에게 갔는지 알 수 없다.
    assert row["id"] not in {r["id"] for r in assigned.json()}


def test_suggestion_shows_up_in_the_review_list(client, suggestion):
    token, row = suggestion

    pending = client.get(
        f"/v1/trainer/clients/{MEMBER}/routine-suggestions", headers=_h(token)
    )

    assert row["id"] in {r["id"] for r in pending.json()}


def test_approve_makes_it_visible_to_the_member(client, suggestion):
    token, row = suggestion

    approved = client.post(
        f"/v1/trainer/routine-suggestions/{row['id']}/approve",
        headers=_h(token),
        json={},
    )
    assert approved.status_code == 200, approved.text

    mine = client.get("/v1/me/coach/routines", headers=_h(_member_token(client)))
    assert row["id"] in {r["id"] for r in mine.json()}


def test_approve_with_edits_saves_the_edited_values(client, suggestion):
    token, row = suggestion

    approved = client.post(
        f"/v1/trainer/routine-suggestions/{row['id']}/approve",
        headers=_h(token),
        json={"minutes": 10, "reason": "오른쪽 어깨 통증 시 중단"},
    )

    assert approved.status_code == 200, approved.text
    body = approved.json()
    assert body["minutes"] == 10
    assert body["reason"] == "오른쪽 어깨 통증 시 중단"
    # 주지 않은 값은 그대로다.
    assert body["name"] == row["name"]


def test_dismiss_keeps_it_away_from_the_member(client, suggestion):
    token, row = suggestion

    dismissed = client.post(
        f"/v1/trainer/routine-suggestions/{row['id']}/dismiss", headers=_h(token)
    )
    assert dismissed.status_code == 200, dismissed.text

    mine = client.get("/v1/me/coach/routines", headers=_h(_member_token(client)))
    assert row["id"] not in {r["id"] for r in mine.json()}
    pending = client.get(
        f"/v1/trainer/clients/{MEMBER}/routine-suggestions", headers=_h(token)
    )
    assert row["id"] not in {r["id"] for r in pending.json()}


def test_second_review_is_rejected_rather_than_silently_repeated(client, suggestion):
    token, row = suggestion

    first = client.post(
        f"/v1/trainer/routine-suggestions/{row['id']}/approve",
        headers=_h(token),
        json={},
    )
    assert first.status_code == 200

    second = client.post(
        f"/v1/trainer/routine-suggestions/{row['id']}/approve",
        headers=_h(token),
        json={},
    )

    # 404 로 뭉개면 트레이너가 "사라졌다" 로 읽는다. 실제로는 이미 반영돼 있다.
    assert second.status_code == 409, second.text


def test_dismissed_suggestion_cannot_be_approved_afterwards(client, suggestion):
    token, row = suggestion

    client.post(
        f"/v1/trainer/routine-suggestions/{row['id']}/dismiss", headers=_h(token)
    )
    late = client.post(
        f"/v1/trainer/routine-suggestions/{row['id']}/approve",
        headers=_h(token),
        json={},
    )

    assert late.status_code == 409, late.text


def test_member_cannot_complete_a_pending_suggestion(client, suggestion):
    _, row = suggestion

    done = client.post(
        f"/v1/me/coach/routines/{row['id']}/complete",
        headers=_h(_member_token(client)),
        json={"minutes": 8, "intensity": "light", "member_note": ""},
    )

    # 조회에서만 거르면 id 를 알아낸 호출이 한 경로 남는다.
    assert done.status_code == 404, done.text


def test_same_client_request_id_does_not_create_two_suggestions(client):
    token = _trainer_token(client)
    key = uuid4().hex
    payload = {
        "name": f"저강도 걷기 {key[:6]}",
        "minutes": 20,
        "type": "유산소",
        "reason": "회복",
        "client_request_id": key,
    }

    first = client.post(
        f"/v1/trainer/clients/{MEMBER}/routine-suggestions",
        headers=_h(token),
        json=payload,
    )
    second = client.post(
        f"/v1/trainer/clients/{MEMBER}/routine-suggestions",
        headers=_h(token),
        json=payload,
    )

    assert first.status_code == 201, first.text
    assert second.json()["id"] == first.json()["id"]

    client.delete(
        f"/v1/trainer/clients/{MEMBER}/routines/{first.json()['id']}",
        headers=_h(token),
    )


def test_existing_assignments_stay_visible(client):
    """상태 칼럼이 생겨도 예전처럼 배정한 루틴은 그대로 회원에게 간다."""
    token = _trainer_token(client)
    created = client.post(
        f"/v1/trainer/clients/{MEMBER}/routines",
        headers=_h(token),
        json={
            "name": f"직접 배정 {uuid4().hex[:6]}",
            "minutes": 30,
            "type": "근력",
            "reason": "직접 배정",
        },
    )
    assert created.status_code == 201, created.text
    row = created.json()

    mine = client.get("/v1/me/coach/routines", headers=_h(_member_token(client)))
    assert row["id"] in {r["id"] for r in mine.json()}

    client.delete(
        f"/v1/trainer/clients/{MEMBER}/routines/{row['id']}", headers=_h(token)
    )
