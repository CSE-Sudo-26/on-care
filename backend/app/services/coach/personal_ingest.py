"""회원의 기록을 개인 RAG 문서로 적재(best-effort).

지금 적재하는 것: 식단 기록(`record_diet`), 트레이너↔회원 채팅(`record_chat`, #580),
운동 세션(`record_exercise`, #586).

혈압·혈당은 여기 없고 앞으로도 없다 — 입력이 번거로워 **제품에서 빼기로 한 항목**이다
(그래서 `vitals` 테이블도 엔드포인트도 없다). 적재를 깜빡한 게 아니므로 나중에
"운동은 있는데 혈압은 왜 없지" 로 다시 열지 말 것. 다만 코치 프롬프트는 아직
혈압·혈당 조언을 지시하고 있어, 그쪽을 줄이는 건 별도 과제다.
적재해 두면 회원 앱 AI 코치의 두 경로(홈 피드백 카드·챗봇)가 retrieve 를 통해
자동으로 근거로 쓴다 — 코치 쪽 코드를 건드리지 않아도 된다.

원칙: 적재 실패(임베딩 오류 등)가 절대 원 기록 저장이나 응답을 깨뜨리지 않는다.
실패 시 조용히 넘어가고 세션을 롤백해 정리한다. RAG_AUTO_INGEST=false 로 끌 수 있다.
"""
from __future__ import annotations

import logging

from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.services.coach import prompt_safety
from app.services.coach.rag import (
    ingest_personal_text,
    purge_personal,
    replace_personal_text,
)

log = logging.getLogger(__name__)


def _safe(
    db: Session, user_id: str, text: str, *, domain: str, source: str,
    source_ref: str | None = None, replace: bool = False,
) -> None:
    if not get_settings().rag_auto_ingest or not user_id or not text.strip():
        return
    try:
        # 교체는 지우고 다시 넣는다(#603). 그냥 넣으면 옛 수치 문서가 남아 코치가
        # "30분"과 "45분"을 동시에 근거로 삼는다 — 안 고치느니만 못하다.
        #
        # 삭제·삽입을 한 트랜잭션으로 묶는 replace_personal_text 를 쓴다. 예전처럼
        # purge 후 ingest 를 따로 부르면 임베딩이 삭제 뒤에 실패했을 때 기존 청크를
        # 되살릴 수 없고, 두 커밋 사이에 근거가 텅 빈 순간이 생긴다.
        if replace and source_ref:
            replace_personal_text(
                db, user_id, text, domain=domain, source=source,
                source_ref=source_ref, title="",
            )
            return
        ingest_personal_text(
            db, user_id, text, domain=domain, source=source, title="",
            source_ref=source_ref,
        )
    except Exception as e:  # noqa: BLE001 — 적재 실패가 원 기록을 깨면 안 됨
        log.warning("개인 RAG 적재 실패(무시): %s", e)
        try:
            db.rollback()
        except Exception:  # noqa: BLE001
            pass


def forget(db: Session, user_id: str, source_ref: str) -> None:
    """기록이 삭제되면 그 근거 문서도 지운다(#603, best-effort).

    남겨 두면 코치가 사용자가 지운 기록을 계속 근거로 든다 — 사용자 입장에서는
    지운 것이 되살아나는 셈이다.
    """
    if not get_settings().rag_auto_ingest or not user_id or not source_ref:
        return
    try:
        purge_personal(db, user_id, source_ref)
    except Exception as e:  # noqa: BLE001 — 정리 실패가 삭제 응답을 깨면 안 됨
        log.warning("개인 RAG 문서 삭제 실패(무시): %s", e)
        try:
            db.rollback()
        except Exception:  # noqa: BLE001
            pass


#: 이 길이 미만은 적재하지 않는다. 대화의 절반 이상은 "넵", "감사합니다" 같은
#: 정형 응답이라 임베딩 비용만 쓰고 검색 상위에 잡음으로 올라온다.
CHAT_MIN_LENGTH = 6

#: 길이 조건은 넘지만 내용이 없는 상용구. 공백·문장부호를 지운 뒤 비교한다.
_CHAT_BOILERPLATE = frozenset({
    "네알겠습니다", "넵알겠습니다", "감사합니다", "감사해요", "고맙습니다",
    "확인했습니다", "확인했어요", "알겠습니다", "알겠어요", "좋습니다",
    "좋아요", "수고하셨습니다", "수고하세요", "안녕하세요", "잘부탁드립니다",
})


def _chat_is_ingestable(text: str) -> bool:
    """적재할 가치가 있는 발화인가 — 길이와 상용구로만 판단한다.

    의미 판정(증상 언급인지)은 하지 않는다. 그건 검색 단계가 할 일이고, 여기서
    걸러 버리면 나중에 근거가 되었을 발화를 되살릴 방법이 없다.
    """
    stripped = text.strip()
    if len(stripped) < CHAT_MIN_LENGTH:
        return False
    squashed = "".join(ch for ch in stripped if ch.isalnum())
    return squashed not in _CHAT_BOILERPLATE


def record_chat(
    db: Session, member_id: str, *, sender: str, text: str, date: str,
    source_ref: str | None = None,
) -> None:
    """트레이너↔회원 채팅 한 줄을 회원의 개인 문서로 적재한다(#580).

    소유자는 항상 **회원**이다(`user_id=member_id`). 트레이너가 보낸 말도 회원의
    맥락이고, 회원 앱 AI 코치는 `user_id` 로만 검색하기 때문이다. 트레이너 쪽
    코칭 질의도 검색 스코프가 담당 회원이라 같은 문서를 본다.

    발화자를 본문에 함께 박는 이유: 검색 결과는 `content` 만 프롬프트로 나가므로
    (`coach/chat.py:_format_context`), 여기서 라벨을 넣지 않으면 모델이 트레이너의
    지시를 회원의 증상 호소로 오인한다.

    도메인은 'general' 이다 — 무릎 통증 한 마디가 식단 코치와 운동 코치 양쪽에서
    검색되어야 하는데, retrieve 는 'general' 을 항상 후보에 포함한다.
    """
    if not _chat_is_ingestable(text):
        return
    speaker = prompt_safety.speaker_label(sender)
    _safe(
        db, member_id, f"{date} 대화 — {speaker}: {text.strip()}",
        domain="general", source="chat", source_ref=source_ref,
    )


#: 운동 타입/강도의 한국어 라벨. 검색 질의도 답변도 한국어라 저장 코드값(cardio,
#: light …)을 그대로 넣으면 임베딩이 질의와 겉돈다.
_EXERCISE_TYPE_KR = {
    "cardio": "유산소",
    "walking": "걷기",
    "strength": "근력",
    "yoga": "요가",
    "stretching": "스트레칭",
    "other": "기타",
}
_EXERCISE_INTENSITY_KR = {"light": "낮음", "moderate": "보통", "high": "높음"}


def record_exercise(
    db: Session, user_id: str, *, date: str, exercise_type: str, minutes: int,
    calories: int, intensity: str, source_ref: str | None = None,
    replace: bool = False,
) -> None:
    """운동 세션 한 건을 개인 문서로 적재한다(#586).

    운동 코치(`domain_coaches.exercise_coach`)는 `domain="exercise"` 로 검색하는데
    지금까지 개인 문서가 하나도 없어, 프롬프트가 운동 조언을 지시해도 근거가 공공
    가이드라인뿐이었다.

    회원이 직접 남긴 기록과 PT 완료로 파생된 기록을 모두 받는다 — 회원 입장에서는
    둘 다 '내가 한 운동'이고, 주간 집계도 이미 둘을 합쳐서 보여준다(#499).
    """
    text = (
        f"{date} 운동 기록: "
        f"{_EXERCISE_TYPE_KR.get(exercise_type, exercise_type)} {minutes}분, "
        f"{calories}kcal, 강도 {_EXERCISE_INTENSITY_KR.get(intensity, intensity)}."
    )
    _safe(
        db, user_id, text, domain="exercise", source="exercise",
        source_ref=source_ref, replace=replace,
    )


def record_diet(
    db: Session, user_id: str, *, date: str, foods: list[dict],
    total_calories: int, sodium_mg: int, sugar_g: float,
    source_ref: str | None = None, replace: bool = False,
) -> None:
    names = ", ".join(f.get("name", "") for f in foods if f.get("name")) or "식단"
    text = (
        f"{date} 식단 기록: {names}. "
        f"총 {total_calories}kcal, 나트륨 {sodium_mg}mg, 당류 {sugar_g}g."
    )
    _safe(
        db, user_id, text, domain="diet", source="diet",
        source_ref=source_ref, replace=replace,
    )
