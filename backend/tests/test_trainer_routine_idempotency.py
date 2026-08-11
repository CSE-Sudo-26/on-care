"""루틴 배정 멱등성 (#581). DB 필요.

배정은 멱등하지 않아 매 요청이 새 행을 만들었다. 전송 중 네트워크가 끊기면
서버는 이미 커밋했는데 클라이언트는 실패로 처리하는 구간이 생기고, 트레이너가
결과를 확인하지 않고 다시 보내면 회원에게 같은 루틴이 두 번 배정된다.

전송 시도당 멱등키를 받아 같은 키의 재요청은 새로 만들지 않고 먼저 저장된
배정을 그대로 돌려준다.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from uuid import uuid4

import pytest
from sqlalchemy import select

from app.models.models import TrainerRoutine

MEMBER = "user-jisu"
TRAINER = "trainer-demo"


def _tok(client) -> str:
    return client.post(
        "/v1/auth/login",
        data={"username": "trainer@oncare.com", "password": "oncare123"},
    ).json()["access_token"]


def _h(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _body(key: str | None, name: str = "저강도 걷기") -> dict:
    body: dict = {"name": name, "minutes": 30, "type": "유산소", "reason": "혈압 관리"}
    if key is not None:
        body["client_request_id"] = key
    return body


@pytest.fixture()
def cleanup_routines(client, db_session):
    """테스트가 만든 루틴을 지운다.

    지우지 않으면 이 회원의 루틴이 실행마다 쌓여 다른 테스트의 목록 단언을
    흔든다(#558 과 같은 누적 취약성).
    """
    created: list[str] = []
    yield created
    token = _tok(client)
    for routine_id in created:
        client.delete(
            f"/v1/trainer/clients/{MEMBER}/routines/{routine_id}", headers=_h(token)
        )


def _rows_for(db_session, key: str) -> list[TrainerRoutine]:
    db_session.expire_all()
    return list(
        db_session.scalars(
            select(TrainerRoutine).where(
                TrainerRoutine.trainer_id == TRAINER,
                TrainerRoutine.member_id == MEMBER,
                TrainerRoutine.client_request_id == key,
            )
        ).all()
    )


def test_same_key_assigns_only_once(client, db_session, cleanup_routines):
    """같은 키로 2회 호출 → 루틴은 1건, 두 응답은 같은 배정을 가리킨다."""
    token = _tok(client)
    key = f"req-{uuid4().hex[:12]}"

    first = client.post(
        f"/v1/trainer/clients/{MEMBER}/routines", json=_body(key), headers=_h(token)
    )
    assert first.status_code == 201, first.text
    cleanup_routines.append(first.json()["id"])

    second = client.post(
        f"/v1/trainer/clients/{MEMBER}/routines", json=_body(key), headers=_h(token)
    )
    assert second.status_code == 201, second.text

    # 같은 배정을 돌려준다 — 클라이언트는 재시도해도 같은 결과를 본다.
    assert second.json()["id"] == first.json()["id"]
    assert len(_rows_for(db_session, key)) == 1


def test_retry_after_a_lost_response_does_not_duplicate(
    client, db_session, cleanup_routines
):
    """응답을 못 받은 트레이너가 같은 키로 재전송해도 회원에게 1건만 배정된다.

    이것이 이 이슈의 실제 시나리오다 — 서버는 커밋했는데 클라이언트는 실패로
    본 상태에서의 재시도.
    """
    token = _tok(client)
    key = f"req-{uuid4().hex[:12]}"

    sent = client.post(
        f"/v1/trainer/clients/{MEMBER}/routines", json=_body(key), headers=_h(token)
    )
    assert sent.status_code == 201
    cleanup_routines.append(sent.json()["id"])

    # 클라이언트가 응답을 잃고 같은 키로 두 번 더 재시도.
    for _ in range(2):
        again = client.post(
            f"/v1/trainer/clients/{MEMBER}/routines", json=_body(key), headers=_h(token)
        )
        assert again.status_code == 201
        assert again.json()["id"] == sent.json()["id"]

    assert len(_rows_for(db_session, key)) == 1

    # 회원 쪽 목록에도 하나만 보인다.
    listed = client.get(
        f"/v1/trainer/clients/{MEMBER}/routines", headers=_h(token)
    ).json()
    assert [r["id"] for r in listed].count(sent.json()["id"]) == 1


def test_different_keys_create_separate_assignments(
    client, db_session, cleanup_routines
):
    """키가 다르면 별개의 배정이다 — 멱등성이 정상 배정을 막지 않는다."""
    token = _tok(client)
    first_key = f"req-{uuid4().hex[:12]}"
    second_key = f"req-{uuid4().hex[:12]}"

    first = client.post(
        f"/v1/trainer/clients/{MEMBER}/routines",
        json=_body(first_key, name="아침 걷기"),
        headers=_h(token),
    )
    second = client.post(
        f"/v1/trainer/clients/{MEMBER}/routines",
        json=_body(second_key, name="저녁 스트레칭"),
        headers=_h(token),
    )
    assert first.status_code == 201 and second.status_code == 201
    cleanup_routines.extend([first.json()["id"], second.json()["id"]])

    assert first.json()["id"] != second.json()["id"]
    assert len(_rows_for(db_session, first_key)) == 1
    assert len(_rows_for(db_session, second_key)) == 1


def test_requests_without_a_key_keep_the_previous_behaviour(
    client, cleanup_routines
):
    """키가 없으면 기존대로 매 요청이 새 배정이다 — 구버전 앱이 깨지지 않는다."""
    token = _tok(client)

    ids = []
    for _ in range(2):
        response = client.post(
            f"/v1/trainer/clients/{MEMBER}/routines",
            json=_body(None),
            headers=_h(token),
        )
        assert response.status_code == 201, response.text
        ids.append(response.json()["id"])
    cleanup_routines.extend(ids)

    assert ids[0] != ids[1], "키 없는 요청까지 합쳐지면 정상 배정이 막힌다"


def test_concurrent_same_key_requests_create_one_assignment(
    client, db_session, cleanup_routines
):
    """같은 키의 동시 요청 둘이 나란히 들어와도 1건만 남는다.

    조회-후-삽입 사이를 둘이 함께 지나가면 유니크 제약이 한쪽을 막는데, 그때
    500 이 아니라 이긴 행을 돌려줘야 한다.
    """
    token = _tok(client)
    key = f"req-{uuid4().hex[:12]}"
    barrier = Barrier(2)

    def send():
        barrier.wait()
        return client.post(
            f"/v1/trainer/clients/{MEMBER}/routines",
            json=_body(key),
            headers=_h(token),
        )

    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = [f.result(timeout=15) for f in [pool.submit(send) for _ in range(2)]]

    assert [r.status_code for r in responses] == [201, 201], [r.text for r in responses]
    ids = {r.json()["id"] for r in responses}
    assert len(ids) == 1, "동시 요청이 서로 다른 배정을 만들었다"
    cleanup_routines.extend(ids)

    assert len(_rows_for(db_session, key)) == 1
