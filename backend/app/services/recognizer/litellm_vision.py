"""
LiteLLM(Claude) 경유 식단 인식기.

Claude 비전 모델에 음식 사진을 주고 JSON 으로 분석받습니다.
LiteLLM 이 OpenAI 호환이므로, OpenAI SDK 의 vision 형식(base64 image_url)을 사용합니다.
결과는 Gemini 인식기와 동일한 DietAnalysis 로 변환 → 프론트 계약 동일.

기존 PoC 방향(전문 영양사 + 고혈압 DASH 관점 + 나트륨·당류) 계승.
"""
from __future__ import annotations

import base64
import json
import math
import re
import time

from app.core.config import get_settings
from app.schemas.diet import DietAnalysis, RecognizedFood
from app.services.recognizer.base import FoodRecognizer

_PROMPT = """당신은 전문 영양사입니다. 이 음식 사진을 분석해 아래 JSON 스키마로만 응답하세요.
설명, 마크다운, 코드블록 없이 순수 JSON만 출력합니다.

{
  "foods": [
    {"name":"음식명(한국어)","calories":정수kcal,"carbs_g":탄수화물g,"protein_g":단백질g,"fat_g":지방g,"sodium_mg":정수mg,"sugar_g":정수g,"confidence":0.0~1.0}
  ],
  "coach_comment": "고혈압(DASH) 관점 식단평. 나트륨 높은 음식을 짚고 개선 제안을 2~3문장 한국어로."
}
음식이 여러 개면 foods 에 모두. 모르는 값은 null. 나트륨·당류를 신중히 추정하세요."""


class LiteLLMVisionRecognizer(FoodRecognizer):
    name = "claude"  # LiteLLM 뒤의 Claude 비전 모델

    def __init__(self) -> None:
        s = get_settings()
        if not s.litellm_api_key:
            raise RuntimeError("LITELLM_API_KEY(Virtual Key) 가 설정되지 않았습니다.")
        from openai import OpenAI
        # 타임아웃을 둬서 지연 응답이 작업 스레드를 오래 점유하지 않게 함
        self._client = OpenAI(
            api_key=s.litellm_api_key, base_url=f"{s.litellm_base_url}/v1", timeout=60.0
        )
        self._model = s.litellm_vision_model

    async def recognize(self, image_bytes: bytes, mime_type: str) -> DietAnalysis:
        import asyncio
        start = time.perf_counter()
        b64 = base64.b64encode(image_bytes).decode()
        data_url = f"data:{mime_type};base64,{b64}"

        resp = await asyncio.to_thread(
            self._client.chat.completions.create,
            model=self._model,
            messages=[{
                "role": "user",
                "content": [
                    {"type": "text", "text": _PROMPT},
                    {"type": "image_url", "image_url": {"url": data_url}},
                ],
            }],
            temperature=0.2,
        )
        latency_ms = int((time.perf_counter() - start) * 1000)
        raw = resp.choices[0].message.content or ""
        return self._parse(raw, latency_ms)

    def _parse(self, raw: str, latency_ms: int) -> DietAnalysis:
        # Claude 가 코드블록(```json ... ```)으로 감쌀 수 있어 앞부분 펜스만 정확히 제거
        text = raw.strip()
        # 선행 ```lang 펜스와 후행 ``` 만 제거 (본문의 'json' 은 건드리지 않음)
        text = re.sub(r"^```[a-zA-Z]*\s*", "", text)
        text = re.sub(r"\s*```$", "", text).strip()
        foods: list[RecognizedFood] = []
        coach = ""
        try:
            data = json.loads(text)
            coach = str(data.get("coach_comment", "") or "")
            for f in data.get("foods", []):
                foods.append(RecognizedFood(
                    name=str(f.get("name", "알 수 없음")),
                    calories=_i(f.get("calories")), sodium_mg=_i(f.get("sodium_mg")),
                    carbs_g=_macro_f(f.get("carbs_g")),
                    protein_g=_macro_f(f.get("protein_g")),
                    fat_g=_macro_f(f.get("fat_g")), sugar_g=_i(f.get("sugar_g")),
                    confidence=_f(f.get("confidence")),
                ))
        except (json.JSONDecodeError, AttributeError):
            pass
        return DietAnalysis(
            engine=self.name, foods=foods, coach_comment=coach,
            latency_ms=latency_ms, raw_model_output=raw,
        ).compute_totals()


def _i(v):
    if v is None:
        return None
    try:
        return int(round(float(v)))
    except (TypeError, ValueError):
        return None


def _f(v):
    if v is None:
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def _macro_f(v):
    if v is None:
        return None
    try:
        value = float(v)
    except (TypeError, ValueError):
        return None
    return value if math.isfinite(value) and value >= 0 else None
