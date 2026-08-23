"""트레이너 채팅에서 다음 PT 를 읽어 내는 규칙. (#1061)

약속은 대화에서 잡히는데, 그 말이 채팅 안에만 남으면 회원 앱의 `다음 PT 일정`
은 비어 있거나 지난 일정을 들고 있다.

없는 약속을 지어내는 쪽이 약속을 놓치는 쪽보다 나쁘다 — 회원이 엉뚱한 날에
헬스장에 간다. 그래서 애매한 문장은 전부 흘려보내는지가 이 파일의 관심사다.
"""
from __future__ import annotations

from datetime import date
from uuid import uuid4

import pytest

from app.services.schedule_parse import parse_schedule

#: 2026-08-21 은 금요일이다.
FRIDAY = date(2026, 8, 21)


def _h(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("다음 PT는 다음 주 수요일 오후 8시로 할게요!", ("2026-08-26", "20:00")),
        ("내일 오전 10시에 PT 봬요", ("2026-08-22", "10:00")),
        ("8월 25일 오후 3시 수업 잡아둘게요", ("2026-08-25", "15:00")),
        ("이번 주 일요일 저녁 7시 세션이요", ("2026-08-23", "19:00")),
        ("모레 14시 PT 로 하죠", ("2026-08-23", "14:00")),
    ],
)
def test_reads_the_appointment_a_trainer_states(text, expected):
    parsed = parse_schedule(text, sent_on=FRIDAY)
    assert parsed is not None, text
    assert (parsed.date, parsed.time) == expected


@pytest.mark.parametrize(
    "text",
    [
        # 아직 묻는 말이다 — 한쪽이 제안했을 뿐 정해진 것이 없다.
        "다음 PT 수요일 오후 8시 어때요?",
        # 취소·변경은 새 약속이 아니다.
        "다음 주 수요일 오후 8시 PT 는 취소할게요",
        # 시각이 없으면 인사말과 구분되지 않는다.
        "다음 주 수요일에 PT 봬요",
        # 날짜가 없다.
        "PT 오후 8시로 할게요",
        # PT 이야기가 아니다.
        "내일 오전 10시에 약 꼭 드세요",
        # 오전·오후가 없는 한 자리 시각은 짐작하지 않는다.
        "내일 7시 PT 예요",
    ],
)
def test_says_nothing_when_it_is_not_sure(text):
    assert parse_schedule(text, sent_on=FRIDAY) is None


def test_trainer_message_puts_the_next_pt_on_the_member_schedule(client):
    """트레이너가 대화에서 잡은 약속이 회원의 세션 목록에 나타난다."""
    trainer = client.post(
        "/v1/auth/login",
        data={"username": "trainer@oncare.com", "password": "oncare123"},
    ).json()["access_token"]

    # 문장에 절대 날짜를 적어, 언제 돌려도 같은 날을 가리키게 한다.
    said = client.post(
        "/v1/trainer/clients/user-jisu/chat",
        json={"text": "다음 PT는 12월 24일 오후 8시로 할게요!"},
        headers=_h(trainer),
    )
    assert said.status_code in (200, 201), said.text

    member = client.post(
        "/v1/auth/login",
        data={"username": "jisu@oncare.com", "password": "oncare123"},
    ).json()["access_token"]
    sessions = client.get("/v1/me/coach/sessions", headers=_h(member)).json()
    booked = [s for s in sessions if s["time"] == "20:00"]
    assert booked, sessions
    assert booked[0]["status"] == "예정"

    # 같은 약속을 두 번 말해도 칸이 늘지 않는다.
    client.post(
        "/v1/trainer/clients/user-jisu/chat",
        json={"text": "다음 PT는 12월 24일 오후 8시예요"},
        headers=_h(trainer),
    )
    again = client.get("/v1/me/coach/sessions", headers=_h(member)).json()
    assert len([s for s in again if s["time"] == "20:00"]) == len(booked)


def test_member_message_does_not_book_anything(client):
    """회원이 제안한 시간은 아직 약속이 아니다."""
    member = client.post(
        "/v1/auth/login",
        data={"username": "jisu@oncare.com", "password": "oncare123"},
    ).json()["access_token"]

    before = client.get("/v1/me/coach/sessions", headers=_h(member)).json()
    asked = client.post(
        "/v1/me/coach/chat",
        json={"text": f"다음 PT는 11월 3일 오후 6시로 할게요 {uuid4().hex[:6]}"},
        headers=_h(member),
    )
    assert asked.status_code == 201, asked.text

    after = client.get("/v1/me/coach/sessions", headers=_h(member)).json()
    assert len(after) == len(before)
