"""코치 LLM 공통 인터페이스. 토큰 사용량 기록(모델 비교용)."""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class LLMResult:
    text: str
    model: str
    prompt_tokens: int = 0
    completion_tokens: int = 0
    total_tokens: int = 0
    extra: dict = field(default_factory=dict)


class CoachLLM(ABC):
    name: str = "base"

    @abstractmethod
    def generate(
        self,
        system_prompt: str,
        user_prompt: str,
        *,
        json_mode: bool = False,
        thinking_budget: int | None = None,
    ) -> LLMResult:
        """텍스트 생성.

        선택 인자는 **구조화된 짧은 출력**을 요구하는 호출부(추천·루틴 옵션 등)를
        위한 것이다. 기본값은 기존 동작 그대로라 산문 응답(챗봇)은 영향받지 않는다.

        - `json_mode`: 응답을 JSON 으로 강제(지원하지 않는 구현은 무시).
        - `thinking_budget`: 사고 토큰 상한. Gemini 계열은 기본적으로 사고가 켜져
          있어 짧은 JSON 하나를 뽑는 데도 10초 이상 걸린다. 작은 값을 주면 체감
          지연이 크게 준다(실측: 12.9s → 1.5s). 지원하지 않는 구현은 무시한다.
        """
        raise NotImplementedError
