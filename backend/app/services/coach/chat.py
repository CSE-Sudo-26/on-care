"""AI 코치 챗봇 응답 생성.

RAG(retrieve)로 개인+공공 근거를 모아 LLM 으로 대화형 답변을 생성한다.
LLM 키가 없거나 실패하면 검색 기반(추출형) 답변으로 폴백해, 키 없이도 근거 있는 응답을 준다.
개인/공공 격리·도메인 필터는 retrieve 가 이미 보장한다.
"""
from __future__ import annotations

from sqlalchemy.orm import Session

from app.services.coach import prompt_safety
from app.services.coach.llm import get_coach_llm
from app.services.coach.rag import retrieve

_SYSTEM = (
    "당신은 온케어의 AI 건강 코치 '온이'입니다. 고혈압·당뇨 위험군 사용자를 돕습니다. "
    "제공된 '내 건강 기록'과 '참고 자료(공공 가이드라인)'에 근거해 나트륨·당류·혈압·혈당·운동 관리를 "
    "중심으로 친근하고 구체적으로 한국어로 답하세요. 2~4문장으로 간결하게, 근거 없는 단정이나 의학적 "
    "진단은 피하고, 증상이 심각해 보이면 전문의 상담을 권하세요. "
    # '내 건강 기록'에는 트레이너와 주고받은 대화도 섞여 들어온다(#580).
    + prompt_safety.UNTRUSTED_QUOTE_GUARD
)

_MAX_HISTORY = 6


def _format_context(hits: dict) -> str:
    lines: list[str] = []
    if hits["personal"]:
        lines.append("[내 건강 기록]")
        lines += [f"- {d.content}" for d in hits["personal"]]
    if hits["public"]:
        lines.append("[참고 자료]")
        for d in hits["public"]:
            tag = f"({d.title}) " if d.title else ""
            lines.append(f"- {tag}{d.content}")
    return "\n".join(lines).strip()


def _build_user_prompt(context: str, history: list, message: str) -> str:
    parts: list[str] = []
    if context:
        parts.append(context)
    if history:
        convo = [
            f"{'사용자' if getattr(t, 'role', '') == 'user' else '온이'}: {getattr(t, 'content', '')}"
            for t in history[-_MAX_HISTORY:]
        ]
        parts.append("[이전 대화]\n" + "\n".join(convo))
    parts.append(f"사용자 질문: {message}\n\n온이로서 위 정보를 바탕으로 답해 주세요.")
    return "\n\n".join(parts)


def _fallback_reply(hits: dict) -> str:
    """LLM 없이 검색 결과만으로 만드는 근거 기반 답변."""
    pub = hits["public"]
    if pub:
        top = pub[0]
        lead = f"'{top.title}' 자료에 따르면, " if top.title else ""
        return f"{lead}{top.content} 더 궁금한 점이 있으면 편하게 물어봐 주세요!"
    if hits["personal"]:
        return "최근 기록을 보면 꾸준히 관리하고 계세요. 식단·운동·혈압·혈당 중 어떤 부분이 궁금하신가요?"
    return "고혈압·당뇨 관리(식단·운동·혈압·혈당)에 대해 물어봐 주시면 온이가 도와드릴게요!"


def answer(
    db: Session, user_id: str, message: str, history: list | None = None,
) -> tuple[str, list[str]]:
    """(답변 텍스트, 근거 공공문서 제목들) 반환."""
    history = history or []
    hits = retrieve(db, message, user_id=user_id, domain=None)
    sources = list(dict.fromkeys(d.title for d in hits["public"] if d.title))

    try:
        llm = get_coach_llm()
        prompt = _build_user_prompt(_format_context(hits), history, message)
        text = llm.generate(_SYSTEM, prompt).text.strip()
        if text:
            return text, sources
    except Exception:  # noqa: BLE001 — 키 미설정/네트워크/모델 오류 → 검색 기반 폴백
        pass
    return _fallback_reply(hits), sources
