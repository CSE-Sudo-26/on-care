"""
Gemini 임베딩기 (gemini-embedding-001). 모델 교체 옵션.

gemini-embedding-001 은 기본 3072차원이지만 output_dimensionality 로 축소 가능(Matryoshka).
EMBED_DIM(기본 768)에 맞춰 요청한다. rag 검색은 cosine 거리(스케일 불변)라 별도 정규화 불필요.
차원을 바꾸면 coach_documents 재생성 + 재임베딩 필요.
"""
from __future__ import annotations

from app.core.config import get_settings
from app.services.embedder.base import Embedder


class GeminiEmbedder(Embedder):
    name = "gemini"

    def __init__(self) -> None:
        s = get_settings()
        if not s.gemini_api_key:
            raise RuntimeError("GEMINI_API_KEY 가 설정되지 않았습니다.")
        from google import genai
        from google.genai import types
        # HTTP 타임아웃을 반드시 건다(#1545). 없으면 provider 가 응답하지 않을 때
        # 호출이 무기한 매달리는데, 개인 문서 교체는 advisory lock 을 쥔 채
        # 임베딩을 부르므로 DB connection 과 잠금까지 함께 묶인다 — 지연이 요청
        # 하나로 끝나지 않고 pool 고갈로 번진다. 챗·인식 client 와 같은 설정값을
        # 쓴다(`coach/llm.py`).
        self._client = genai.Client(
            api_key=s.gemini_api_key,
            http_options=types.HttpOptions(
                timeout=int(s.gemini_timeout_seconds * 1000)  # SDK 는 밀리초
            ),
        )
        self._types = types
        self._model = "gemini-embedding-001"
        self.dim = s.embed_dim

    def embed(self, texts: list[str]) -> list[list[float]]:
        if not texts:
            return []
        out: list[list[float]] = []
        # Gemini 임베딩 API 는 건별 호출이 단순(배치도 가능하나 호환 위해 건별)
        for t in texts:
            r = self._client.models.embed_content(
                model=self._model, contents=t,
                config=self._types.EmbedContentConfig(output_dimensionality=self.dim),
            )
            out.append(list(r.embeddings[0].values))
        return out
