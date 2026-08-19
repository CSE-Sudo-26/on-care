"""트레이너가 채팅으로 보내는 사진. (#921)

지금까지 첨부는 주간 리포트 PDF 하나뿐이라, 자세 사진·시범 이미지처럼 코칭에서
가장 자주 오가는 형식을 보낼 수 없었다.

여기서 가장 중요하게 보는 것 둘: **형식을 바이트로 판정하는가**(적어 준
Content-Type 을 믿으면 아무 파일이나 저장된다), 그리고 **그 스레드의 두 사람만
받을 수 있는가**.

DB 가 필요하므로 로컬에서는 skip 되고 CI(Postgres) 에서 실행된다.
"""
from __future__ import annotations

import struct
import zlib
from uuid import uuid4

import pytest

from app.core.security import hash_password
from app.models.models import (
    ChatMessage,
    Notification,
    TrainerClient,
    TrainerProfile,
    User,
)
from app.services import chat_image_storage

EMAIL_PREFIX = "chatimg-test-"
PASSWORD = "chatimg-pw-1234"


def _png(width: int = 1, height: int = 1) -> bytes:
    """가장 작은 유효 PNG. 파일을 읽어 오지 않고 여기서 만든다 —
    테스트가 저장소의 픽스처 파일에 기대지 않게."""

    def chunk(tag: bytes, payload: bytes) -> bytes:
        return (
            struct.pack(">I", len(payload))
            + tag
            + payload
            + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
        )

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    raw = b"".join(b"\x00" + b"\x00\x00\x00" * width for _ in range(height))
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )


@pytest.fixture(autouse=True)
def _cleanup(db_session):
    saved: list[str] = []
    yield saved
    db_session.rollback()
    user_ids = [
        row[0]
        for row in db_session.query(User.id)
        .filter(User.email.like(f"{EMAIL_PREFIX}%"))
        .all()
    ]
    if user_ids:
        for row in (
            db_session.query(ChatMessage.attachment_file_id)
            .filter(ChatMessage.trainer_id.in_(user_ids))
            .all()
        ):
            if row[0]:
                chat_image_storage.delete(row[0])
        db_session.query(ChatMessage).filter(
            ChatMessage.trainer_id.in_(user_ids)
        ).delete(synchronize_session=False)
        db_session.query(TrainerClient).filter(
            TrainerClient.trainer_id.in_(user_ids)
        ).delete(synchronize_session=False)
        db_session.query(Notification).filter(
            Notification.user_id.in_(user_ids)
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


def _login(client, email: str) -> str:
    response = client.post(
        "/v1/auth/login", data={"username": email, "password": PASSWORD}
    )
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


def _member(client) -> tuple[str, str]:
    email = f"{EMAIL_PREFIX}member-{uuid4().hex[:10]}@oncare.com"
    response = client.post(
        "/v1/auth/register",
        json={"email": email, "password": PASSWORD, "name": "사진 회원"},
    )
    assert response.status_code == 201, response.text
    return response.json()["id"], _login(client, email)


def _trainer_with_client(client, db_session, member_id: str) -> tuple[User, str]:
    suffix = uuid4().hex[:10]
    email = f"{EMAIL_PREFIX}trainer-{suffix}@oncare.com"
    trainer = User(
        id=f"chatimg-trainer-{suffix}",
        email=email,
        name="사진 트레이너",
        hashed_password=hash_password(PASSWORD),
        role="trainer",
        is_active=True,
    )
    db_session.add(trainer)
    db_session.flush()
    db_session.add(TrainerProfile(trainer_id=trainer.id))
    db_session.add(
        TrainerClient(
            id=f"tc-chatimg-{suffix}",
            trainer_id=trainer.id,
            member_id=member_id,
            active=True,
        )
    )
    db_session.commit()
    return trainer, _login(client, email)


def _send(client, token: str, member_id: str, data: bytes, name: str = "pose.png"):
    return client.post(
        f"/v1/trainer/clients/{member_id}/chat/image",
        files={"image": (name, data, "image/png")},
        data={"message": "이 자세를 참고해 주세요"},
        headers=_auth(token),
    )


def test_the_member_receives_the_photo_in_the_same_thread(client, db_session):
    member_id, member_token = _member(client)
    _, trainer_token = _trainer_with_client(client, db_session, member_id)

    sent = _send(client, trainer_token, member_id, _png())

    assert sent.status_code == 201, sent.text
    attachment = sent.json()["attachment"]
    assert attachment["type"] == "image"
    assert attachment["file_name"] == "pose.png"

    thread = client.get("/v1/me/coach/chat", headers=_auth(member_token))
    assert thread.status_code == 200, thread.text
    received = thread.json()[-1]
    assert received["body"] == "이 자세를 참고해 주세요"
    assert received["attachment"]["type"] == "image"
    assert received["attachment"]["file_id"] == attachment["file_id"]


def test_a_photo_can_be_sent_without_a_message(client, db_session):
    """사진만 보내는 것이 자연스러운 경우가 있다 — 본문을 강제하지 않는다."""
    member_id, _ = _member(client)
    _, trainer_token = _trainer_with_client(client, db_session, member_id)

    response = client.post(
        f"/v1/trainer/clients/{member_id}/chat/image",
        files={"image": ("pose.png", _png(), "image/png")},
        headers=_auth(trainer_token),
    )

    assert response.status_code == 201, response.text
    assert response.json()["body"] == ""


def test_a_photo_only_message_still_says_something_in_the_notification(
    client, db_session
):
    """본문이 빈 메시지의 알림은 제목만 남는다 — 무엇이 왔는지 알 수 없다."""
    member_id, _ = _member(client)
    _, trainer_token = _trainer_with_client(client, db_session, member_id)

    client.post(
        f"/v1/trainer/clients/{member_id}/chat/image",
        files={"image": ("pose.png", _png(), "image/png")},
        headers=_auth(trainer_token),
    )

    bodies = [
        row[0]
        for row in db_session.query(Notification.body)
        .filter(Notification.user_id == member_id)
        .all()
    ]
    assert "사진을 보냈어요" in bodies


def test_both_sides_of_the_thread_can_download_it(client, db_session):
    member_id, member_token = _member(client)
    _, trainer_token = _trainer_with_client(client, db_session, member_id)
    file_id = _send(client, trainer_token, member_id, _png()).json()["attachment"][
        "file_id"
    ]

    for token in (member_token, trainer_token):
        response = client.get(
            f"/v1/chat/attachments/{file_id}", headers=_auth(token)
        )
        assert response.status_code == 200, response.text
        assert response.headers["content-type"] == "image/png"
        # 사진은 대화 안에서 그려야 한다 — 내려받기로 처리되면 스레드에
        # 아무것도 보이지 않는다.
        assert "inline" in response.headers["content-disposition"]


def test_a_stranger_cannot_download_it(client, db_session):
    member_id, _ = _member(client)
    _, trainer_token = _trainer_with_client(client, db_session, member_id)
    _, stranger_token = _member(client)
    file_id = _send(client, trainer_token, member_id, _png()).json()["attachment"][
        "file_id"
    ]

    response = client.get(
        f"/v1/chat/attachments/{file_id}", headers=_auth(stranger_token)
    )

    # 존재 여부조차 알려 주지 않는다.
    assert response.status_code == 404


def test_the_declared_content_type_is_not_believed(client, db_session):
    """`image/png` 라고 적힌 실행 파일은 이미지가 아니다."""
    member_id, _ = _member(client)
    _, trainer_token = _trainer_with_client(client, db_session, member_id)

    response = client.post(
        f"/v1/trainer/clients/{member_id}/chat/image",
        files={"image": ("evil.png", b"MZ\x90\x00 not an image", "image/png")},
        headers=_auth(trainer_token),
    )

    assert response.status_code == 415


def test_a_pdf_is_not_accepted_as_a_photo(client, db_session):
    """리포트 PDF 는 자기 경로가 있다 — 여기로 들어오면 그림으로 그려진다."""
    member_id, _ = _member(client)
    _, trainer_token = _trainer_with_client(client, db_session, member_id)

    response = client.post(
        f"/v1/trainer/clients/{member_id}/chat/image",
        files={"image": ("report.pdf", b"%PDF-1.4\n%%EOF", "application/pdf")},
        headers=_auth(trainer_token),
    )

    assert response.status_code == 415


def test_a_retry_with_the_same_key_does_not_send_twice(client, db_session):
    member_id, member_token = _member(client)
    _, trainer_token = _trainer_with_client(client, db_session, member_id)
    key = uuid4().hex

    first = client.post(
        f"/v1/trainer/clients/{member_id}/chat/image",
        files={"image": ("pose.png", _png(), "image/png")},
        data={"message": "같은 사진", "client_request_id": key},
        headers=_auth(trainer_token),
    )
    second = client.post(
        f"/v1/trainer/clients/{member_id}/chat/image",
        files={"image": ("pose.png", _png(), "image/png")},
        data={"message": "같은 사진", "client_request_id": key},
        headers=_auth(trainer_token),
    )

    assert first.status_code == 201, first.text
    assert second.status_code == 201, second.text
    assert first.json()["id"] == second.json()["id"]
    thread = client.get("/v1/me/coach/chat", headers=_auth(member_token)).json()
    assert len([row for row in thread if row["attachment"]]) == 1


def test_a_member_who_is_not_mine_gets_nothing(client, db_session):
    member_id, _ = _member(client)
    other_member_id, _ = _member(client)
    _, trainer_token = _trainer_with_client(client, db_session, member_id)

    response = client.post(
        f"/v1/trainer/clients/{other_member_id}/chat/image",
        files={"image": ("pose.png", _png(), "image/png")},
        headers=_auth(trainer_token),
    )

    assert response.status_code == 404


def test_the_storage_reads_the_format_from_the_bytes():
    assert chat_image_storage.sniff(_png()) == ("png", "image/png")
    assert chat_image_storage.sniff(b"\xff\xd8\xff\xe0rest") == (
        "jpg",
        "image/jpeg",
    )
    assert chat_image_storage.sniff(b"RIFF____WEBPVP8 ") == ("webp", "image/webp")
    with pytest.raises(chat_image_storage.UnsupportedImage):
        chat_image_storage.sniff(b"<svg xmlns='http://www.w3.org/2000/svg'/>")
