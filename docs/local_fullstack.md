# 로컬 풀스택 실행 (백엔드 + 회원 앱 + 트레이너 앱)

두 앱을 **같은 백엔드·같은 DB** 로 띄우는 절차입니다. 회원↔트레이너 상호작용
(회원이 올린 식단을 트레이너가 보는 것 등)은 이 구성에서만 확인할 수 있습니다.

> 두 앱의 `useMockApi` 기본값은 `true` 입니다. dart-define 없이 실행하면 각 앱이
> **자기 로컬 drift DB** 를 보기 때문에, 두 앱이 각각 잘 도는 것처럼 보여도 서로의
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

## 2. 회원 앱

```bash
cd frontend/flutter
flutter run -d chrome \
  --dart-define=USE_MOCK_API=false \
  --dart-define=API_BASE_URL=http://localhost:8000/v1
```

## 3. 트레이너 앱

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

앱 없이 API 로만 30초 안에 확인할 수 있습니다. 회원이 올린 식단이 트레이너 쪽에
나타나면 두 앱이 같은 DB 를 보고 있다는 뜻입니다.

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

## 알려진 함정

- **Windows(Git Bash)에서 `curl -F "image=@/tmp/x.jpg"`** 는 `curl: (26)` 로 실패합니다.
  Windows `curl.exe` 가 MSYS 경로를 못 읽습니다. `$(cygpath -w /tmp/x.jpg)` 로 변환하세요.
- **셸에서 한글이 든 JSON 을 `-d` 로 보내면** 콘솔 인코딩(cp949) 때문에 깨져
  `400 There was an error parsing the body` 가 납니다. 파일(`-d @body.json`)로 보내거나
  ASCII 로 확인하세요. 앱에서 보내는 요청은 정상입니다.
- CORS 는 `.env` 기본값이 `CORS_ALLOW_ORIGINS=*` 라 로컬 웹에서 그대로 붙습니다.
