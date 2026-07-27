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
배포 잡은 `concurrency` 로 한 번에 하나만 돌고, `start-deployment` 후 App Runner 상태와
`/v1/healthz` 를 폴링해 **실제 배포·기동 성공까지 확인**한 뒤 워크플로우를 통과시킨다.

> ⚠️ **수동 실행 주의**: `workflow_dispatch` 로 수동 트리거하면 **CI 성공 게이트를 우회**해
> 현재 ref 를 그대로 배포한다(리포 write 권한자만 가능). 최초 배포/긴급 롤백 용도로만 쓰고,
> 반드시 로컬에서 `alembic upgrade head` + `pytest` 를 통과시킨 커밋에서만 사용한다.

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

- 소스: ECR 이미지, 포트 `8000`. CI 는 매 배포마다 **커밋 SHA 태그** 이미지(`oncare-backend:<sha>`)와
  `:latest` 를 함께 push 한다.
- **배포 방식(권장)**: CI 가 push 직후 `start-deployment` 로 트리거하고 완료·헬스까지 확인한다.
  App Runner 자동배포를 `:latest` 로 켜두면 **다른 push 가 먼저 `:latest` 를 덮을 때 CI 통과 SHA 가
  아닌 이미지가 나갈 수 있으므로**, 정확성이 중요하면 App Runner 소스 이미지를 `:latest` 대신
  **커밋 SHA 태그(또는 digest)** 로 지정하고 CI 가 그 이미지 식별자를 갱신하도록 두는 편이 안전하다.
- 헬스체크: HTTP `GET /v1/healthz`.
- 환경변수: 위 표(민감값은 Secrets 참조).
- 컨테이너가 기동 시 마이그레이션을 수행하므로 별도 마이그레이션 스텝 불필요.

## 5) CI 용 GitHub Secrets & IAM 역할

- `AWS_DEPLOY_ROLE_ARN` — GitHub OIDC 로 assume 하는 IAM 역할. 필요 권한: ECR push
  (`ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`,
  `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`) + `apprunner:StartDeployment`,
  `apprunner:DescribeService`.
- `APPRUNNER_SERVICE_ARN` — 배포 대상 App Runner 서비스 ARN.
- **App Runner ECR 액세스 역할(별도)**: App Runner 가 **private ECR 에서 이미지를 pull** 하려면
  서비스의 `AuthenticationConfiguration.AccessRoleArn` 에 지정하는 IAM 역할이 필요하다.
  신뢰 주체 `build.apprunner.amazonaws.com`, 정책은 `ecr:GetAuthorizationToken`(리소스 `*`) +
  `ecr:BatchGetImage`·`ecr:GetDownloadUrlForLayer`·`ecr:BatchCheckLayerAvailability`·`ecr:DescribeImages`
  (해당 리포 리소스). 이 역할이 없으면 배포/기동 시 이미지 pull 이 실패한다.

## 6) 프론트 연결

```bash
flutter build web --release \
  --dart-define=USE_MOCK_API=false \
  --dart-define=API_BASE_URL=https://<apprunner-domain>/v1
```

지도 핀은 프론트 카카오맵 **JS SDK**(JS키 + 도메인 등록) 담당. 백엔드는 좌표+정보만 제공한다.

---

## 마이그레이션 head 선형화 (머지 순서 주의)

병렬 브랜치가 같은 부모에서 각자 새 마이그레이션을 만들면 Alembic head 가 여러 개가 되어
`alembic upgrade head` 가 실패한다. 현재는 아래처럼 **단일 선형 체인**으로 정리돼 있다:

```
0009_diet_idempotency_key → 0010_diet_entry_macros(#207) → 0011_health_daily_sugar_g(#231)
                          → 0012_trainer_domain(트레이너 스택)
```

**원칙**: 나중에 머지되는 마이그레이션의 `down_revision` 을 현재 main head 로 맞춰 한 줄로 잇는다
(파일명 숫자도 위치에 맞게). 트레이너 스택은 위 순서대로 **가장 마지막**에 머지한다.

> 단, **한쪽 브랜치가 이미 staging/production DB 에 적용된 뒤**라면 위 "down_revision 만 바꾸기"를
> 쓰면 안 된다. 먼저 `alembic current` 로 그 DB 의 현재 revision 을 확인하고, 이미 적용된 경우
> `alembic merge` 로 병합 revision 을 만들거나 실제 적용 상태에 맞춰 head 를 선형화한다.
> CI 의 single-head 검사(`alembic heads` == 1)로 분기 재발을 막는다.

---

## 대안 — 저비용 EC2 (수동)

`docker-compose.yml` 거의 그대로 EC2 1대에 올리고 Nginx + Let's Encrypt 로 HTTPS.
가장 저렴하지만 HTTPS/DB백업/재시작을 직접 관리해야 한다.
