"""Authenticated access to the PDF attachment carried by a chat message."""
from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session
from starlette.responses import FileResponse

from app.api.deps import RequireUser
from app.db.session import get_db
from app.models.models import ChatMessage, TrainerClient
from app.services import report_pdf_storage

router = APIRouter(tags=["chat-attachments"])


@router.get("/chat/attachments/{file_id}")
def download_chat_pdf(
    file_id: str,
    user: RequireUser,
    db: Annotated[Session, Depends(get_db)],
) -> FileResponse:
    message = db.scalar(
        select(ChatMessage).where(
            ChatMessage.attachment_file_id == file_id,
            ChatMessage.attachment_type == "pdf",
        )
    )
    if message is None:
        raise HTTPException(status_code=404, detail="PDF를 찾을 수 없습니다.")

    allowed = user.role == "member" and message.member_id == user.id
    if user.role == "trainer" and message.trainer_id == user.id:
        allowed = db.scalar(
            select(TrainerClient.id).where(
                TrainerClient.trainer_id == user.id,
                TrainerClient.member_id == message.member_id,
                TrainerClient.active.is_(True),
            )
        ) is not None
    if not allowed:
        # 다른 사용자에게 file id의 존재 여부를 노출하지 않는다.
        raise HTTPException(status_code=404, detail="PDF를 찾을 수 없습니다.")
    try:
        path = report_pdf_storage.path_for(file_id)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail="PDF를 찾을 수 없습니다.") from exc
    return FileResponse(
        path,
        media_type="application/pdf",
        filename=message.attachment_file_name or "weekly-report.pdf",
        content_disposition_type="attachment",
    )
