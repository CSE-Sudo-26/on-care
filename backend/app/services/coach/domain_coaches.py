"""
도메인별 RAG 코치 (식단 / 운동).

흐름(도메인마다 동일):
  1) 사용자 최근 데이터로 질의문 구성
  2) retrieve_context() 로 [내 기록 + 공공 가이드라인] 컨텍스트 확보 (격리·도메인 필터 적용)
  3) LLM 에 system+user 프롬프트로 코칭 생성 (토큰 기록)
  4) 실패(키 없음/자료 없음/에러) 시 STEP 6 규칙 기반으로 폴백

식단·운동을 각각 생성한 뒤 합치는 구조는 coach_service.build_feedback 에서.
STEP 8 챗봇은 retrieve_context + get_coach_llm 을 직접 재사용.
"""
from __future__ import annotations
import logging
from sqlalchemy.orm import Session

from app.schemas.misc_api import CoachSuggestion
from app.services.coach import grounding, prompt_safety
from app.services.coach.llm import get_coach_llm
from app.services.coach.rag import retrieve_context
# STEP 6 규칙 기반(폴백)
from app.services.coach_service import _diet_suggestion, _exercise_suggestion

logger = logging.getLogger(__name__)

_DIET_SYSTEM = (
    "당신은 고혈압·당뇨 위험군을 돕는 전문 영양 코치입니다. "
    "제공된 '내 건강 기록'과 '참고 자료'에 근거해, 나트륨·당류 관리를 중심으로 "
    "DASH 식단 관점의 조언을 2~3문장으로 친근하게 한국어로 제시하세요. "
    "근거 없는 단정은 피하고, 참고 자료가 있으면 그 권고를 반영하세요. "
    # 식단 조언도 자유 서술이라 "나트륨을 줄이면 당신 혈압이…" 로 새어 나갈 수
    # 있다. 세 코치 모두 같은 안내를 싣는다(#602).
    + grounding.UNTRACKED_METRIC_NOTICE + " "
    # 개인 문서에는 트레이너와 주고받은 대화도 검색되어 들어온다(#580).
    + prompt_safety.UNTRUSTED_QUOTE_GUARD
)
_EXERCISE_SYSTEM = (
    "당신은 만성질환 위험군을 돕는 운동 코치입니다. "
    "제공된 '내 건강 기록'과 '참고 자료'에 근거해, 최근 운동량과 생활 습관에 맞는 "
    "운동 조언을 2~3문장으로 친근하게 한국어로 제시하세요. "
    # 예전에는 "혈압·혈당 관리에 도움이 되는" 이라고 지시했다. 그 수치를 재지
    # 않으므로 모델이 근거 없이 답하거나 일반론으로 흘렀다(#602).
    + grounding.UNTRACKED_METRIC_NOTICE + " "
    + prompt_safety.UNTRUSTED_QUOTE_GUARD
)


def _rag_suggestion(
    db: Session, user_id: str, *, domain: str, system_prompt: str,
    query: str, tag: str, title: str, fallback: CoachSuggestion,
) -> CoachSuggestion:
    try:
        context = retrieve_context(db, query, user_id=user_id, domain=domain)
        if not context:
            return fallback  # 검색 자료가 전혀 없으면 규칙 기반
        llm = get_coach_llm()
        user_prompt = f"{context}\n\n위 정보를 바탕으로 조언해 주세요."
        result = llm.generate(system_prompt, user_prompt)
        if not result.text.strip():
            return fallback
        return CoachSuggestion(tag=tag, title=title, body=result.text.strip())
    except Exception:
        # 키 미설정/네트워크/모델 오류 → 안전하게 규칙 기반 폴백 (단, 로그는 남긴다)
        logger.exception(
            "RAG 코칭 생성 실패 (domain=%s, user_id=%s) → 규칙 기반 폴백 사용", domain, user_id
        )
        return fallback

def diet_coach(db: Session, user_id: str) -> CoachSuggestion:
    fallback = _diet_suggestion(db, user_id)
    return _rag_suggestion(
        db, user_id, domain="diet", system_prompt=_DIET_SYSTEM,
        query="최근 식단의 나트륨·당류 관리와 개선점",
        tag="diet", title="오늘의 식단 코칭", fallback=fallback,
    )


def exercise_coach(db: Session, user_id: str) -> CoachSuggestion:
    fallback = _exercise_suggestion(db, user_id)
    return _rag_suggestion(
        db, user_id, domain="exercise", system_prompt=_EXERCISE_SYSTEM,
        # 질의문도 실제 적재된 것으로 좁힌다 — 혈압·혈당으로 검색해 봐야 개인
        # 문서에는 없고, 엉뚱한 공공 문서만 상위로 끌어올린다(#602).
        query="이번 주 운동량과 최근 운동 기록을 바탕으로 한 운동 제안",
        tag="exercise", title="오늘의 운동 코칭", fallback=fallback,
    )
