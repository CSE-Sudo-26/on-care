"""리포트 전송 안내 표시 — 채팅 메시지의 `report_week_start`. (#1600, DB 필요)

두 앱은 이 값으로 리포트 전송을 일반 대화가 아니라 안내 상자로 그린다. 첨부
유무와는 별개다 — 리포트는 PDF 없이 본문만으로도 나간다.
"""
from __future__ import annotations

from uuid import uuid4


PDF = b"%PDF-1.4\n1 0 obj<<>>endobj\n%%EOF\n"


def _login(client, email: str) -> str:
    response = client.post(
        "/v1/auth/login",
        data={"username": email, "password": "oncare123"},
    )
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


def _headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _find(thread: list[dict], message_id: str) -> dict:
    match = [m for m in thread if m["id"] == message_id]
    assert match, f"{message_id} 가 스레드에 없다"
    return match[0]


def test_pdf_report_marks_the_week_in_both_threads(client, tmp_path, monkeypatch):
    from app.core.config import get_settings

    monkeypatch.setattr(get_settings(), "report_pdf_storage_dir", str(tmp_path))
    trainer_token = _login(client, "trainer@oncare.com")
    sent = client.post(
        "/v1/trainer/clients/user-jisu/report/send-pdf",
        headers=_headers(trainer_token),
        data={
            # 주 중간 날짜로 보내도 그 주 월요일로 정규화된다 — 화면이 적는
            # 기간(월→일)과 저장된 값이 어긋나면 안 된다.
            "week_start": "2026-08-05",
            "message": "이번 주 리포트입니다.",
            "client_request_id": f"week-test-{uuid4().hex[:12]}",
        },
        files={"pdf": ("weekly.pdf", PDF, "application/pdf")},
    )
    assert sent.status_code == 201, sent.text
    assert sent.json()["report_week_start"] == "2026-08-03"

    message_id = sent.json()["id"]
    trainer_thread = client.get(
        "/v1/trainer/clients/user-jisu/chat", headers=_headers(trainer_token)
    ).json()
    assert _find(trainer_thread, message_id)["report_week_start"] == "2026-08-03"

    member_token = _login(client, "jisu@oncare.com")
    member_thread = client.get(
        "/v1/me/coach/chat", headers=_headers(member_token)
    ).json()
    assert _find(member_thread, message_id)["report_week_start"] == "2026-08-03"


def test_text_report_marks_the_week_and_plain_chat_does_not(client):
    """PDF 없이 본문만 보낸 리포트도 안내로 표시되고, 일반 대화는 아니다."""
    trainer_token = _login(client, "trainer@oncare.com")
    report = client.post(
        "/v1/trainer/clients/user-jisu/report/send",
        headers=_headers(trainer_token),
        json={"week_start": "2026-08-05", "message": "이번 주 리포트 정리했어요"},
    )
    assert report.status_code == 201, report.text
    assert report.json()["attachment"] is None
    assert report.json()["report_week_start"] == "2026-08-03"

    chat = client.post(
        "/v1/trainer/clients/user-jisu/chat",
        headers=_headers(trainer_token),
        json={"text": "오늘 컨디션 어떠세요?"},
    )
    assert chat.status_code == 201, chat.text
    assert chat.json()["report_week_start"] is None
