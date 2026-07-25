# 백엔드 배포 가이드 — AWS App Runner + RDS(pgvector)

컨테이너 + Postgres(pgvector) 구조라 **App Runner + RDS PostgreSQL** 조합을 권장한다
(HTTPS 자동, 운영 부담 최소). CI 는 `main` push 시 이미지를 ECR 에 올리고 App Runner 를
재배포한다(`.github/workflows/backend-deploy.yml`).

```
GitHub(main push) ──> Actions ──> ECR(이미지) ──> App Runner(:8000, /v1/healthz)
                                                        │
                                                        └── RDS PostgreSQL 15+ (CREATE EXTENSION vector)
```

기동 흐름: 컨테이너가 `scripts/start.sh` 로 **마이그레이션 → uvicorn(--proxy-headers)**.
마이그레이션은 `scripts/migrate.py` 가 **PostgreSQL advisory lock 으로 직렬화**하므로, App Runner
가 여러 인스턴스를 동시에 띄워도 하나만 마이그레이션하고 나머지는 대기 후 no-op 이다(리뷰 #3).
운영은 `AUTO_CREATE_TABLES=false` 로 두고 Alembic 을 스키마의 유일한 소스로 삼는다.

**배포 게이팅**: `.github/workflows/backend-deploy.yml` 은 **"Backend CI" 가 성공**했을 때만
(workflow_run) 실행되어, 테스트/마이그레이션 실패 커밋이 운영에 배포되지 않는다. Backend CI 는
`alembic heads` 가 **정확히 1개**인지 검사해 마이그레이션 head 분기(선형화 누락)를 막는다.

---

## 1) ECR 리포지토리

```bash
aws ecr create-repository --repository-name oncare-backend --region ap-northeast-2
```

## 2) RDS PostgreSQL (pgvector)

- 엔진: PostgreSQL **15.2+** (pgvector 지원 버전). 보안그룹은 App Runner VPC 커넥터에서 5432 허용.
- 생성 후 pgvector 확장 1회:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

- `DATABASE_URL` 형식: `postgresql+psycopg://<user>:<pass>@<rds-endpoint>:5432/<db>`

## 3) 환경변수 / Secrets (App Runner)

| 키 | 값/설명 |
|---|---|
| `ENV` | `prod` (fail-fast 하드닝 활성) |
| `JWT_SECRET` | `openssl rand -hex 32` (기본값이면 기동 거부) |
| `DATABASE_URL` | 위 RDS 접속 문자열 |
| `AUTO_CREATE_TABLES` | `false` (Alembic 이 정답) |
| `CORS_ALLOW_ORIGINS` | GitHub Pages 도메인 (예: `https://ewhasudo.zapto.org`) |
| `TZ` | `Asia/Seoul` (오늘/어제 라벨 KST 기준) |
| `SEED_DEMO_DATA` | 운영 권장 `false`. 데이터 든 데모 계정을 두려면 `true` + `DEMO_LOGIN_PASSWORD` 필수 |
| `DEMO_LOGIN_PASSWORD` | `SEED_DEMO_DATA=true` 일 때 12자+ 강한 값(아니면 기동 거부) |
| `GEMINI_API_KEY` 또는 LiteLLM(`LITELLM_*`) | 식단 인식/코치. 없으면 stub 폴백 |
| `KAKAO_REST_API_KEY` | 장소(O2O) 실검색. 없으면 시드 폴백. `PLACES_PROVIDER=auto` 기본 |

> 참고: 키가 없어도 인식/장소는 폴백으로 동작(기동은 됨). 운영 시크릿은 Secrets Manager/SSM 에 두고
> App Runner 에 주입한다.

## 4) App Runner 서비스

- 소스: ECR 이미지(`oncare-backend:latest`), 포트 `8000`.
- 헬스체크: HTTP `GET /v1/healthz`.
- 환경변수: 위 표(민감값은 Secrets 참조).
- 자동배포: ECR `:latest` push 시 재배포(또는 CI 의 `start-deployment` 로 트리거).
- 컨테이너가 기동 시 마이그레이션을 수행하므로 별도 마이그레이션 스텝 불필요.

## 5) CI 용 GitHub Secrets

- `AWS_DEPLOY_ROLE_ARN` — GitHub OIDC 로 assume 하는 IAM 역할(ECR push + `apprunner:StartDeployment`).
- `APPRUNNER_SERVICE_ARN` — 배포 대상 App Runner 서비스 ARN.

## 6) 프론트 연결

```bash
flutter build web --release \
  --dart-define=USE_MOCK_API=false \
  --dart-define=API_BASE_URL=https://<apprunner-domain>/v1
```

지도 핀은 프론트 카카오맵 **JS SDK**(JS키 + 도메인 등록) 담당. 백엔드는 좌표+정보만 제공한다.

---

## ⚠️ 마이그레이션 head 선형화 (머지 순서 주의)

트레이너 도메인 마이그레이션(`0010_trainer_domain`)과 `backend-diet-macros`의
`0010_diet_entry_macros` 가 **둘 다 0009 에서 분기**한다. 둘 다 머지되면 Alembic head 가
2개가 되어 `alembic upgrade head` 가 실패한다.

**나중에 머지되는 쪽**이 자기 마이그레이션의 `down_revision` 을 상대 head 로 바꿔 선형화한다
(1줄 + 파일명 `0011_` 정리). 예: diet-macros 가 먼저 머지되면 트레이너 마이그레이션을
`down_revision = "0010_diet_entry_macros"` 로.

---

## 대안 — 저비용 EC2 (수동)

`docker-compose.yml` 거의 그대로 EC2 1대에 올리고 Nginx + Let's Encrypt 로 HTTPS.
가장 저렴하지만 HTTPS/DB백업/재시작을 직접 관리해야 한다.
