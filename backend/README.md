# On-Care Backend (프론트 계약 정렬 재작업판)

> 프론트엔드(Flutter)의 `LocalApiInterceptor` 를 **정답 계약**으로 삼아 백엔드를 맞춥니다.
> 계약 전체는 `API_CONTRACT.md` 참조.

## 재작업 로드맵
- **STEP 0** ✅ API 계약 명세 (API_CONTRACT.md)
- **STEP 1** ✅ 골격 재구성: /v1 prefix · 문자열 id · snake_case · 시스템 엔드포인트 · DB/Docker
- **STEP 2** ✅ 사용자/인증: /users/me, /users/me/health (토큰→유저 / 무토큰→데모 폴백)
- **STEP 3** ✅ 식단: /diet/days/today + POST /diet/analyze (Gemini, DASH/나트륨·당류 관점, 엔진 교체 가능)
- **STEP 4** ✅ 운동: /exercise/weeks/current + POST /exercise/sessions (요일별/타입별 집계, streak, 주간 코칭)
- **STEP 5** ✅ 바이탈: /vitals/{weight|blood-pressure|blood-sugar} + /vitals/{kind}/latest (→ /users/me/health indicators 자동 연결)
- **STEP 6** ✅ 일정/알림/장소/AI코치: /schedule/events · /notifications · /places/nearby · /ai-coach/feedback (도메인별 코치 분리, RAG 진입점)
- **STEP 7** ✅ RAG 코치: 임베더/LLM factory(교체 가능), 개인·공공 문서 격리, 도메인 필터, 청킹(설정값), 토큰 기록, 규칙 기반 폴백, 적재/재임베딩 스크립트

## STEP 1 에서 동작하는 것
- `GET /v1/ping` · `GET /v1/healthz` · `GET /v1/version` — 프론트 계약과 정확히 일치
- 테이블 생성 (프론트 drift 스키마 정렬: diet_entries 에 sodium_mg/sugar_g 포함) — 베이스라인 9테이블(places 포함), 이후 마이그레이션으로 현재 12테이블(social_accounts·food_nutrients·audit_logs 추가)
- 사용자 id = 문자열, 데모 유저 'user-demo'(김민수) 시드

## 실행
```bash
cp .env.example .env          # JWT_SECRET 교체
docker compose up --build
```
→ http://localhost:8000/docs  (경로는 모두 /v1/...)

## DB 마이그레이션 (Alembic)
스키마는 **Alembic 마이그레이션**으로 관리합니다(베이스라인: `migrations/versions/0001_baseline.py`, 9테이블 + pgvector; 이후 마이그레이션으로 현재 12테이블).
DB URL 은 `.env` 의 `DATABASE_URL` 을 그대로 사용합니다(`migrations/env.py` 가 app 설정에서 읽음).

```bash
cd backend
alembic upgrade head          # 최신 스키마로 반영 (운영/CI 는 이 명령으로 스키마 생성)
alembic revision --autogenerate -m "설명"   # 모델 변경 후 새 마이그레이션 생성
alembic downgrade -1          # 한 단계 롤백
```
> 개발 편의를 위해 앱 기동 시 `create_all()` 로도 테이블을 만들지만(멱등), **운영은 `alembic upgrade head`** 를 정답으로 삼습니다.
> (운영에서 `create_all` 을 끄려면 `AUTO_CREATE_TABLES=false` — 설정 항목은 이후 커밋에서 추가)

## RAG (pgvector + Gemini)
공공문서 적재 → pgvector 검색 → 근거 코칭까지의 로컬 셋업·재현 절차는 **[docs/rag_gemini_setup.md](docs/rag_gemini_setup.md)** 참고.
임베딩 `gemini-embedding-001`(768) · 코치/인식 `gemini-flash-latest` · `.env`: `EMBEDDER=gemini`, `EMBED_DIM=768`.
검증: `python -m scripts.check_gemini` · `/v1/ai-coach/chat` 응답의 `sources` 가 채워지면 RAG 가 실제로 동작(규칙 폴백 아님).

## 프론트 연동 (실서버 전환)
프론트에서:
```bash
flutter run --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=http://localhost:8000/v1
```
(LocalApiInterceptor 가 꺼지고 실제 /v1 서버로 요청)

## 준비물
- Docker Desktop (무료, 가입 없음)
- (STEP 3~) Gemini / OpenAI 키

## 식단 인식 실제 예시 (Diet Analysis PoC — live output)

식단 인식은 인식 엔진을 교체할 수 있습니다(factory 구조).
현재 Gemini 무료 티어가 지역에서 회수되어(quota=0) 라이브 호출이 막혔으므로,
**LiteLLM Virtual Key 를 통해 Claude 비전 모델로 우회**하여 라이브 호출을 확인했습니다.
Gemini 키가 확보되면 `.env` 의 `RECOGNIZER=gemini` 로 즉시 전환 가능합니다.

**설정 (.env)**
```
RECOGNIZER=claude
COACH_LLM=litellm
LITELLM_BASE_URL=http://<litellm-host>:4000
LITELLM_API_KEY=<Virtual Key>          # gitignored
LITELLM_VISION_MODEL=claude-haiku-4-5-20251001
```

**요청**
```
POST /v1/diet/analyze   (multipart: image=<음식 사진>, meal_type=lunch)
```

**응답 (engine=claude, 실제 호출 결과)**
```json
{
  "entry_id": "diet-c62ce45833ba",
  "analysis": {
    "engine": "claude",
    "foods": [
      {"name": "혼합 견과류 및 건포도", "calories": 180, "sodium_mg": 95, "sugar_g": 15, "confidence": 0.75},
      {"name": "오이 및 채소 샐러드", "calories": 35, "sodium_mg": 45, "sugar_g": 3, "confidence": 0.85},
      {"name": "치즈(옐로우)", "calories": 110, "sodium_mg": 190, "sugar_g": 1, "confidence": 0.7},
      {"name": "과일 음료", "calories": 95, "sodium_mg": 25, "sugar_g": 22, "confidence": 0.65}
    ],
    "total_calories": 420,
    "total_sodium_mg": 355,
    "total_sugar_g": 41,
    "coach_comment": "치즈의 높은 나트륨(190mg)이 주의 대상입니다. DASH 식단 관점에서 저나트륨 치즈로 교체하거나 양을 줄이고, 과일 음료의 당류(22g)도 물이나 무가당 음료로 대체하는 것을 권장합니다. 신선한 채소 샐러드는 훌륭한 선택이므로 이를 더 늘리면 좋습니다."
  }
}
```

인식 엔진 선택: `RECOGNIZER=claude`(LiteLLM) | `gemini` | `yolo`(비교실험용 스텁).
엔진을 바꿔도 응답 형식(DietAnalysis)은 동일하므로 프론트는 영향받지 않습니다.
