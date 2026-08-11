"""회원 실데이터를 바탕으로 트레이너용 맞춤 루틴 후보를 생성한다.

설정된 코치 LLM(OpenAI/Gemini/LiteLLM)을 우선 호출하고, 키 미설정·네트워크
오류·잘못된 JSON 응답이면 결정론적인 규칙 기반 후보로 폴백한다.
"""
from __future__ import annotations

import json
import logging
import time
# `time` 은 stdlib 모듈로 두고(경과 시간 측정), 자정 시각은 별칭으로 받는다.
from datetime import date, datetime, timedelta
from datetime import time as time_of_day

from pydantic import ValidationError
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.core import clock, metrics
from app.models.models import (
    ChatMessage,
    DietEntry,
    RoutineHistory,
    TrainerClient,
    TrainerRoutine,
)
from app.schemas.trainer_api import (
    ROUTINE_CHAT_MAX_MESSAGES,
    RoutineOptionAnalysisOut,
    RoutineOptionPlanOut,
    RoutineOptionsOut,
    RoutineOptionsRequest,
)
from app.services import routine_ai
from app.services.coach import prompt_safety
from app.services.coach.llm import DEFAULT_THINKING_BUDGET, get_coach_llm

logger = logging.getLogger(__name__)

#: 프롬프트에 싣는 최근 대화 범위. 넓히면 오래된 통증 호소가 이미 나은 뒤에도
#: 계속 루틴을 눌러 버리고, 좁히면 지난주 부상이 사라진다.
CHAT_LOOKBACK_DAYS = 14

#: 프롬프트에 싣는 최대 대화 수(최신 우선). 스키마가 단일 출처다.
CHAT_MAX_MESSAGES = ROUTINE_CHAT_MAX_MESSAGES

#: 발화 한 줄의 길이 상한. 긴 상담 메시지 하나가 프롬프트를 독차지하지 않게 자른다.
CHAT_MAX_CHARS = 200

# JSON 예시의 중괄호가 본문에 그대로 들어가므로 f-string 을 쓰지 않고 이어 붙인다.
_SYSTEM_PROMPT = (
    """\
당신은 만성질환 위험군을 돕는 전문 운동 코치입니다.
제공된 회원 분석과 트레이너 조건만 사용해 서로 다른 맞춤 루틴 두 개를 만드세요.
의학적 진단이나 치료를 단정하지 말고, 통증·부상 메모가 있으면 저충격 대안을 우선하세요.
recent_messages 에 통증·불편 언급이 있으면 해당 부위에 부담이 가는 운동을 피하고,
왜 그렇게 구성했는지 rationale 에 그 발화를 근거로 적으세요.
"""
    + prompt_safety.UNTRUSTED_QUOTE_GUARD
    + "\n"
    + prompt_safety.TRAINER_NOTE_GUARD
    + """

반드시 설명이나 마크다운 없이 아래 JSON 객체만 반환하세요.
{
  "plan_a": {
    "key": "A",
    "label": "짧고 직관적인 한국어 이름",
    "total_minutes": 30,
    "intensity": "낮음|보통|높음",
    "exercises": [
      {"name": "운동명", "minutes": 15, "type": "걷기|유산소|근력|요가|스트레칭|기타"}
    ],
    "reason": "회원에게 보여줄 짧은 추천 이유",
    "rationale": "트레이너가 확인할 데이터 근거"
  },
  "plan_b": {
    "key": "B",
    "label": "짧고 직관적인 한국어 이름",
    "total_minutes": 30,
    "intensity": "낮음|보통|높음",
    "exercises": [
      {"name": "운동명", "minutes": 15, "type": "걷기|유산소|근력|요가|스트레칭|기타"}
    ],
    "reason": "회원에게 보여줄 짧은 추천 이유",
    "rationale": "트레이너가 확인할 데이터 근거"
  }
}
각 plan의 total_minutes는 exercises의 minutes 합과 정확히 같아야 합니다.
"""
)


def build_member_analysis(
    db: Session,
    trainer_id: str,
    member_id: str,
    request: RoutineOptionsRequest,
) -> RoutineOptionAnalysisOut:
    """소유 링크와 회원의 최근 식단·운동·배정 데이터를 하나의 분석으로 집계."""
    link = db.scalar(
        select(TrainerClient).where(
            TrainerClient.trainer_id == trainer_id,
            TrainerClient.member_id == member_id,
        )
    )
    if link is None:
        raise ValueError("담당 고객을 찾을 수 없습니다.")

    # 오늘과 28일 창을 같은 스냅샷에서 뽑는다 — 따로 읽으면 KST 자정 사이에
    # 한 응답의 '오늘 나트륨'과 '최근 4주 이행률'이 다른 날을 기준으로 잡힌다.
    today_date = clock.today()
    today = today_date.isoformat()
    sodium = int(
        db.scalar(
            select(func.coalesce(func.sum(DietEntry.sodium_mg), 0)).where(
                DietEntry.user_id == member_id,
                DietEntry.date == today,
            )
        )
        or 0
    )

    since = (today_date - timedelta(days=27)).isoformat()
    completion = db.scalar(
        select(func.avg(RoutineHistory.completion_rate)).where(
            RoutineHistory.member_id == member_id,
            RoutineHistory.date >= since,
            or_(
                RoutineHistory.trainer_id.is_(None),
                RoutineHistory.trainer_id == trainer_id,
            ),
        )
    )

    latest = db.scalar(
        select(TrainerRoutine)
        .where(
            TrainerRoutine.trainer_id == trainer_id,
            TrainerRoutine.member_id == member_id,
        )
        .order_by(TrainerRoutine.created_at.desc(), TrainerRoutine.id.desc())
        .limit(1)
    )

    return RoutineOptionAnalysisOut(
        goal=link.goal,
        sodium_today_mg=sodium,
        sodium_over_target=sodium > routine_ai.SODIUM_TARGET_MG,
        avg_completion_rate=round(float(completion or 0)),
        latest_routine=latest.name if latest is not None else "-",
        note=request.trainer_note.strip(),
        recent_messages=_recent_chat_lines(db, trainer_id, member_id, today_date),
    )


def _recent_chat_lines(
    db: Session, trainer_id: str, member_id: str, today_date: date,
) -> list[str]:
    """최근 트레이너↔회원 대화를 발화자 라벨이 붙은 줄로 만든다(오래된→최신).

    회원 앱 AI 코치는 같은 대화를 RAG(`personal_ingest.record_chat`)로 받지만,
    이 경로는 RAG 를 쓰지 않고 실데이터를 직접 집계하므로 여기서 따로 읽는다.

    양쪽 발화를 모두 싣고 라벨로 구분한다. 트레이너의 "이번 주는 하체 빼시죠" 도
    루틴 구성의 근거인데, 라벨이 없으면 모델이 그 말을 회원의 증상 호소로 읽는다.
    """
    # created_at 은 timestamptz 다. 식단처럼 문자열 date 컬럼이 아니므로 KST
    # 자정을 실제 시각으로 환산해 비교한다 — 날짜로 캐스팅해 비교하면 인덱스도
    # 못 타고, 드라이버가 파라미터를 varchar 로 넘겨 타입 비교가 깨진다.
    since = datetime.combine(
        today_date - timedelta(days=CHAT_LOOKBACK_DAYS - 1),
        time_of_day.min,
        tzinfo=clock.SEOUL,
    )
    rows = db.execute(
        select(ChatMessage.sender, ChatMessage.body)
        .where(
            ChatMessage.trainer_id == trainer_id,
            ChatMessage.member_id == member_id,
            ChatMessage.created_at >= since,
        )
        # 최신 N건을 고른 뒤 시간순으로 되돌린다 — 잘려 나가야 할 건 오래된 쪽이다.
        .order_by(ChatMessage.created_at.desc(), ChatMessage.id.desc())
        .limit(CHAT_MAX_MESSAGES)
    ).all()

    lines: list[str] = []
    for sender, body in reversed(rows):
        text = (body or "").strip()
        if not text:
            continue
        if len(text) > CHAT_MAX_CHARS:
            text = text[:CHAT_MAX_CHARS] + "…"
        lines.append(f"{prompt_safety.speaker_label(sender)}: {text}")
    return lines


def build_rule_options(
    analysis: RoutineOptionAnalysisOut,
    request: RoutineOptionsRequest,
) -> RoutineOptionsOut:
    """LLM 실패 시 공용 결정형 생성기로 동일 계약을 반환한다."""
    plan_a, plan_b = routine_ai.rule_based_plans(
        goal=analysis.goal,
        sodium_today_mg=analysis.sodium_today_mg,
        avg_completion_rate=analysis.avg_completion_rate,
        available_minutes=request.available_minutes,
        intensity_preference=request.intensity_preference,
        trainer_note=analysis.note,
    )
    return RoutineOptionsOut(
        analysis=analysis,
        plan_a=RoutineOptionPlanOut.model_validate(plan_a),
        plan_b=RoutineOptionPlanOut.model_validate(plan_b),
        generated_by="rule",
    )


class RoutineContractError(ValueError):
    """LLM 응답이 계약을 어겼다 — 공급자는 살아 있고, 볼 곳은 프롬프트·스키마다.

    `ValueError` 를 통째로 계약 위반으로 잡으면 안 된다. `get_coach_llm()` 은
    COACH_LLM 값이 오타면 `ValueError("알 수 없는 코치 LLM: ...")` 를 던지는데
    (`coach/llm.py`), 그건 설정 문제라 프롬프트를 아무리 손봐도 안 고쳐진다.
    계약 위반만 이 타입으로 좁혀 `reason=contract` 와 `reason=infra` 를 가른다.
    """


def _decode_json_object(text: str) -> dict:
    """LLM이 실수로 붙인 코드펜스·설명 앞뒤를 제거하고 첫 JSON 객체만 읽는다."""
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end <= start:
        raise RoutineContractError("LLM 응답에 JSON 객체가 없습니다.")
    try:
        parsed = json.loads(text[start : end + 1])
    except json.JSONDecodeError as exc:
        raise RoutineContractError(f"LLM 응답 JSON 파싱 실패: {exc}") from exc
    if not isinstance(parsed, dict):
        raise RoutineContractError("LLM 응답은 JSON 객체여야 합니다.")
    return parsed


def _generate_with_llm(
    analysis: RoutineOptionAnalysisOut,
    request: RoutineOptionsRequest,
) -> RoutineOptionsOut:
    prompt = json.dumps(
        {
            "member_analysis": analysis.model_dump(),
            "available_minutes": request.available_minutes,
            "intensity_preference": request.intensity_preference,
            "trainer_note": request.trainer_note.strip(),
        },
        ensure_ascii=False,
    )
    # json_mode 와 사고 예산은 **반드시 함께** 넘긴다. 기본값(사고 켜짐)으로는 이
    # 짧은 JSON 하나에도 10초 이상 걸려 클라이언트가 먼저 끊고 규칙형만 보게 된다.
    # json_mode 만 켜면 오히려 더 느려진다(근거 실측은 coach/llm.py 주석).
    result = get_coach_llm().generate(
        _SYSTEM_PROMPT, prompt,
        json_mode=True,
        thinking_budget=DEFAULT_THINKING_BUDGET,
    )
    payload = _decode_json_object(result.text)
    payload["analysis"] = analysis.model_dump()
    payload["generated_by"] = "ai"
    options = RoutineOptionsOut.model_validate(payload)
    if (
        options.plan_a.total_minutes > request.available_minutes
        or options.plan_b.total_minutes > request.available_minutes
    ):
        raise RoutineContractError("LLM 루틴 시간이 요청 가능한 시간을 초과했습니다.")
    return options


def generate_routine_options(
    db: Session,
    trainer_id: str,
    member_id: str,
    request: RoutineOptionsRequest,
) -> RoutineOptionsOut:
    analysis = build_member_analysis(db, trainer_id, member_id, request)
    fallback = build_rule_options(analysis, request)
    started = time.monotonic()
    had_chat = bool(analysis.recent_messages)
    try:
        options = _generate_with_llm(analysis, request)
    except (ValidationError, RoutineContractError) as exc:
        # 계약 위반 — 공급자는 살아 있는데 응답이 규격에 안 맞는다. 프롬프트나
        # 스키마를 손볼 신호라 인프라 장애와 섞으면 안 된다.
        # 넓은 ValueError 가 아니라 이 두 타입만 잡는다 — COACH_LLM 오타 같은
        # 설정 오류도 ValueError 라, 그것까지 계약 위반으로 세면 지표가 엉킨다.
        _record(started, reason="contract", had_chat_context=had_chat)
        logger.warning(
            "맞춤 루틴 LLM 계약 위반 — 규칙 기반 폴백 사용 "
            "(trainer_id=%s, member_id=%s): %s",
            trainer_id, member_id, exc,
        )
        return fallback
    except Exception:  # noqa: BLE001 — 키 미설정·설정 오타·네트워크·5xx, 우리 쪽 버그
        # 이쪽은 stack trace 를 남긴다. 예전엔 한 덩어리로 삼켜서, 스키마 필드
        # 이름을 잘못 쓴 버그도 조용히 규칙형으로 내려가 아무도 몰랐다.
        _record(started, reason="infra", had_chat_context=had_chat)
        logger.exception(
            "맞춤 루틴 LLM 호출 실패 — 규칙 기반 폴백 사용 "
            "(trainer_id=%s, member_id=%s)",
            trainer_id, member_id,
        )
        return fallback

    _record(started, reason=None, had_chat_context=had_chat)
    return options


def _record(
    started: float, *, reason: str | None, had_chat_context: bool,
) -> None:
    """생성 결과를 계측한다(#583).

    소요 시간은 성공·실패 모두 남긴다 — 타임아웃으로 폴백하는 경우 '얼마나 오래
    기다렸는지'가 #584 의 타임아웃 값을 정하는 근거다.
    """
    metrics.observe_ms(
        "routine_options.llm_ms", (time.monotonic() - started) * 1000
    )
    if reason:
        metrics.incr("routine_options.generated", by="rule")
        metrics.incr("routine_options.fallback", reason=reason)
        return
    metrics.incr("routine_options.generated", by="ai")
    # 성공했을 때만 센다 — 규칙형은 채팅을 읽지 않으므로, 폴백까지 세면 이 지표가
    # "채팅 근거가 AI 에 닿았다"는 질문에 거짓으로 답한다(#580 이 실환경에서
    # 도는지 확인하려고 만든 카운터다).
    if had_chat_context:
        metrics.incr("routine_options.with_chat_context")
