"""트레이너별 프로그램 템플릿 CRUD. (#920)

가장 중요하게 보는 것은 **시작 구성이 저장된 행이 아니라는 점**이다. 저장된
템플릿이 없는 트레이너에게만 보이고, 자기 것이 하나라도 생기면 사라진다 —
그래야 "지웠는데 되살아난다" 가 생기지 않는다.

DB 가 필요하므로 로컬에서는 skip 되고 CI(Postgres) 에서 실행된다.
"""
from __future__ import annotations

from uuid import uuid4

import pytest

from app.core.security import hash_password
from app.models.models import TrainerProfile, TrainerProgramTemplate, User
from app.services import trainer_program_template_service as service

EMAIL_PREFIX = "template-test-"
PASSWORD = "template-pw-1234"


@pytest.fixture(autouse=True)
def _cleanup(db_session):
    yield
    db_session.rollback()
    user_ids = [
        row[0]
        for row in db_session.query(User.id)
        .filter(User.email.like(f"{EMAIL_PREFIX}%"))
        .all()
    ]
    if user_ids:
        db_session.query(TrainerProgramTemplate).filter(
            TrainerProgramTemplate.trainer_id.in_(user_ids)
        ).delete(synchronize_session=False)
        db_session.query(TrainerProfile).filter(
            TrainerProfile.trainer_id.in_(user_ids)
        ).delete(synchronize_session=False)
        db_session.query(User).filter(User.id.in_(user_ids)).delete(
            synchronize_session=False
        )
    db_session.commit()


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _trainer(client, db_session) -> tuple[User, str]:
    suffix = uuid4().hex[:10]
    email = f"{EMAIL_PREFIX}trainer-{suffix}@oncare.com"
    trainer = User(
        id=f"template-trainer-{suffix}",
        email=email,
        name="템플릿 테스트 트레이너",
        hashed_password=hash_password(PASSWORD),
        role="trainer",
        is_active=True,
    )
    db_session.add(trainer)
    db_session.commit()
    response = client.post(
        "/v1/auth/login", data={"username": email, "password": PASSWORD}
    )
    assert response.status_code == 200, response.text
    return trainer, response.json()["access_token"]


def _create(client, token: str, name: str = "내 블록") -> dict:
    response = client.post(
        "/v1/trainer/program-templates",
        json={
            "name": name,
            "goal": "체중 감량 · 초급",
            "exercises": [
                {"name": "인터벌 유산소", "minutes": 20, "type": "유산소"},
                {"name": "코어 서킷", "minutes": 10, "type": "근력"},
            ],
        },
        headers=_auth(token),
    )
    assert response.status_code == 201, response.text
    return response.json()


def test_a_new_trainer_starts_with_the_bundled_set(client, db_session):
    _, token = _trainer(client, db_session)

    response = client.get("/v1/trainer/program-templates", headers=_auth(token))

    assert response.status_code == 200, response.text
    rows = response.json()
    assert [row["name"] for row in rows] == [
        "혈압 관리 기본",
        "체중 감량 순환",
        "하체 근력 A",
    ]
    # 시작 구성은 저장된 행이 아니다 — id 로 그것을 알 수 있어야 화면이
    # 지우기·고치기를 내밀지 않는다.
    assert all(row["id"].startswith(service.STARTER_PREFIX) for row in rows)
    assert (
        db_session.query(TrainerProgramTemplate)
        .filter(TrainerProgramTemplate.trainer_id.isnot(None))
        .filter(TrainerProgramTemplate.id.like("starter%"))
        .count()
        == 0
    )


def test_saving_one_template_replaces_the_starter_set(client, db_session):
    _, token = _trainer(client, db_session)

    _create(client, token)

    rows = client.get(
        "/v1/trainer/program-templates", headers=_auth(token)
    ).json()
    assert [row["name"] for row in rows] == ["내 블록"]


def test_a_saved_template_keeps_its_exercises_in_order(client, db_session):
    _, token = _trainer(client, db_session)

    created = _create(client, token)

    assert [item["name"] for item in created["exercises"]] == [
        "인터벌 유산소",
        "코어 서킷",
    ]
    assert created["exercises"][0]["type"] == "유산소"


def test_editing_replaces_the_exercise_list_wholesale(client, db_session):
    _, token = _trainer(client, db_session)
    created = _create(client, token)

    response = client.put(
        f"/v1/trainer/program-templates/{created['id']}",
        json={
            "name": "고친 블록",
            "exercises": [{"name": "걷기", "minutes": 30, "type": "걷기"}],
        },
        headers=_auth(token),
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["name"] == "고친 블록"
    assert [item["name"] for item in body["exercises"]] == ["걷기"]
    # 보내지 않은 필드는 그대로다.
    assert body["goal"] == "체중 감량 · 초급"


def test_deleting_the_last_template_brings_the_starter_set_back(client, db_session):
    """지우면 '아무것도 저장하지 않은 트레이너' 로 돌아간다.

    시작 구성이 되살아나는 것이 아니라, 애초에 저장된 적 없는 값이라 다시
    보이는 것이다. 빈 화면으로 두면 이 기능이 무엇인지 알 수 없다.
    """
    _, token = _trainer(client, db_session)
    created = _create(client, token)

    deleted = client.delete(
        f"/v1/trainer/program-templates/{created['id']}", headers=_auth(token)
    )

    assert deleted.status_code == 200, deleted.text
    rows = client.get(
        "/v1/trainer/program-templates", headers=_auth(token)
    ).json()
    assert all(row["id"].startswith(service.STARTER_PREFIX) for row in rows)


def test_templates_are_private_to_their_trainer(client, db_session):
    _, owner_token = _trainer(client, db_session)
    _, stranger_token = _trainer(client, db_session)
    created = _create(client, owner_token, name="남의 블록")

    # 남의 목록에는 보이지 않고,
    rows = client.get(
        "/v1/trainer/program-templates", headers=_auth(stranger_token)
    ).json()
    assert all(row["name"] != "남의 블록" for row in rows)

    # 직접 집어도 존재조차 드러내지 않는다.
    edited = client.put(
        f"/v1/trainer/program-templates/{created['id']}",
        json={"name": "가로채기"},
        headers=_auth(stranger_token),
    )
    assert edited.status_code == 404
    removed = client.delete(
        f"/v1/trainer/program-templates/{created['id']}",
        headers=_auth(stranger_token),
    )
    assert removed.status_code == 404


def test_a_starter_id_cannot_be_edited(client, db_session):
    """시작 구성은 저장된 행이 아니라 고칠 대상이 없다.

    화면은 '고치기' 대신 '내 템플릿으로 저장' 을 내밀지만, 그 규약을 서버가
    한 번 더 지킨다.
    """
    _, token = _trainer(client, db_session)

    response = client.put(
        f"/v1/trainer/program-templates/{service.STARTER_PREFIX}0",
        json={"name": "고쳐보기"},
        headers=_auth(token),
    )

    assert response.status_code == 404


def test_a_template_needs_at_least_one_exercise(client, db_session):
    _, token = _trainer(client, db_session)

    response = client.post(
        "/v1/trainer/program-templates",
        json={"name": "빈 블록", "goal": "", "exercises": []},
        headers=_auth(token),
    )

    assert response.status_code == 422


def test_an_unknown_exercise_type_is_refused(client, db_session):
    _, token = _trainer(client, db_session)

    response = client.post(
        "/v1/trainer/program-templates",
        json={
            "name": "이상한 블록",
            "exercises": [{"name": "무언가", "minutes": 10, "type": "필라테스"}],
        },
        headers=_auth(token),
    )

    assert response.status_code == 422


def test_the_save_limit_is_enforced(client, db_session):
    trainer, token = _trainer(client, db_session)
    for index in range(service.TEMPLATE_LIMIT):
        db_session.add(
            TrainerProgramTemplate(
                id=f"tpl-limit-{index}-{uuid4().hex[:6]}",
                trainer_id=trainer.id,
                name=f"블록 {index}",
                goal="",
                exercises_json='[{"name": "걷기", "minutes": 10, "type": "걷기"}]',
            )
        )
    db_session.commit()

    response = client.post(
        "/v1/trainer/program-templates",
        json={
            "name": "하나 더",
            "exercises": [{"name": "걷기", "minutes": 10, "type": "걷기"}],
        },
        headers=_auth(token),
    )

    assert response.status_code == 409
