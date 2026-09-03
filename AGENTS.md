# AGENTS.md

이 저장소에서 작업하는 AI 코딩 도구(Claude Code · Codex · Cursor 등)를 위한 지침입니다.
사람이 읽어도 됩니다. `CLAUDE.md` 는 이 파일을 그대로 불러옵니다.

## 프로젝트

**On-Care** — HealthMate AI: 회원·트레이너 연동 식단·운동 관리 서비스.
2026 이화여자대학교 캡스톤디자인 Team 02 Sudo.

회원 앱(Flutter, 모바일)과 트레이너 웹(Flutter Web)이 **단일 백엔드(FastAPI)를 공유**하는
O2O 서비스입니다. 회원이 음식 사진 한 장·간단한 입력으로 식단과 운동을 기록하면, 앱이 이를
회원별·날짜별로 정리해 트레이너에게 전달하고, 트레이너의 코칭과 운동 루틴이 다시 회원 앱으로
돌아옵니다.

**타깃은 PT를 이용하는 회원과 이들을 관리하는 트레이너입니다.**

## ⚠️ 참조 금지 — `docs/archive/**`

`docs/archive/` 아래의 모든 문서는 **캡스톤 스타트 단계(졸업프로젝트 1단계)의 보존용 기록**이며,
이후 타깃과 서비스 방향이 재정의되어 **현재 제품과 일치하지 않습니다.**

- 이 디렉터리의 내용을 **현재 사양·타깃·수치·경쟁 분석의 근거로 인용하지 마십시오.**
- 검색 결과에 이 경로가 걸리더라도 현재 사실로 취급하지 말고, 필요하면 "스타트 단계 기록"이라고
  명시해 구분하십시오.
- 특히 이 문서들에 남아 있는 **"2030 고혈압·당뇨 위험군"** 타깃 서술은 **폐기된 이전 방향**입니다.
  현재 타깃은 위에 적은 대로 PT 회원과 트레이너입니다.
- 사용자가 명시적으로 "스타트 단계에는 어땠나", "예전 기획을 보여 달라"고 요청할 때만 참조하고,
  그 경우에도 출처가 아카이브임을 밝히십시오.

무엇이 어떻게 바뀌었는지는 [docs/archive/README.md](docs/archive/README.md) 에 정리되어 있습니다.

## 현재 기준 문서

| 문서 | 내용 |
| --- | --- |
| [README.md](README.md) | 서비스 개요·문제 정의·기능·아키텍처·기술 스택 (**최우선 기준**) |
| [docs/local_fullstack.md](docs/local_fullstack.md) | 백엔드·회원 앱·트레이너 웹 로컬 실행 |
| [backend/API_CONTRACT.md](backend/API_CONTRACT.md) | 엔드포인트·요청/응답 스키마 |
| [backend/docs/TRAINER_DOMAIN.md](backend/docs/TRAINER_DOMAIN.md) | 회원↔트레이너 데이터 공유 도메인 |
| [docs/team_workflow.md](docs/team_workflow.md) | 브랜치·커밋·PR 규약 |
| [docs/frontend_deployment.md](docs/frontend_deployment.md) | 프론트 배포 구조 |

## 저장소 구조

| 경로 | 내용 |
| --- | --- |
| `backend/` | FastAPI · SQLAlchemy · Alembic · PostgreSQL(pgvector) |
| `frontend/flutter/` | 회원 앱 (모바일) |
| `frontend/flutter_trainer/` | 트레이너 웹 |
| `docs/` | 현행 문서 |
| `docs/archive/` | **보존용 기록 — 참조 금지 (위 항목 참고)** |
| `index.html` | 소개 페이지 (GitHub Pages) |
