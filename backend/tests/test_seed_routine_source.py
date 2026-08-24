"""김민수 개인운동 시드가 공유 픽스처의 출처를 그대로 따르는지. (#1199)

목업은 픽스처를 읽어 `트레이너 추천` 과 `AI 추천` 을 갈라 적는데, 실서버 시드는
따로 든 표에서 넷 모두 `ai` 로 넣었다. 실연동 데모에서 두 출처의 차이가 사라져
있었다.

DB 필요(로컬 skip, CI 의 Postgres 서비스에서 실행).
"""
from __future__ import annotations

from app.db.demo_fixture import load_fixture

_MEMBER_ID = "user-demo"


def _h(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _member_tok(client) -> str:
    return client.post(
        "/v1/auth/login",
        data={"username": "minsu@oncare.com", "password": "oncare123"},
    ).json()["access_token"]


def test_fixture_carries_both_sources() -> None:
    """픽스처가 두 출처를 섞어 든다 — 이 전제가 깨지면 아래 검증이 무의미하다."""
    routines = load_fixture().routines
    assert routines, "픽스처에 개인운동이 없습니다."
    sources = {r.source for r in routines}
    assert sources == {"ai", "trainer"}, sources


def test_seeded_routines_match_fixture(client, db_session) -> None:
    """시드 행의 내용이 픽스처와 같다 — 이름·분·유형·이유·출처 전부."""
    from app.models.models import TrainerRoutine

    for routine in load_fixture().routines:
        row = db_session.get(TrainerRoutine, routine.id)
        assert row is not None, f"{routine.id} 시드가 없습니다."
        assert row.member_id == _MEMBER_ID
        assert (
            row.name,
            row.minutes,
            row.type,
            row.reason,
            row.source,
        ) == (
            routine.name,
            routine.minutes,
            routine.type,
            routine.reason,
            routine.source,
        )


def test_reseed_realigns_drifted_row_without_touching_review(
    client, db_session
) -> None:
    """이미 시드된 행도 픽스처 값으로 맞춘다. 검토 상태는 그대로 둔다.

    한 번 시드된 DB 가 옛 값을 들고 있으면 픽스처를 고쳐도 실연동 화면이 바뀌지
    않는다 — 예전 시드가 넣어 둔 `ai` 넷이 그런 상태였다.
    """
    from app.db.seed_member_data import _seed_routines
    from app.models.models import TrainerRoutine

    target = next(r for r in load_fixture().routines if r.source == "trainer")
    row = db_session.get(TrainerRoutine, target.id)
    assert row is not None

    original_status = row.status
    row.source = "ai"
    row.name = "옛 이름"
    row.status = "pending"
    db_session.commit()

    _seed_routines(db_session, _MEMBER_ID)
    db_session.refresh(row)

    assert row.source == target.source
    assert row.name == target.name
    # 시드가 소유하지 않는 값 — 트레이너의 검토 결과를 되돌리지 않는다.
    assert row.status == "pending"

    row.status = original_status
    db_session.commit()


def test_member_api_reports_fixture_source(client) -> None:
    """회원 앱이 읽는 응답의 출처가 픽스처와 같다."""
    rows = client.get("/v1/me/coach/routines", headers=_h(_member_tok(client)))
    assert rows.status_code == 200, rows.text
    by_id = {r["id"]: r for r in rows.json()}
    for routine in load_fixture().routines:
        assert by_id[routine.id]["source"] == routine.source
