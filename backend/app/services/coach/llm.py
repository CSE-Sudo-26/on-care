"""
코치 LLM 구현 + factory.

- OpenAICoachLLM (GPT-4o 등)
- GeminiCoachLLM (gemini-2.0-flash 등)
둘 다 LLMResult(토큰 사용량 포함) 반환 → 모델 비교 가능.
.env 의 COACH_LLM 으로 선택, 또는 get_coach_llm("gemini") 강제.
"""
from __future__ import annotations

from functools import lru_cache

from app.core.config import get_settings
from app.services.coach.llm_base import CoachLLM, LLMResult

#: 짧은 JSON 한 건을 받을 때 쓰는 기본 사고 예산.
#:
#: 지연을 지배하는 값이라 호출부마다 따로 정하면 한쪽만 느려진다(실제로 루틴 생성
#: 경로가 이 값을 넘기지 않아 상시 폴백으로 떨어졌다 — #579). 근거 실측은 아래
#: `GeminiCoachLLM.generate` 주석에 있다.
#:
#: **`json_mode=True` 와 반드시 함께 쓴다.** json_mode 만 켜면 오히려 크게 느려진다.
DEFAULT_THINKING_BUDGET = 128


class OpenAICoachLLM(CoachLLM):
    name = "openai"

    def __init__(self) -> None:
        s = get_settings()
        if not s.openai_api_key:
            raise RuntimeError("OPENAI_API_KEY 가 설정되지 않았습니다.")
        from openai import OpenAI
        self._client = OpenAI(api_key=s.openai_api_key, timeout=60.0)
        self._model = s.openai_chat_model

    def generate(
        self,
        system_prompt: str,
        user_prompt: str,
        *,
        json_mode: bool = False,
        thinking_budget: int | None = None,  # noqa: ARG002 - OpenAI 는 사고 예산 개념이 없다
    ) -> LLMResult:
        extra = (
            {"response_format": {"type": "json_object"}} if json_mode else {}
        )
        resp = self._client.chat.completions.create(
            model=self._model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            temperature=0.4,
            **extra,
        )
        u = resp.usage
        return LLMResult(
            text=resp.choices[0].message.content or "",
            model=self._model,
            prompt_tokens=getattr(u, "prompt_tokens", 0),
            completion_tokens=getattr(u, "completion_tokens", 0),
            total_tokens=getattr(u, "total_tokens", 0),
        )


class GeminiCoachLLM(CoachLLM):
    name = "gemini"

    def __init__(self) -> None:
        s = get_settings()
        if not s.gemini_api_key:
            raise RuntimeError("GEMINI_API_KEY 가 설정되지 않았습니다.")
        from google import genai
        from google.genai import types
        self._genai = genai
        self._types = types
        # HTTP 타임아웃을 반드시 건다. 없으면 Gemini 가 응답하지 않을 때 호출 스레드가
        # 무기한 묶인다 — 호출부의 future.result(timeout=...) 은 기다리기를 포기할 뿐
        # 작업을 취소하지 못하므로, 여기서 끊어 주지 않으면 워커가 영영 반납되지 않는다.
        self._client = genai.Client(
            api_key=s.gemini_api_key,
            http_options=types.HttpOptions(
                timeout=int(s.gemini_timeout_seconds * 1000)  # SDK 는 밀리초
            ),
        )
        self._model = s.gemini_model

    def generate(
        self,
        system_prompt: str,
        user_prompt: str,
        *,
        json_mode: bool = False,
        thinking_budget: int | None = None,
    ) -> LLMResult:
        # 사고 예산은 지연에 지배적이다. `gemini-flash-latest` 는 기본적으로 사고가
        # 켜져 있어 짧은 JSON 응답도 10초 이상 걸린다(실측 12.9s). 작은 예산을 주면
        # 1.5s 수준으로 떨어진다. 단 budget=0 은 이 모델이 400 으로 거부하므로,
        # "사고 끄기"가 아니라 "예산 제한"으로만 쓴다.
        # 주의: json_mode 를 사고 예산 없이 단독으로 켜면 오히려 크게 느려졌다(실측
        # 177s). 둘은 함께 쓴다.
        options: dict[str, object] = {
            "system_instruction": system_prompt,
            "temperature": 0.4,
        }
        if json_mode:
            options["response_mime_type"] = "application/json"
        if thinking_budget is not None:
            options["thinking_config"] = self._types.ThinkingConfig(
                thinking_budget=thinking_budget
            )
        resp = self._client.models.generate_content(
            model=self._model,
            contents=[user_prompt],
            config=self._types.GenerateContentConfig(**options),
        )
        um = getattr(resp, "usage_metadata", None)
        pt = getattr(um, "prompt_token_count", 0) if um else 0
        ct = getattr(um, "candidates_token_count", 0) if um else 0
        return LLMResult(
            text=resp.text or "", model=self._model,
            prompt_tokens=pt, completion_tokens=ct, total_tokens=(pt + ct),
        )


class LiteLLMCoachLLM(CoachLLM):
    """LiteLLM 프록시 경유 (OpenAI 호환). Virtual Key 하나로 claude 등 호출."""
    name = "litellm"

    def __init__(self) -> None:
        s = get_settings()
        if not s.litellm_api_key:
            raise RuntimeError("LITELLM_API_KEY(Virtual Key) 가 설정되지 않았습니다.")
        if not s.litellm_base_url:
            raise RuntimeError(
                "LITELLM_BASE_URL 이 설정되지 않았습니다. .env 에 지정하세요. "
                "(예: LITELLM_BASE_URL=https://<litellm-host>:4000)"
            )
        from openai import OpenAI
        # base_url 만 LiteLLM 으로 돌리면 OpenAI SDK 가 프록시를 호출
        self._client = OpenAI(api_key=s.litellm_api_key, base_url=f"{s.litellm_base_url}/v1", timeout=60.0)
        self._model = s.litellm_chat_model

    def generate(
        self,
        system_prompt: str,
        user_prompt: str,
        *,
        json_mode: bool = False,
        thinking_budget: int | None = None,  # noqa: ARG002 - 프록시 모델마다 달라 전달하지 않는다
    ) -> LLMResult:
        extra = (
            {"response_format": {"type": "json_object"}} if json_mode else {}
        )
        resp = self._client.chat.completions.create(
            model=self._model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            temperature=0.4,
            **extra,
        )
        u = resp.usage
        return LLMResult(
            text=resp.choices[0].message.content or "",
            model=self._model,
            prompt_tokens=getattr(u, "prompt_tokens", 0),
            completion_tokens=getattr(u, "completion_tokens", 0),
            total_tokens=getattr(u, "total_tokens", 0),
        )


_REGISTRY: dict[str, type[CoachLLM]] = {}


def _registry() -> dict[str, type[CoachLLM]]:
    if not _REGISTRY:
        _REGISTRY["openai"] = OpenAICoachLLM
        _REGISTRY["gemini"] = GeminiCoachLLM
        _REGISTRY["litellm"] = LiteLLMCoachLLM
    return _REGISTRY


@lru_cache
def _build(name: str) -> CoachLLM:
    reg = _registry()
    if name not in reg:
        raise ValueError(f"알 수 없는 코치 LLM: '{name}'. 사용 가능: {list(reg.keys())}")
    return reg[name]()


def get_coach_llm(name: str | None = None) -> CoachLLM:
    return _build((name or get_settings().coach_llm).lower())
