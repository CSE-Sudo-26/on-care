# 로컬 풀스택 실행 (백엔드 + 회원 앱 + 트레이너 웹)

회원 앱(모바일)과 트레이너 웹을 **같은 백엔드·같은 DB** 로 띄우는 절차입니다. 회원↔트레이너 상호작용
(회원이 올린 식단을 트레이너가 보는 것 등)은 이 구성에서만 확인할 수 있습니다.

> 둘 다 `useMockApi` 기본값이 `true` 입니다. dart-define 없이 실행하면 각각
> **자기 로컬 drift DB** 를 보기 때문에, 둘 다 잘 도는 것처럼 보여도 서로의
> 데이터는 절대 보이지 않습니다. 상호작용을 확인하려면 아래 3단계를 모두 거쳐야 합니다.

## 1. 백엔드

```bash
cd backend
cp .env.example .env          # JWT_SECRET 은 openssl rand -hex 32 로 교체 권장
docker compose up -d --build
```

→ http://localhost:8000/docs (모든 경로는 `/v1/...`)

AI 키는 없어도 됩니다. `GEMINI_API_KEY` 가 비어 있으면 식단 인식이 오프라인 스텁으로
폴백해서 `/v1/diet/analyze` 가 그대로 동작합니다(CI 와 같은 경로).

### 기동에 실패하면: 오래된 볼륨

예전에 만들어 둔 `oncare_pgdata` 볼륨이 있으면 다음처럼 죽습니다.

```
alembic ... Running upgrade -> 0001_baseline
psycopg.errors.DuplicateTable: relation "users" already exists
```

`create_all()` 로 만들어진 스키마가 남아 있는데 `alembic_version` 이 없어서, 마이그레이션이
baseline 부터 다시 돌다 충돌하는 것입니다. 로컬 개발 DB 라 버리고 다시 만들면 됩니다.

```bash
docker compose down -v        # 볼륨 삭제 — 로컬 데이터가 사라집니다
docker compose up -d
```

확인:

```bash
docker compose ps             # app, db 모두 Up
docker compose logs app       # alembic upgrade 성공 후 uvicorn 기동
```

## 2. 회원 앱 (모바일)

로컬 검증은 Chrome 으로 띄우는 편이 빠릅니다. 실제 배포 타깃은 iOS/Android 입니다.


```bash
cd frontend/flutter
flutter run -d chrome \
  --dart-define=USE_MOCK_API=false \
  --dart-define=API_BASE_URL=http://localhost:8000/v1
```

## 3. 트레이너 웹

```bash
cd frontend/flutter_trainer
bash tool/fetch_drift_wasm.sh   # 최초 1회
flutter run -d chrome \
  --dart-define=USE_MOCK_API=false \
  --dart-define=API_BASE_URL=http://localhost:8000/v1
```

## 데모 계정

`SEED_DEMO_DATA=true`(기본값)면 시드 계정이 생성됩니다. 비밀번호는 모두
`.env` 의 `DEMO_LOGIN_PASSWORD`(기본 `oncare123`)입니다.

| 역할 | 이메일 | 비고 |
| --- | --- | --- |
| 트레이너 | `trainer@oncare.com` | 담당 회원 3명 |
| 회원 | `jisu@oncare.com` | 이지수 |
| 회원 | `sungho@oncare.com` | 박성호 |
| 회원 | `minsu@oncare.com` | 김민수 — **현재 로그인 불가**, 아래 참고 |

> `minsu@oncare.com`(user-demo)은 `init_db` 가 빈 비밀번호 해시로 먼저 만들고
> 트레이너 시드가 기존 사용자를 건너뛰기 때문에 로그인할 수 없습니다. 하필 트레이너의
> 1번 고객이라 시연 계정으로 쓰기 쉬운데, 지금은 **`jisu@oncare.com` 을 쓰세요.**

## 상호작용이 실제로 연결됐는지 확인

클라이언트 없이 API 로만 30초 안에 확인할 수 있습니다. 회원이 올린 식단이 트레이너 쪽에
나타나면 둘이 같은 DB 를 보고 있다는 뜻입니다.

```bash
M=$(curl -s -X POST http://localhost:8000/v1/auth/login \
      -d "username=jisu@oncare.com&password=oncare123" \
    | python -c "import sys,json;print(json.load(sys.stdin)['access_token'])")
T=$(curl -s -X POST http://localhost:8000/v1/auth/login \
      -d "username=trainer@oncare.com&password=oncare123" \
    | python -c "import sys,json;print(json.load(sys.stdin)['access_token'])")

# 회원이 메시지를 보내면
curl -s -X POST http://localhost:8000/v1/me/coach/chat \
  -H "Authorization: Bearer $M" -H "Content-Type: application/json" \
  -d '{"text":"hello from member"}'

# 트레이너 스레드에 그대로 나타난다
curl -s -H "Authorization: Bearer $T" \
  http://localhost:8000/v1/trainer/clients/user-jisu/chat
```

로그인은 `OAuth2PasswordRequestForm` 이라 **JSON 이 아니라 폼 데이터**(`username=`)로
보냅니다. 이메일을 `username` 필드에 넣습니다.

### 전 경로 한 번에 훑기

위 확인은 채팅 하나만 봅니다. 46개 경로(식단·운동·채팅·로스터·예약·상담)를 한 번에
훑으려면:

```bash
cd backend
python -m scripts.e2e_sweep
```

통과/실패를 그룹별로 출력하고, 실패가 있으면 마지막에 목록으로 모아 줍니다. 그 목록만
화면으로 확인하면 됩니다.

만든 것은 모두 되돌립니다 — 식단·운동 세션은 삭제, 건강 목표는 원래 값으로 복구,
채팅은 DB 에서 제거합니다(채팅에는 삭제 API 가 없습니다). 몇 번을 돌려도 데모 DB 가
그대로라, 위 "알려진 함정" 의 pytest 문제도 생기지 않습니다. 정리에 실패하면 조용히
넘어가지 않고 `정리` 항목이 FAIL 로 뜹니다.

데이터를 쓰고 지우므로 기본은 로컬 `--base` 만 허용합니다. `--allow-remote` 로 배포
대상을 가리키면 **채팅은 남습니다** — 채팅 정리만 로컬 `DATABASE_URL` 을 쓰기
때문입니다. 배포 환경에 쓰는 것은 권하지 않습니다.

AI 코칭·루틴 생성은 이 스윕에서 제외했습니다. `GEMINI_API_KEY` 가 없으면 규칙 폴백이
200 을 돌려주어 **통과처럼 보이기** 때문입니다(#579 수정 후 #589 에서 검증).

## 알려진 함정

- **Windows(Git Bash)에서 `curl -F "image=@/tmp/x.jpg"`** 는 `curl: (26)` 로 실패합니다.
  Windows `curl.exe` 가 MSYS 경로를 못 읽습니다. `$(cygpath -w /tmp/x.jpg)` 로 변환하세요.
- **셸에서 한글이 든 JSON 을 `-d` 로 보내면** 콘솔 인코딩(cp949) 때문에 깨져
  `400 There was an error parsing the body` 가 납니다. 파일(`-d @body.json`)로 보내거나
  ASCII 로 확인하세요. 회원 앱·트레이너 웹이 보내는 요청은 정상입니다.
- CORS 는 `.env` 기본값이 `CORS_ALLOW_ORIGINS=*` 라 로컬 웹에서 그대로 붙습니다.
- **백엔드 테스트 스위트가 이 DB 를 그대로 씁니다**(`DATABASE_URL` 이 같은
  `localhost:5432`). 손으로 API 를 찔러 데이터를 남기면 시드 개수를 단언하는 테스트가
  깨집니다(예: `test_trainer_client_diet_maps_member_meals` 는 `len(meals) == 3`).
  `pytest` 를 돌리기 전에 `docker compose down -v && docker compose up -d` 로 초기화하세요.
