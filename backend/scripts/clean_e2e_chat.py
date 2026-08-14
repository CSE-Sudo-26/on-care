"""채팅 E2E(#639)가 만든 메시지와 거기서 파생된 개인 RAG 문서를 지운다.

채팅은 **삭제 API 가 없다.** 그래서 `scripts/e2e_sweep.py` 와 같은 방식으로 DB 에서
직접 지운다. 원본만 지우면 부족하다 — 채팅은 AI 코치 근거로 적재되므로(#580, #604),
메시지만 지우고 문서를 남기면 다음 코칭 답변이 지워진 대화를 근거로 삼는다.

지우는 범위는 **이번 실행의 마커가 든 것**뿐이다. 마커는 러너가 실행마다 새로 만든다.

    python -m scripts.clean_e2e_chat --marker e2e-639-1723598400

혼자 쓰는 로컬 데모 DB 를 전제로 한다(`docs/local_fullstack.md`). 삭제 건수를 출력하니
예상 밖이면 눈에 띈다.
"""
from __future__ import annotations

import argparse
import sys

from sqlalchemy import delete, select

from app.db.session import SessionLocal
from app.models.models import ChatMessage, CoachDocument

# 채팅에서 파생되는 문서만 지운다. 식단 문서까지 건드리면 이 스크립트의 범위를 넘는다.
CHAT_DOC_SOURCES = ("chat",)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--marker",
        required=True,
        help="이번 실행이 메시지 본문에 심어 둔 고유 문자열",
    )
    args = parser.parse_args()
    marker = args.marker.strip()
    if not marker:
        print("marker 가 비어 있습니다 — 전체 삭제를 막기 위해 중단합니다.", file=sys.stderr)
        return 2

    db = SessionLocal()
    try:
        # 문서는 메시지 본문을 그대로 담고 있지 않을 수 있어, 지울 메시지의 소유자만
        # 추려 그 사용자의 채팅 문서 중 마커가 든 것을 지운다.
        owners = set(
            db.scalars(
                select(ChatMessage.member_id).where(
                    ChatMessage.body.like(f"%{marker}%")
                )
            ).all()
        )

        chats = (
            db.execute(
                delete(ChatMessage).where(ChatMessage.body.like(f"%{marker}%"))
            ).rowcount
            or 0
        )

        docs = 0
        if owners:
            docs = (
                db.execute(
                    delete(CoachDocument).where(
                        CoachDocument.user_id.in_(owners),
                        CoachDocument.source.in_(CHAT_DOC_SOURCES),
                        CoachDocument.content.like(f"%{marker}%"),
                    )
                ).rowcount
                or 0
            )
        db.commit()
    finally:
        db.close()

    print(f"채팅 {chats}건, 개인 RAG 문서 {docs}건 삭제 (marker={marker})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
