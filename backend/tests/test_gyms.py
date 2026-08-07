"""헬스장·트레이너 디렉터리 API. (#324)

시드(`seed_gyms.seed_partner_gyms`)가 만든 제휴 헬스장 3곳과 트레이너 1명을 전제로 한다.
"""
from __future__ import annotations

import pytest

PARTNER_IDS = {"gym-oncare-sinchon", "gym-healthmate", "gym-bodyandsoul"}
#: 카카오 Local 에서 발견한 실재 업체 — 제휴는 아니지만 상담 대상이어야 한다.
DISCOVERED_IDS = {"11621774", "1558845892", "328969863", "696444256"}
SEEDED_IDS = PARTNER_IDS | DISCOVERED_IDS
SINCHON = {"lat": 37.5559, "lng": 126.9368}


def test_list_gyms_returns_partner_gyms(client):
    r = client.get("/v1/gyms")
    assert r.status_code == 200, r.text
    ids = {g["id"] for g in r.json()}
    assert PARTNER_IDS <= ids


def test_list_gyms_partner_only_filters(client):
    everything = client.get("/v1/gyms").json()
    partners = client.get("/v1/gyms", params={"partner_only": True}).json()

    assert {g["id"] for g in partners} == PARTNER_IDS
    assert all(g["is_partner"] for g in partners)
    # 기존 데모 시드의 fitness 장소(프로필 없음)는 제휴가 아니라 걸러진다.
    assert len(partners) < len(everything)


def test_list_gyms_sorts_by_distance_when_coordinates_given(client):
    r = client.get("/v1/gyms", params={**SINCHON, "partner_only": True})
    assert r.status_code == 200, r.text
    gyms = r.json()

    distances = [g["distance_km"] for g in gyms]
    assert distances == sorted(distances)
    # 신촌 중심이므로 온케어짐(같은 좌표)이 가장 가깝다.
    assert gyms[0]["id"] == "gym-oncare-sinchon"
    assert gyms[0]["distance_km"] == 0


def test_gyms_without_coordinates_sort_last(client, db_session):
    """좌표를 모르는 헬스장은 distance_km 가 0 이라, 그냥 정렬하면 '가장 가까운 곳'
    으로 맨 앞에 온다."""
    from app.models.models import Place

    db_session.add(
        Place(
            id="gym-no-coords-test",
            name="좌표없는테스트짐",
            category="fitness",
            address="주소 미상",
        )
    )
    db_session.commit()
    try:
        gyms = client.get("/v1/gyms", params=SINCHON).json()
        ids = [g["id"] for g in gyms]
        assert "gym-no-coords-test" in ids
        assert ids[-1] == "gym-no-coords-test", ids
        assert ids[0] == "gym-oncare-sinchon", ids
    finally:
        db_session.query(Place).filter(
            Place.id == "gym-no-coords-test"
        ).delete()
        db_session.commit()


def test_list_gyms_without_coordinates_has_zero_distance(client):
    gyms = client.get("/v1/gyms", params={"partner_only": True}).json()
    # 기준점이 없으면 거리를 지어내지 않는다.
    assert all(g["distance_km"] == 0 for g in gyms)


def test_gym_detail_exposes_profile_fields(client):
    r = client.get("/v1/gyms/gym-oncare-sinchon")
    assert r.status_code == 200, r.text
    gym = r.json()

    assert gym["name"] == "온케어짐 신촌점"
    assert gym["address"] == "서울 서대문구 신촌로 120"
    assert gym["rating"] == 4.7
    assert gym["phone"] == "02-1234-5678"
    assert gym["tags"] == ["다이어트", "재활운동"]
    assert gym["is_partner"] is True
    # 지도 핀을 찍으려면 좌표가 있어야 한다.
    assert gym["lat"] is not None and gym["lng"] is not None


def test_gym_detail_404_for_unknown(client):
    assert client.get("/v1/gyms/no-such-gym").status_code == 404


def test_gym_detail_404_for_non_fitness_place(client):
    # place-1 은 medical 이다 — 헬스장 API 로 새어 나오면 안 된다.
    assert client.get("/v1/gyms/place-1").status_code == 404


def test_gym_trainers_are_scoped_to_that_gym(client):
    r = client.get("/v1/gyms/gym-oncare-sinchon/trainers")
    assert r.status_code == 200, r.text
    trainers = r.json()

    assert trainers, "시드 트레이너가 소속으로 연결돼야 한다"
    assert all(t["gym_id"] == "gym-oncare-sinchon" for t in trainers)


def test_gym_trainers_404_for_unknown_gym(client):
    assert client.get("/v1/gyms/no-such-gym/trainers").status_code == 404


def test_every_seeded_gym_has_at_least_two_trainers(client):
    """앱 화면과 같은 구성이어야 한다 — 헬스장마다 트레이너 2명 이상."""
    for gym_id in SEEDED_IDS:
        trainers = client.get(f"/v1/gyms/{gym_id}/trainers").json()
        assert len(trainers) >= 2, f"{gym_id} 소속 트레이너 {len(trainers)}명"


def test_discovered_gyms_are_not_partners(client):
    """카카오에서 발견한 실재 업체는 제휴가 아니다 — 구분이 유지돼야 한다."""
    for gym_id in DISCOVERED_IDS:
        gym = client.get(f"/v1/gyms/{gym_id}").json()
        assert gym["is_partner"] is False, gym["name"]
    partners = client.get("/v1/gyms", params={"partner_only": True}).json()
    assert {g["id"] for g in partners} == PARTNER_IDS


def test_trainer_directory_and_detail(client):
    listed = client.get("/v1/trainers").json()
    assert listed, "시드 트레이너가 디렉터리에 나와야 한다"

    trainer_id = listed[0]["id"]
    detail = client.get(f"/v1/trainers/{trainer_id}")
    assert detail.status_code == 200, detail.text
    assert detail.json()["id"] == trainer_id


def test_trainer_detail_404_for_unknown(client):
    assert client.get("/v1/trainers/no-such-trainer").status_code == 404


def test_recommended_route_is_not_shadowed_by_detail(client):
    """`/trainers/recommended` 가 `/trainers/{id}` 에 잡히면 404 가 난다."""
    r = client.get("/v1/trainers/recommended")
    assert r.status_code == 200, r.text
    assert isinstance(r.json(), list)


def test_recommended_only_includes_trainers_with_reason(client):
    recommended = client.get("/v1/trainers/recommended").json()
    assert recommended, "시드 트레이너에 추천 사유가 있어야 한다"
    assert all(t["reason"] for t in recommended)


def test_seeded_trainers_cover_every_gym(client):
    """앱 mock 과 같은 15명이 디렉터리에 있어야 화면이 달라지지 않는다."""
    trainers = client.get("/v1/trainers").json()
    assert len(trainers) >= 15

    gym_ids = {t["gym_id"] for t in trainers if t["gym_id"]}
    assert SEEDED_IDS <= gym_ids

    # 이름이 겹치면 목록에서 서로 구분되지 않는다.
    names = [t["name"] for t in trainers]
    assert len(set(names)) == len(names), "트레이너 이름 중복"


def test_consultation_works_for_a_discovered_gym(client):
    """카카오 발견 헬스장이 places 에 없으면 상담이 404 로 실패한다.

    헬스장 상세의 상담 버튼은 제휴 여부를 가리지 않으므로, 발견 헬스장도 상담
    대상이어야 화면과 백엔드가 어긋나지 않는다(#324 → #327).
    """
    from tests.test_consultations import _auth, _payload, _register_member

    _member_id, token = _register_member(client)
    payload = _payload(gym_id="328969863")  # 빌드업짐 PT 신촌점
    r = client.post("/v1/consultations", headers=_auth(token), json=payload)

    assert r.status_code == 201, r.text
    assert r.json()["gym_id"] == "328969863"


def test_trainer_fields_match_app_contract(client):
    trainer = client.get("/v1/trainers/recommended").json()[0]
    # 앱 Trainer 엔티티와 같은 필드여야 매핑 코드가 없다.
    assert set(trainer) == {
        "id", "gym_id", "name", "role", "reason", "career", "intro",
        "certifications",
    }
    # career 는 "7년" 처럼 앱이 그대로 렌더하는 문자열이다.
    assert trainer["career"] is None or trainer["career"].endswith("년")
    assert isinstance(trainer["certifications"], list)


def test_my_coach_exposes_gym_id(client, db_session):
    """"내 헬스장" 카드가 헬스장 상세로 이동하려면 id 가 필요하다(#324).

    데모 회원(user-demo)은 hashed_password 가 비어 있어 로그인할 수 없으므로
    서비스를 직접 호출해 확인한다.
    """
    from app.services import trainer_service

    coach = trainer_service.build_member_coach(db_session, "user-demo")
    assert coach is not None, "시드가 user-demo ↔ 김트레이너를 연결해야 한다"
    # 이름만으로는 목록의 헬스장과 이어붙일 수 없다.
    assert coach.gym.id == "gym-oncare-sinchon"
    assert coach.gym.name == "온케어짐 신촌점"


def test_disconnect_my_coach_is_idempotent(client):
    """해제는 두 번 눌러도 오류 화면이 뜨면 안 된다."""
    from tests.test_consultations import _auth, _register_member

    _member_id, token = _register_member(client)
    # 담당이 없는 회원도 204 — 404 면 앱이 오류를 띄운다.
    assert client.delete("/v1/me/coach", headers=_auth(token)).status_code == 204
    assert client.delete("/v1/me/coach", headers=_auth(token)).status_code == 204
    assert (
        client.delete("/v1/me/coach/trainer", headers=_auth(token)).status_code == 204
    )


# ---- 회원↔헬스장 링크 (#444) ----

@pytest.fixture
def connected_member(client, db_session):
    """헬스장·담당 트레이너에 모두 연결된 새 회원을 만드는 팩토리. (member_id, token)

    끝나면 만든 링크를 지운다 — 김트레이너의 시드 담당 링크 **수**를 세는 테스트가
    있어(`test_trainer.test_demo_trainer_client_links_seeded`) 남겨 두면 그쪽이 깨진다.
    """
    from uuid import uuid4

    from app.models import models
    from tests.test_consultations import _register_member

    created: list[tuple[str, str]] = []

    def _make(gym_id: str = "gym-oncare-sinchon") -> tuple[str, str]:
        member_id, token = _register_member(client)
        link_id = f"tc-{uuid4().hex[:12]}"
        db_session.add(models.MemberGym(member_id=member_id, gym_id=gym_id))
        db_session.add(models.TrainerClient(
            id=link_id, trainer_id="trainer-demo", member_id=member_id, active=True,
        ))
        db_session.commit()
        created.append((link_id, member_id))
        return member_id, token

    yield _make

    for link_id, member_id in created:
        # 테스트가 이미 지웠을 수 있다(해제 경로 검증).
        for row in (
            db_session.get(models.TrainerClient, link_id),
            db_session.get(models.MemberGym, member_id),
        ):
            if row is not None:
                db_session.delete(row)
    db_session.commit()


def test_disconnect_trainer_keeps_the_gym(client, connected_member):
    """트레이너만 해제 — MY 탭 휴지통 2개가 서버에서도 갈라져야 한다.

    전에는 두 버튼이 같은 엔드포인트로 나가, 트레이너만 끊었는데 헬스장 카드까지
    사라졌다(mock 과 실 API 가 갈리던 지점).
    """
    from tests.test_consultations import _auth

    _member_id, token = connected_member()
    assert client.get("/v1/me/gym", headers=_auth(token)).status_code == 200

    assert (
        client.delete("/v1/me/coach/trainer", headers=_auth(token)).status_code == 204
    )

    assert client.get("/v1/me/coach", headers=_auth(token)).status_code == 404
    gym = client.get("/v1/me/gym", headers=_auth(token))
    assert gym.status_code == 200, "트레이너를 끊었다고 헬스장까지 사라지면 안 된다"
    assert gym.json()["id"] == "gym-oncare-sinchon"


def test_disconnect_gym_drops_the_trainer_too(client, connected_member):
    """헬스장 해제는 둘 다 끊는다 — 떠난 헬스장의 트레이너를 담당으로 둘 수 없다."""
    from tests.test_consultations import _auth

    _member_id, token = connected_member()

    assert client.delete("/v1/me/coach", headers=_auth(token)).status_code == 204

    assert client.get("/v1/me/coach", headers=_auth(token)).status_code == 404
    assert client.get("/v1/me/gym", headers=_auth(token)).status_code == 404


def test_my_gym_is_404_without_a_link(client):
    """연결이 없으면 404 — 앱은 이걸 '헬스장 없음' 카드로 바꾼다."""
    from tests.test_consultations import _auth, _register_member

    _member_id, token = _register_member(client)
    assert client.get("/v1/me/gym", headers=_auth(token)).status_code == 404


def test_my_gym_answers_with_the_same_shape_as_the_directory(client, connected_member):
    """`/gyms/{id}` 와 같은 형태여야 앱이 상세를 한 번 더 읽지 않는다."""
    from tests.test_consultations import _auth

    _member_id, token = connected_member()

    mine = client.get("/v1/me/gym", headers=_auth(token), params=SINCHON)
    detail = client.get(
        "/v1/gyms/gym-oncare-sinchon", headers=_auth(token), params=SINCHON
    )
    assert mine.status_code == 200 and detail.status_code == 200
    assert mine.json() == detail.json()


def test_coach_gym_follows_the_member_link_not_the_trainer(db_session, connected_member):
    """코치 요약의 헬스장도 회원 링크가 진실이다.

    트레이너 소속에서 파생시키면, 회원이 다른 헬스장으로 옮겨도 카드가 트레이너를
    따라간다.
    """
    from app.models import models
    from app.services import trainer_service

    member_id, _token = connected_member()
    # 김트레이너의 소속은 gym-oncare-sinchon 이다. 회원만 다른 곳으로 옮긴다.
    link = db_session.get(models.MemberGym, member_id)
    link.gym_id = "gym-healthmate"
    db_session.commit()

    coach = trainer_service.build_member_coach(db_session, member_id)
    assert coach is not None
    assert coach.gym.id == "gym-healthmate"
    assert coach.gym.name == "헬스메이트 신촌점"


def test_coach_gym_falls_back_to_the_trainer_when_unlinked(db_session, connected_member):
    """링크가 없는 회원(백필 이전 데이터)은 예전처럼 트레이너 소속을 보여 준다.

    빈 카드로 퇴화시키는 것보다 낫다.
    """
    from app.models import models
    from app.services import trainer_service

    member_id, _token = connected_member()
    db_session.delete(db_session.get(models.MemberGym, member_id))
    db_session.commit()

    coach = trainer_service.build_member_coach(db_session, member_id)
    assert coach is not None
    assert coach.gym.id == "gym-oncare-sinchon"


def test_coordinates_must_be_sent_as_a_pair(client):
    """하나만 오면 거리 계산이 조용히 생략돼 distance_km=0 이 된다 — 422 여야 한다."""
    assert client.get("/v1/gyms", params={"lat": 37.5559}).status_code == 422
    assert client.get("/v1/gyms", params={"lng": 126.9368}).status_code == 422
    assert (
        client.get(
            "/v1/gyms/gym-oncare-sinchon", params={"lat": 37.5559}
        ).status_code
        == 422
    )
    # 둘 다 있거나 둘 다 없으면 정상.
    assert client.get("/v1/gyms", params=SINCHON).status_code == 200
    assert client.get("/v1/gyms").status_code == 200


def test_discovered_gyms_expose_no_invented_numbers(client):
    """실재 업체에 확인할 수 없는 평점·영업시간·태그를 붙여 내보내지 않는다.

    주석은 API 응답에 남지 않는다 — 실제 상호·주소·전화와 함께 평점이 내려가면
    화면에서는 실제 평점으로 읽힌다(리뷰 지적).
    """
    for gym_id in DISCOVERED_IDS:
        gym = client.get(f"/v1/gyms/{gym_id}").json()
        assert gym["rating"] == 0, gym["name"]      # 0 이면 UI 가 뱃지를 감춘다
        assert gym["tags"] == [], gym["name"]
        assert not gym["weekday_hours"], gym["name"]
        assert not gym["weekend_hours"], gym["name"]
        # 전화·주소는 카카오 실데이터라 그대로 노출한다.
        assert gym["phone"], gym["name"]


def test_disconnect_clears_every_active_link(client, db_session):
    """활성 링크가 여러 개 남은 경우에도 전부 내려야 '해제했는데 그대로'가 안 된다."""
    from app.models.models import TrainerClient
    from app.services import trainer_service
    from tests.test_consultations import _register_member

    member_id, _token = _register_member(client)
    # partial unique index 를 우회해 비정상 상태를 만든다(active 는 한 번에 하나여야
    # 하지만, 깨졌을 때 해제가 동작하는지 본다).
    db_session.add(
        TrainerClient(
            id=f"link-{member_id}-1", trainer_id="trainer-demo",
            member_id=member_id, goal="테스트", active=True,
        )
    )
    db_session.commit()
    try:
        assert trainer_service.disconnect_member_coach(db_session, member_id) is True
        assert trainer_service.get_member_trainer_id(db_session, member_id) is None
        remaining = db_session.query(TrainerClient).filter(
            TrainerClient.member_id == member_id, TrainerClient.active.is_(True)
        ).count()
        assert remaining == 0
    finally:
        db_session.query(TrainerClient).filter(
            TrainerClient.member_id == member_id
        ).delete()
        db_session.commit()
