"""담당 트레이너가 없는 회원의 AI 자동 추천. (#782) DB 필요.

예전에는 담당이 없으면 `/me/coach/routines` 가 늘 빈 목록이라, 그 회원은 운동
탭에서 받을 것이 아무것도 없었다. 승인할 사람이 없으므로 추천 범위 자체를
보수적으로 좁혀 내려준다.
"""
from __future__ import annotations

import pytest
from sqlalchemy import select

from app.db.session import SessionLocal
from app.models.models import TrainerClient, TrainerRoutine
from app.services import auto_routine_service


def _token(client, email: str) -> str:
    return client.post(
        "/v1/auth/login",
        data={"username": email, "password": "oncare123"},
    ).json()["access_token"]


def _h(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture()
def lone_member(client):
    """담당 트레이너 링크를 잠시 끊어 '담당 없는 회원' 을 만든다.

    시드 회원을 쓰되 끝나면 되돌린다 — 다른 테스트가 같은 회원의 담당 관계를
    전제하므로 여기서 영구히 끊으면 안 된다.
    """
    member_id = "user-jisu"
    db = SessionLocal()
    links = list(
        db.scalars(
            select(TrainerClient).where(TrainerClient.member_id == member_id)
        ).all()
    )
    saved = [(link.trainer_id, link.active) for link in links]
    for link in links:
        link.active = False
    db.commit()
    db.close()

    yield member_id

    db = SessionLocal()
    for (trainer_id, active), link in zip(
        saved,
        db.scalars(
            select(TrainerClient).where(TrainerClient.member_id == member_id)
        ).all(),
        strict=False,
    ):
        link.active = active
    # 이 테스트가 만든 자동 추천은 남기지 않는다.
    for row in db.scalars(
        select(TrainerRoutine).where(
            TrainerRoutine.member_id == member_id,
            TrainerRoutine.trainer_id.is_(None),
        )
    ).all():
        db.delete(row)
    db.commit()
    db.close()


def test_member_without_a_trainer_now_gets_routines(client, lone_member):
    mine = client.get(
        "/v1/me/coach/routines", headers=_h(_token(client, "jisu@oncare.com"))
    )

    assert mine.status_code == 200, mine.text
    body = mine.json()
    assert body, "담당이 없어도 받을 것이 있어야 한다"
    assert {r["name"] for r in body} == {
        name for name, _, _, _ in auto_routine_service.SAFE_ROUTINES
    }


def test_auto_recommendations_stay_in_a_safe_range(client, lone_member):
    mine = client.get(
        "/v1/me/coach/routines", headers=_h(_token(client, "jisu@oncare.com"))
    )

    # 승인할 사람이 없으므로 범위 자체가 안전장치다. 고강도·고위험 운동을
    # 회원 기록만으로 새로 처방하지 않는다.
    assert {r["type"] for r in mine.json()} <= {"유산소", "스트레칭"}
    assert all(r["minutes"] <= 30 for r in mine.json())
    assert all(r["reason"] for r in mine.json()), "왜 하는지 없이 주지 않는다"


def test_opening_twice_does_not_pile_up_recommendations(client, lone_member):
    token = _token(client, "jisu@oncare.com")

    first = client.get("/v1/me/coach/routines", headers=_h(token)).json()
    second = client.get("/v1/me/coach/routines", headers=_h(token)).json()

    # 화면을 열 때마다 만들면 목록이 하루 만에 길어진다.
    assert [r["id"] for r in first] == [r["id"] for r in second]


def test_auto_recommendation_can_be_completed(client, lone_member):
    token = _token(client, "jisu@oncare.com")
    routine = client.get("/v1/me/coach/routines", headers=_h(token)).json()[0]

    done = client.post(
        f"/v1/me/coach/routines/{routine['id']}/complete",
        headers=_h(token),
        json={"minutes": 15, "intensity": "light", "member_note": ""},
    )

    # 담당이 없다고 완료가 막히면, 화면에 보이는 운동을 수행할 수 없다.
    assert done.status_code == 200, done.text
    assert done.json()["completed"] is True


def test_a_member_with_a_trainer_gets_no_auto_recommendation(client):
    """담당이 있으면 이 경로는 아예 돌지 않는다 — 검토 흐름이 대신한다(#790)."""
    mine = client.get(
        "/v1/me/coach/routines", headers=_h(_token(client, "jisu@oncare.com"))
    ).json()

    safe_names = {name for name, _, _, _ in auto_routine_service.SAFE_ROUTINES}
    assert not (safe_names & {r["name"] for r in mine})
