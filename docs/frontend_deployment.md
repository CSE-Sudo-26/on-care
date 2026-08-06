# 프론트엔드 배포 구조 및 운영 절차

## 현재 운영 환경

프론트엔드의 공식 배포 대상은 **GitHub Pages 한 곳**입니다. 루트 랜딩페이지와 두 Flutter Web 앱을 하나의 Pages artifact로 묶어 같은 도메인에서 제공합니다.

| 경로 | 서비스 | 배포 산출물 |
| --- | --- | --- |
| `https://ewhasudo.zapto.org/` | 랜딩페이지 | `public/index.html` |
| `https://ewhasudo.zapto.org/frontend/` | 사용자 앱 | `public/frontend/` |
| `https://ewhasudo.zapto.org/trainer/` | 트레이너 앱 | `public/trainer/` |

- 배포 워크플로: [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml)
- 커스텀 도메인 설정: [`CNAME`](../CNAME)
- 자동 배포 조건: `main` 브랜치 push
- 수동 배포: GitHub Actions의 `Deploy GitHub Pages` → `Run workflow`

## GitHub Pages 배포 과정

1. 사용자 앱과 트레이너 앱의 Flutter 의존성을 설치합니다.
2. 두 앱에 필요한 drift WASM 파일을 내려받습니다.
3. 사용자 앱을 `/frontend/`, 트레이너 앱을 `/trainer/` base path로 빌드합니다.
4. 루트 `index.html`과 두 앱의 빌드 결과를 `public/` 아래에 모읍니다.
5. Pages artifact를 업로드하고 `github-pages` 환경에 배포합니다.
6. 배포 action이 제한 시간 안에 완료를 확인하지 못하면 `version.txt`로 실제 반영 여부를 추가 검증합니다.

## Vercel 자동 배포 정리

Vercel 프로젝트가 이 Git 저장소와 연결되어 있으면 저장소 안에 `vercel.json`이 없어도 다음 배포가 별도로 생성될 수 있습니다.

- `main` 갱신: Vercel Production 배포
- PR 브랜치 갱신: Vercel Preview 배포 및 GitHub Bot 댓글

이 배포는 GitHub Pages로 전달되는 중간 단계가 아니라 **Vercel이 같은 커밋을 독립적으로 배포하는 중복 경로**입니다. 공식 서비스에서 Vercel을 사용하지 않으므로 아래 순서로 연결을 정리합니다.

1. 루트 [`vercel.json`](../vercel.json)의 `git.deploymentEnabled: false`를 반영해 모든 브랜치의 자동 배포를 차단합니다.
2. Vercel Dashboard에서 `sudo-capstone-project`를 엽니다.
3. `Settings` → `Git`에서 연결된 GitHub 저장소를 `Disconnect`합니다.
4. GitHub 저장소의 Rulesets 또는 Branch protection에서 Vercel 관련 required check가 있으면 제거합니다.
5. 새 PR을 갱신해 Vercel Preview와 Bot 댓글이 더 생성되지 않는지 확인합니다.
6. `main` 갱신 후 Vercel Production 배포가 생성되지 않는지 확인합니다.
7. 기존 `*.vercel.app` 주소가 필요하지 않다면 Pages 검증 후 Vercel 프로젝트를 별도로 삭제합니다.

> `vercel.json`은 자동 배포를 코드 수준에서 막는 안전장치입니다. Git 연결 해제와 프로젝트 삭제는 외부 서비스 설정이므로 저장소 변경만으로 실행되지 않습니다.

## 배포 확인

배포 완료 후 다음 항목을 확인합니다.

- 랜딩페이지 `https://ewhasudo.zapto.org/`가 정상 응답하는지 확인
- 사용자 앱 `https://ewhasudo.zapto.org/frontend/`이 정상 응답하는지 확인
- 트레이너 앱 `https://ewhasudo.zapto.org/trainer/`이 정상 응답하는지 확인
- `https://ewhasudo.zapto.org/version.txt`의 값이 배포한 전체 커밋 SHA와 일치하는지 확인

## AWS 이전 원칙

AWS 이전은 Vercel 정리와 별도 이슈 및 PR로 진행합니다.

구체적인 인프라 생성, 비활성 배포 설정, 병행 검증 절차는 [`aws-frontend-deployment.md`](aws-frontend-deployment.md)를 따릅니다.

1. GitHub Pages 배포를 유지한 상태에서 S3, CloudFront, OIDC 인프라를 준비합니다.
2. CloudFront 기본 도메인으로 랜딩페이지와 두 Flutter 앱을 검증합니다.
3. 검증이 끝난 뒤 커스텀 도메인의 DNS를 CloudFront로 전환합니다.
4. 전환과 롤백 가능 여부를 확인한 다음 GitHub Pages 배포를 중단합니다.

이 순서를 따르면 AWS 준비 중에도 현재 서비스 주소를 계속 사용할 수 있습니다.
