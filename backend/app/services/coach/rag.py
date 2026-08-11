"""
RAG 적재(ingest) + 검색(retrieve).

핵심 격리 규칙:
- 개인 문서(환자 데이터): user_id = 특정 사용자
- 공공 문서(가이드라인):  user_id = NULL  → 전체 공유
- 검색은 (user_id == 본인 OR user_id IS NULL) 로만 → 남의 개인기록 절대 안 섞임
- domain('diet'|'exercise'|'general') 으로 도메인별 코치가 자기 자료 위주 검색

STEP 8 챗봇도 retrieve_context() 를 그대로 재사용합니다.
"""
from __future__ import annotations


from sqlalchemy import delete, or_, select
from sqlalchemy import text as sa_text
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.models.models import CoachDocument
from app.services.coach.chunking import chunk_text
from app.services.embedder.factory import get_embedder


# ---- 적재 ----
def ingest_document(
    db: Session,
    content: str,
    *,
    user_id: str | None,      # None = 공공 문서
    domain: str = "general",  # diet|exercise|general
    source: str = "",
    title: str = "",
    source_ref: str | None = None,  # 원본 기록 id (#603)
) -> int:
    """문서를 청킹→임베딩→저장. 저장한 청크 수 반환."""
    chunks = chunk_text(content)
    if not chunks:
        return 0
    embedder = get_embedder()
    vectors = embedder.embed(chunks)

    for chunk, vec in zip(chunks, vectors, strict=True):
        db.add(CoachDocument(
            user_id=user_id, domain=domain, source=source,
            title=title, content=chunk, embedding=vec, source_ref=source_ref,
        ))
    db.commit()
    return len(chunks)


def purge_personal(db: Session, user_id: str, source_ref: str) -> int:
    """한 기록에서 나온 개인 문서를 모두 지운다. 지운 행 수 반환 (#603).

    청킹 때문에 기록 하나가 문서 여러 개일 수 있어 단건 삭제로는 부족하다.
    `user_id` 로도 좁히는 이유는 방어다 — 참조 id 는 접두사가 붙은 uuid 라 충돌이
    사실상 없지만, 남의 문서를 지울 수 있는 경로를 열어 둘 이유도 없다.
    """
    result = db.execute(
        delete(CoachDocument).where(
            CoachDocument.user_id == user_id,
            CoachDocument.source_ref == source_ref,
        )
    )
    db.commit()
    return result.rowcount or 0


def has_personal_doc(db: Session, user_id: str, source_ref: str) -> bool:
    """이 기록이 이미 적재됐는가 (#604).

    시드 적재의 멱등 판정에 쓴다. 기동할 때마다 같은 기록을 다시 임베딩하면 비용도
    비용이지만 같은 내용이 여러 벌 검색돼 상위를 독차지한다.
    """
    return db.scalar(
        select(CoachDocument.id)
        .where(
            CoachDocument.user_id == user_id,
            CoachDocument.source_ref == source_ref,
        )
        .limit(1)
    ) is not None


def _lock_source_ref(db: Session, user_id: str, source_ref: str) -> None:
    """이 기록의 문서 교체를 트랜잭션 끝까지 직렬화한다.

    같은 기록을 두 요청이 동시에 고치면 각자 지우고 넣어 서로의 결과를 밟는다.
    자문 잠금(advisory lock)은 테이블을 몰라도 되고 커밋과 함께 자동으로 풀린다 —
    행 잠금과 달리 지울 행이 하나도 없는 첫 교체에서도 걸린다.
    """
    db.execute(
        sa_text("SELECT pg_advisory_xact_lock(hashtext(:key))"),
        {"key": f"coach_doc:{user_id}:{source_ref}"},
    )


def replace_personal_text(
    db: Session, user_id: str, text: str, *, domain: str, source: str,
    source_ref: str, title: str = "",
) -> int:
    """기록이 바뀌었을 때 그 기록의 개인 문서를 통째로 갈아 끼운다 (#603).

    순서가 중요하다:
      1. **먼저 임베딩한다.** 벡터 생성이 실패해도 이 시점엔 아무것도 지우지 않았다.
         지우고 나서 임베딩하면 실패했을 때 기존 청크를 되살릴 방법이 없다.
      2. 삭제와 삽입을 **한 트랜잭션**으로 커밋한다. 둘을 따로 커밋하면 그 사이에
         검색이 들어와 근거가 하나도 없는 순간을 본다.

    빈 내용이면 기존 문서만 지운다 — 기록이 비워진 것도 반영해야 할 변화다.
    """
    chunks = chunk_text(text)
    vectors = get_embedder().embed(chunks) if chunks else []

    _lock_source_ref(db, user_id, source_ref)
    db.execute(
        delete(CoachDocument).where(
            CoachDocument.user_id == user_id,
            CoachDocument.source_ref == source_ref,
        )
    )
    for chunk, vec in zip(chunks, vectors, strict=True):
        db.add(CoachDocument(
            user_id=user_id, domain=domain, source=source,
            title=title, content=chunk, embedding=vec, source_ref=source_ref,
        ))
    db.commit()
    return len(chunks)


def ensure_personal_text(
    db: Session, user_id: str, text: str, *, domain: str, source: str,
    source_ref: str, title: str = "",
) -> int:
    """아직 적재되지 않았을 때만 적재한다. 이미 있으면 0 (#604).

    확인과 삽입이 갈라져 있으면 안 된다. `has_personal_doc` 로 먼저 보고 따로
    `ingest_personal_text` 를 부르면, 두 인스턴스가 동시에 기동할 때 둘 다 "없다"를
    보고 같은 기록의 청크를 두 벌 넣는다. 유니크 제약으로는 막을 수 없다 — 청킹
    때문에 한 기록이 여러 행이라 (user_id, source_ref) 가 원래 중복이다.

    잠금 전에 한 번 더 확인하는 이유는 비용이다. 이 함수는 기동할 때마다 이미
    적재된 기록 전부에 대해 불리므로, 흔한 경우(이미 있음)를 잠금 없이 끝낸다.
    """
    if has_personal_doc(db, user_id, source_ref):
        return 0

    _lock_source_ref(db, user_id, source_ref)
    # 잠금을 잡는 사이 다른 인스턴스가 넣었을 수 있다. 잠금 안에서 다시 본다.
    if has_personal_doc(db, user_id, source_ref):
        db.commit()  # 잠금 해제 — 이 트랜잭션에서 더 할 일이 없다.
        return 0

    chunks = chunk_text(text)
    if not chunks:
        db.commit()
        return 0
    vectors = get_embedder().embed(chunks)
    for chunk, vec in zip(chunks, vectors, strict=True):
        db.add(CoachDocument(
            user_id=user_id, domain=domain, source=source,
            title=title, content=chunk, embedding=vec, source_ref=source_ref,
        ))
    db.commit()
    return len(chunks)


def ingest_personal_text(
    db: Session, user_id: str, text: str, *, domain: str, source: str,
    title: str = "", source_ref: str | None = None,
) -> int:
    """환자 개인 데이터(식단/운동/채팅 요약)를 적재.

    [source_ref] 를 주면 나중에 그 기록만 골라 교체·삭제할 수 있다.
    """
    return ingest_document(
        db, text, user_id=user_id, domain=domain, source=source, title=title,
        source_ref=source_ref,
    )


# ---- 검색 ----
def retrieve(
    db: Session,
    query: str,
    *,
    user_id: str,
    domain: str | None = None,
) -> dict:
    """
    질의에 대해 개인 문서 top-k + 공공 문서 top-k 를 각각 벡터 검색.
    반환: {"personal": [CoachDocument...], "public": [...]}
    """
    s = get_settings()
    embedder = get_embedder()
    qvec = embedder.embed_one(query)

    def _search(personal: bool, k: int):
        stmt = select(CoachDocument)
        if personal:
            stmt = stmt.where(CoachDocument.user_id == user_id)
        else:
            stmt = stmt.where(CoachDocument.user_id.is_(None))
        if domain:
            # 도메인 일치 또는 general 은 항상 포함
            stmt = stmt.where(or_(CoachDocument.domain == domain,
                                  CoachDocument.domain == "general"))
        stmt = stmt.where(CoachDocument.embedding.isnot(None))
        # pgvector 코사인 거리 정렬
        stmt = stmt.order_by(CoachDocument.embedding.cosine_distance(qvec)).limit(k)
        return list(db.scalars(stmt).all())

    return {
        "personal": _search(True, s.retrieve_personal_k),
        "public": _search(False, s.retrieve_public_k),
    }


def retrieve_context(
    db: Session, query: str, *, user_id: str, domain: str | None = None
) -> str:
    """
    검색 결과를 LLM 프롬프트용 컨텍스트 문자열로 합친다.
    STEP 8 챗봇도 이 함수를 그대로 사용.
    """
    hits = retrieve(db, query, user_id=user_id, domain=domain)
    lines: list[str] = []
    if hits["personal"]:
        lines.append("[내 건강 기록]")
        for d in hits["personal"]:
            lines.append(f"- {d.content}")
    if hits["public"]:
        lines.append("\n[참고 자료(공공 가이드라인)]")
        for d in hits["public"]:
            tag = f"({d.title}) " if d.title else ""
            lines.append(f"- {tag}{d.content}")
    return "\n".join(lines).strip()
