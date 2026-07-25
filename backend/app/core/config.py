"""환경 설정. .env 에서 읽어옵니다."""
from __future__ import annotations

from functools import lru_cache

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# 개발 기본 시크릿(운영에서 그대로 쓰면 기동 차단)
DEFAULT_JWT_SECRET = "CHANGE_ME_dev_only_secret_key_please_replace_in_prod"
# 데모 계정(트레이너/회원 시드) 기본 로그인 비밀번호. 운영에서 데모 시드를 켜려면
# 반드시 이 기본값이 아닌 안전한 값으로 바꿔야 한다(아래 _guard_prod_secrets 가 강제).
DEFAULT_DEMO_PASSWORD = "oncare123"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # --- 환경 ---
    env: str = "dev"  # dev | staging | prod

    # --- API ---
    api_v1_prefix: str = "/v1"
    app_version: str = "0.4.0"

    # --- Database ---
    database_url: str = "postgresql+psycopg://oncare:oncare@localhost:5432/oncare"
    # 앱 기동 시 create_all() 로 테이블 생성 여부(개발 편의). 운영은 Alembic 을 정답으로 → false 권장.
    auto_create_tables: bool = True

    # --- JWT ---
    jwt_secret: str = DEFAULT_JWT_SECRET
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24
    refresh_token_expire_days: int = 30
    # 토큰 없이 접근 시 데모 사용자로 폴백(개발 편의). 운영(prod)에서는 항상 비활성.
    allow_demo_fallback: bool = True

    # --- AI 엔진 ---
    recognizer: str = "gemini"        # gemini | claude(litellm) | yolo
    # 인식 후 공공 식품영양성분 DB 로 영양 수치 보강(정확도↑). 순수 LLM 비교실험 시 false.
    nutrition_db_enrich: bool = True
    gemini_api_key: str = ""
    gemini_model: str = "gemini-flash-latest"  # 챗·인식 공용. 핀 버전은 은퇴로 404 → latest 별칭 사용
    coach_llm: str = "gemini"         # openai | gemini | litellm
    openai_api_key: str = ""
    openai_chat_model: str = "gpt-4o"
    embedder: str = "gemini"          # openai | gemini | litellm
    openai_embed_model: str = "text-embedding-3-small"

    # --- LiteLLM 프록시 (OpenAI 호환) ---
    # 하나의 Virtual Key 로 뒤의 여러 모델(claude 등)을 호출.
    # base_url 을 넣으면 OpenAI SDK 가 이 프록시를 바라봄.
    litellm_base_url: str = ""
    litellm_api_key: str = ""                       # Virtual Key
    litellm_chat_model: str = "claude-sonnet-4-6"   # 코치/인식용 채팅 모델
    litellm_embed_model: str = ""                   # 프록시에 임베딩 모델 있으면 지정
    litellm_vision_model: str = "claude-sonnet-4-6" # 식단 인식(이미지)용

    # --- RAG (STEP 7) ---
    # 임베딩 차원: 모델에 맞춰 바꿉니다. 바꾸면 재임베딩 필요(scripts/reembed).
    #   Gemini gemini-embedding-001        = 768 (현재 기본, EMBEDDER=gemini)
    #   OpenAI text-embedding-3-small/large = 1536 / 3072 (EMBEDDER=openai 시 EMBED_DIM=1536)
    embed_dim: int = 768
    # 청킹: 윈도우(문장 수)와 겹침(stride 보정). 최적값 찾으면 여기만 수정.
    chunk_window: int = 5      # 한 청크에 묶을 문장 수
    chunk_overlap: int = 1     # 청크 간 겹칠 문장 수
    # 검색: 개인 문서 / 공공 문서 각각 top-k
    retrieve_personal_k: int = 3
    retrieve_public_k: int = 3
    # 식단/바이탈 기록 시 개인 RAG 문서 자동 적재(코치가 내 최근 데이터를 검색하도록)
    rag_auto_ingest: bool = True

    # --- 기타 ---
    cors_allow_origins: str = "http://localhost:3000,http://localhost:5173,http://127.0.0.1:3000"
    seed_demo_data: bool = True
    # 데모 계정(트레이너/회원 시드) 로그인 비밀번호. 운영에서 데모 계정에 데이터를 담아
    # 두고 싶으면 이 값을 안전하게 설정한다(기본값이면 운영 기동 차단).
    demo_login_password: str = DEFAULT_DEMO_PASSWORD
    # 관리자 이메일(콤마구분) — 기동 시 해당 사용자를 is_admin=True 로 승격
    admin_emails: str = ""

    # --- 운영 배포 하드닝 ---
    force_https: bool = False       # HTTP→HTTPS 리다이렉트(프록시 뒤면 X-Forwarded-Proto 신뢰)
    security_headers: bool = True   # 보안 응답 헤더(HSTS·nosniff·frame deny 등)

    # --- Rate limit (인증 엔드포인트 브루트포스 방어) ---
    rate_limit_enabled: bool = True
    rate_limit_auth_per_minute: int = 10  # IP·엔드포인트당 분당 시도 한도

    @property
    def admin_email_set(self) -> set[str]:
        return {e.strip().lower() for e in self.admin_emails.split(",") if e.strip()}

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_allow_origins.split(",") if o.strip()]

    @property
    def is_cors_wildcard(self) -> bool:
        return "*" in self.cors_origin_list

    @property
    def is_prod(self) -> bool:
        return self.env.strip().lower() in ("prod", "production")

    @property
    def demo_fallback_enabled(self) -> bool:
        """데모 사용자 폴백 허용 여부 — 운영에서는 설정과 무관하게 항상 비활성."""
        return self.allow_demo_fallback and not self.is_prod

    @model_validator(mode="after")
    def _guard_prod_secrets(self) -> "Settings":
        """운영 환경에서 안전하지 않은 기본값을 쓰면 기동을 막는다(fail-fast)."""
        if self.is_prod:
            if not self.jwt_secret or self.jwt_secret == DEFAULT_JWT_SECRET:
                raise ValueError(
                    "운영(env=prod)에서는 JWT_SECRET 을 안전한 값으로 반드시 설정해야 합니다."
                )
            if self.is_cors_wildcard:
                raise ValueError(
                    "운영(env=prod)에서는 CORS 허용 출처를 명시해야 합니다(와일드카드 '*' 금지)."
                )
            # 운영에서 데모 시드를 켜면 트레이너/회원 데모 계정이 생성된다. 약한 기본
            # 비밀번호가 그대로 운영 자격증명이 되는 것을 막는다(강한 값 강제, 아니면 시드 끄기).
            if self.seed_demo_data and self.demo_login_password == DEFAULT_DEMO_PASSWORD:
                raise ValueError(
                    "운영(env=prod)에서 데모 시드(SEED_DEMO_DATA=true)를 켜려면 "
                    "DEMO_LOGIN_PASSWORD 를 안전한 값으로 설정해야 합니다(또는 SEED_DEMO_DATA=false)."
                )
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
