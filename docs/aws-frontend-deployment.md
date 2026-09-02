# AWS 프론트엔드 배포 준비

Flutter 회원 앱과 트레이너 웹을 하나의 private S3 버킷에 올리고 CloudFront로 제공합니다. GitHub Actions는 장기 액세스 키 대신 OIDC 임시 자격 증명을 사용합니다.

이 변경을 `main`에 병합해도 AWS 배포는 즉시 시작되지 않습니다. `AWS_FRONTEND_DEPLOY_ENABLED` 저장소 변수가 정확히 `true`일 때만 별도 AWS 워크플로가 실행되며, 전환 검증이 끝날 때까지 기존 GitHub Pages 배포와 커스텀 도메인을 유지합니다.

## 사전 조건

- AWS 계정 MFA 설정
- 배포 리전: `ap-northeast-2`(서울)
- AWS Budget 알림 유지
- CloudFormation을 실행할 IAM 관리자 계정
- GitHub 저장소의 `KAKAO_JS_KEY` secret 유지

## 1. 템플릿 검증

AWS CloudShell에서 브랜치를 받은 뒤 템플릿을 먼저 검증합니다.

템플릿은 기본적으로 GitHub의 immutable OIDC subject를 사용합니다. 저장소 설정값은 다음 명령으로
확인합니다. 응답의 `sub_claim_prefix`에 표시된 owner ID와 repository ID가 템플릿 기본값과 다르면
배포 시 `GitHubOwnerId`, `GitHubRepositoryId` 파라미터로 전달합니다.

```bash
gh api repos/CSE-Sudo/on-care/actions/oidc/customization/sub
```

2026년 7월 15일 이전에 생성되어 이름 기반 subject를 계속 사용하는 저장소에서는
`UseImmutableGitHubOidcSubject=false`를 전달할 수 있습니다. 와일드카드로 권한 범위를 넓히지 않고,
저장소와 `main` 브랜치가 포함된 정확한 subject를 유지합니다.

```bash
git clone https://github.com/CSE-Sudo/on-care.git
cd on-care
git switch feat/aws-frontend-deployment

aws cloudformation validate-template \
  --template-body file://infra/frontend-hosting.yml \
  --region ap-northeast-2
```

계정에 GitHub Actions용 OIDC 공급자가 이미 있는지도 확인합니다.

```bash
aws iam list-open-id-connect-providers \
  --query 'OpenIDConnectProviderList[*].Arn' \
  --output table
```

`token.actions.githubusercontent.com` 공급자가 없다면 아래 기본 명령으로 새 공급자를 함께 생성합니다.

## 2. AWS 리소스 생성

```bash
aws cloudformation deploy \
  --template-file infra/frontend-hosting.yml \
  --stack-name oncare-frontend \
  --capabilities CAPABILITY_IAM \
  --region ap-northeast-2
```

이미 GitHub OIDC 공급자가 있다면 그 ARN을 전달해 재사용합니다.

```bash
aws cloudformation deploy \
  --template-file infra/frontend-hosting.yml \
  --stack-name oncare-frontend \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    ExistingGitHubOidcProviderArn=arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com \
  --region ap-northeast-2
```

> **이미 생성된 스택을 갱신하는 경우 주의합니다.** `aws cloudformation deploy`는 `--parameter-overrides`에 없는 파라미터를 이전 값 그대로 유지합니다. 저장소 이름이 `sudo-capstone-project`에서 `on-care`로 바뀌었으므로, 이름 변경 이전에 만들어진 스택은 템플릿의 `GitHubRepository` 기본값을 갱신해도 이전 값을 계속 씁니다. 이 경우 OIDC 신뢰 조건의 `sub`가 옛 저장소를 가리켜 배포 워크플로가 자격 증명을 받지 못하므로, 아래처럼 값을 명시해 한 번 갱신해야 합니다.
>
> ```bash
> aws cloudformation deploy \
>   --template-file infra/frontend-hosting.yml \
>   --stack-name oncare-frontend \
>   --capabilities CAPABILITY_IAM \
>   --parameter-overrides \
>     GitHubRepository=on-care \
>     GitHubOwnerId=265976266 \
>     GitHubRepositoryId=1174354664 \
>   --region ap-northeast-2
> ```

CloudFront 배포가 포함되어 있어 스택 생성에는 몇 분이 걸릴 수 있습니다. 완료되면 출력값을 확인합니다.

```bash
aws cloudformation describe-stacks \
  --stack-name oncare-frontend \
  --region ap-northeast-2 \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table
```

## 3. GitHub Actions 변수 등록

GitHub 저장소의 `Settings` → `Secrets and variables` → `Actions` → `Variables`에 스택 출력값을 등록합니다.

| 변수 | 값 |
| --- | --- |
| `AWS_FRONTEND_DEPLOY_ROLE_ARN` | `GitHubDeployRoleArn` 출력값 |
| `AWS_FRONTEND_BUCKET` | `BucketName` 출력값 |
| `AWS_FRONTEND_DISTRIBUTION_ID` | `DistributionId` 출력값 |

준비 단계에서는 `AWS_FRONTEND_DEPLOY_ENABLED`를 만들지 않거나 `false`로 둡니다. AWS 액세스 키는 GitHub Secrets에 만들거나 저장하지 않습니다.

## 4. 첫 AWS 배포 활성화

CloudFormation 스택과 세 변수를 확인하고 배포할 `main` 커밋이 준비된 뒤에만 다음 변수를 추가합니다.

| 변수 | 값 |
| --- | --- |
| `AWS_FRONTEND_DEPLOY_ENABLED` | `true` |

OIDC 역할은 `main` 브랜치만 신뢰하므로 AWS 워크플로의 첫 실행도 `main`에서 진행합니다.

1. GitHub Actions에서 `Deploy Frontend to AWS`를 엽니다.
2. `Run workflow`에서 `main`을 선택합니다.
3. 워크플로가 출력한 CloudFront 기본 도메인을 확인합니다.

```text
https://<DistributionDomainName>/
https://<DistributionDomainName>/frontend/
https://<DistributionDomainName>/trainer/
https://<DistributionDomainName>/version.txt
```

세 서비스 경로가 정상 응답하고 `version.txt`가 배포한 전체 커밋 SHA와 일치해야 합니다. 카카오맵을 CloudFront 기본 도메인에서도 검증하려면 해당 도메인을 카카오 JavaScript SDK 허용 도메인에 임시 등록해야 합니다.

## 5. Pages와 병행 운영

초기 AWS 검증 중에는 다음 상태를 유지합니다.

- `.github/workflows/deploy.yml`: 기존 GitHub Pages 배포 계속 실행
- `.github/workflows/aws-frontend-deploy.yml`: 활성화 변수 설정 시 AWS에도 병행 배포
- `ewhasudo.zapto.org`: 계속 GitHub Pages를 가리킴
- CloudFront 기본 도메인: AWS 배포 검증에만 사용

AWS 배포에 문제가 생기면 `AWS_FRONTEND_DEPLOY_ENABLED=false`로 변경해 추가 배포를 즉시 중단할 수 있습니다. Pages와 현재 커스텀 도메인은 영향을 받지 않습니다.

## 6. 커스텀 도메인 전환

CloudFront 검증이 끝난 뒤 별도 변경으로 진행합니다.

1. `us-east-1`에서 `ewhasudo.zapto.org`용 ACM 인증서 발급 및 DNS 검증
2. CloudFront distribution에 인증서와 alternate domain name 연결
3. DNS를 GitHub Pages에서 CloudFront로 전환
4. 전환 후 랜딩페이지, 두 앱, SPA 새로고침, 카카오맵 확인
5. 롤백 가능 여부를 확인한 뒤 GitHub Pages 배포 중단

## 7. 릴리스 전환과 롤백

배포는 운영 파일을 덮어쓰지 않습니다. 빌드는 커밋 SHA로 격리된 `releases/<SHA>/`에 올라가고, 그 릴리스가 온전한지 확인한 뒤에야 CloudFront distribution의 origin path를 그 prefix로 전환합니다. 전환 전에는 지금 서비스 중인 릴리스의 객체를 하나도 건드리지 않으므로, 업로드나 사전 검증이 실패하면 운영은 직전 빌드를 그대로 계속 서비스합니다.

| 단계 | 실패했을 때 |
| --- | --- |
| 빌드 · 업로드 · 릴리스 사전 검증 | 전환하지 않고 종료 — 운영은 직전 릴리스 유지 |
| origin path 전환 | 롤백 단계가 직전 origin path로 되돌리고 무효화 |
| 무효화 후 smoke check | 같음 — 자동 롤백 후 워크플로 실패 처리 |

- 릴리스 보관: 최신 5개를 남기고 그보다 오래된 prefix는 배포 성공 시 정리합니다. 현재 릴리스와 직전 릴리스는 개수와 무관하게 항상 보존합니다.
- 버킷 버전 관리가 켜져 있어 실수로 덮어쓰거나 지운 객체도 30일 안에는 복구할 수 있습니다.
- 수동 롤백이 필요하면 distribution의 origin path를 되돌릴 릴리스로 바꾸고 `/*`를 무효화합니다.

```bash
aws cloudfront get-distribution-config --id <DISTRIBUTION_ID> \
  --query 'DistributionConfig.Origins.Items[0].OriginPath'
```

> **이 방식은 스택 갱신이 선행되어야 합니다.** 릴리스 전환에는 `cloudfront:GetDistributionConfig`·`cloudfront:UpdateDistribution` 권한이 필요하고, 버전 관리·수명 주기 규칙도 템플릿에 새로 들어갔습니다. 이 변경을 병합한 뒤 배포를 켜기 전에 `aws cloudformation deploy`를 한 번 더 실행해 주세요.
>
> 첫 전환 이후에는 버킷 루트에 남아 있는 옛 배포 파일이 더 이상 서비스되지 않습니다. 다만 그 시점의 롤백 대상이 루트이므로, 다음 릴리스가 정상 서비스되는 것을 확인한 뒤에 수동으로 정리하는 편이 안전합니다.

## 비용 및 삭제 주의사항

- S3와 CloudFront는 사용량에 따라 과금될 수 있으므로 AWS Budget 알림을 유지합니다.
- CloudFormation 스택을 삭제해도 데이터 보호를 위해 S3 버킷은 보존됩니다.
- 다른 워크플로가 재사용할 수 있도록 스택이 생성한 GitHub OIDC 공급자도 보존됩니다. 스택을 다시 만들 때는 기존 공급자 ARN을 전달합니다.
- 완전히 정리하려면 스택 삭제 후 보존된 버킷을 비우고 별도로 삭제해야 합니다.
- 준비만 하고 당장 검증하지 않는다면 스택 생성을 미뤄 불필요한 리소스 사용을 피할 수 있습니다.
