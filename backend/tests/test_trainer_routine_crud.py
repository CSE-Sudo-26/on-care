"""배정한 루틴 수정·삭제. (#504) DB 필요.

전에는 배정만 되고 고칠 수 없었다. 이름이나 시간을 잘못 넣어도, 회원 상태가
바뀌어 루틴을 물려야 해도 방법이 없어 트레이너는 잘못된 루틴을 남겨둔 채 새 것을
하나 더 배정했고, 회원 앱에는 둘 다 그대로 보였다.
"""
from __future__ import annotations

from uuid import uuid4

import pytest


def _tok(client) -> str:
    return client.post(
        "/v1/auth/login",
        data={"username": "trainer@oncare.com", "password": "oncare123"},
    ).json()["access_token"]


def _h(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


MEMBER = "user-jisu"


@pytest.fixture()
def routine(client):
    """루틴 하나를 배정하고, 테스트가 끝나면 지운다."""
    token = _tok(client)
    created = client.post(
        f"/v1/trainer/clients/{MEMBER}/routines",
        headers=_h(token),
        json={
            "name": f"테스트 루틴 {uuid4().hex[:6]}",
            "minutes": 30,
            "type": "근력",
            "reason": "처음 배정",
        },
    )
    assert created.status_code == 201, created.text
    row = created.json()
    yield token, row
    client.delete(
        f"/v1/trainer/clients/{MEMBER}/routines/{row['id']}", headers=_h(token)
    )


def test_update_changes_only_the_sent_fields(client, routine):
    token, row = routine

    updated = client.put(
        f"/v1/trainer/clients/{MEMBER}/routines/{row['id']}",
        headers=_h(token),
        json={"minutes": 45},
    )

    assert updated.status_code == 200, updated.text
    assert updated.json()["minutes"] == 45
    # 보내지 않은 필드는 그대로다 — 부분 수정이 전체 덮어쓰기가 되면 안 된다.
    assert updated.json()["name"] == row["name"]
    assert updated.json()["type"] == row["type"]
    assert updated.json()["reason"] == row["reason"]


def test_update_is_visible_in_the_list(client, routine):
    token, row = routine
    new_name = f"고친 이름 {uuid4().hex[:6]}"

    client.put(
        f"/v1/trainer/clients/{MEMBER}/routines/{row['id']}",
        headers=_h(token),
        json={"name": new_name},
    )

    listed = client.get(
        f"/v1/trainer/clients/{MEMBER}/routines", headers=_h(token)
    ).json()
    assert next(r for r in listed if r["id"] == row["id"])["name"] == new_name


def test_delete_removes_it_from_the_list(client, routine):
    token, row = routine

    deleted = client.delete(
        f"/v1/trainer/clients/{MEMBER}/routines/{row['id']}", headers=_h(token)
    )
    assert deleted.status_code == 200, deleted.text

    listed = client.get(
        f"/v1/trainer/clients/{MEMBER}/routines", headers=_h(token)
    ).json()
    assert all(r["id"] != row["id"] for r in listed)

    # 두 번째 삭제는 404 — 이미 없는 것을 지웠다고 하면 안 된다.
    assert (
        client.delete(
            f"/v1/trainer/clients/{MEMBER}/routines/{row['id']}",
            headers=_h(token),
        ).status_code
        == 404
    )


def test_delete_keeps_the_order_of_the_rest(client):
    """중간을 지워도 남은 루틴의 순서가 흔들리지 않는다."""
    token = _tok(client)
    ids = []
    for i in range(3):
        created = client.post(
            f"/v1/trainer/clients/{MEMBER}/routines",
            headers=_h(token),
            json={
                "name": f"순서 {i} {uuid4().hex[:4]}",
                "minutes": 20,
                "type": "근력",
            },
        )
        ids.append(created.json()["id"])
    try:
        before = [
            r["id"]
            for r in client.get(
                f"/v1/trainer/clients/{MEMBER}/routines", headers=_h(token)
            ).json()
            if r["id"] in ids
        ]
        assert before == ids

        client.delete(
            f"/v1/trainer/clients/{MEMBER}/routines/{ids[1]}", headers=_h(token)
        )

        after = [
            r["id"]
            for r in client.get(
                f"/v1/trainer/clients/{MEMBER}/routines", headers=_h(token)
            ).json()
            if r["id"] in ids
        ]
        assert after == [ids[0], ids[2]]
    finally:
        for routine_id in ids:
            client.delete(
                f"/v1/trainer/clients/{MEMBER}/routines/{routine_id}",
                headers=_h(token),
            )


def test_unknown_routine_is_404(client):
    token = _tok(client)
    assert (
        client.put(
            f"/v1/trainer/clients/{MEMBER}/routines/rt-nope",
            headers=_h(token),
            json={"minutes": 10},
        ).status_code
        == 404
    )


def test_another_trainers_routine_is_404(client, db_session, routine):
    """남의 배정은 고칠 수도 지울 수도 없고, 존재도 드러나지 않는다."""
    from app.models import models

    token, row = routine
    # 같은 회원의 루틴이지만 다른 트레이너가 배정한 것으로 바꾼다.
    stored = db_session.get(models.TrainerRoutine, row["id"])
    original = stored.trainer_id
    stored.trainer_id = "trainer-park"
    db_session.commit()
    try:
        assert (
            client.put(
                f"/v1/trainer/clients/{MEMBER}/routines/{row['id']}",
                headers=_h(token),
                json={"minutes": 10},
            ).status_code
            == 404
        )
        assert (
            client.delete(
                f"/v1/trainer/clients/{MEMBER}/routines/{row['id']}",
                headers=_h(token),
            ).status_code
            == 404
        )
    finally:
        stored.trainer_id = original
        db_session.commit()


def test_someone_elses_client_is_404(client, routine):
    """담당이 아닌 회원의 루틴은 건드릴 수 없다."""
    token, row = routine
    assert (
        client.put(
            f"/v1/trainer/clients/user-nobody/routines/{row['id']}",
            headers=_h(token),
            json={"minutes": 10},
        ).status_code
        == 404
    )


def test_empty_update_is_400(client, routine):
    token, row = routine
    assert (
        client.put(
            f"/v1/trainer/clients/{MEMBER}/routines/{row['id']}",
            headers=_h(token),
            json={},
        ).status_code
        == 400
    )


@pytest.mark.parametrize("field", ["name", "minutes", "type", "reason"])
def test_update_rejects_explicit_null(client, routine, field):
    """명시적 null 은 422 — 이 저장소의 부분 수정 규약(#495)."""
    token, row = routine
    res = client.put(
        f"/v1/trainer/clients/{MEMBER}/routines/{row['id']}",
        headers=_h(token),
        json={field: None},
    )
    assert res.status_code == 422, res.text


def test_update_rejects_out_of_range_values(client, routine):
    token, row = routine
    assert (
        client.put(
            f"/v1/trainer/clients/{MEMBER}/routines/{row['id']}",
            headers=_h(token),
            json={"minutes": 9999},
        ).status_code
        == 422
    )
    assert (
        client.put(
            f"/v1/trainer/clients/{MEMBER}/routines/{row['id']}",
            headers=_h(token),
            json={"type": "수영"},
        ).status_code
        == 422
    )
    # 공백만 있는 이름은 trim 후 400.
    assert (
        client.put(
            f"/v1/trainer/clients/{MEMBER}/routines/{row['id']}",
            headers=_h(token),
            json={"name": "   "},
        ).status_code
        in (400, 422)
    )


def test_editing_does_not_notify_the_member(client, db_session, routine):
    """정정 알림까지 겹치면 회원 알림함이 같은 루틴으로 채워진다."""
    from sqlalchemy import select

    from app.models import models

    token, row = routine
    before = db_session.scalars(
        select(models.Notification).where(models.Notification.user_id == MEMBER)
    ).all()

    client.put(
        f"/v1/trainer/clients/{MEMBER}/routines/{row['id']}",
        headers=_h(token),
        json={"minutes": 50},
    )
    client.delete(
        f"/v1/trainer/clients/{MEMBER}/routines/{row['id']}", headers=_h(token)
    )

    db_session.expire_all()
    after = db_session.scalars(
        select(models.Notification).where(models.Notification.user_id == MEMBER)
    ).all()
    assert len(after) == len(before)
