<div align="center">

<img src="docs/assets/oncare-banner.png" alt="On-Care Banner" width="900"/>

<br/><br/>


# On-care <img src="docs/assets/oncare-logo-name.png" alt="On-Care Logo" width="150" align="left"/>

***HealthMate AI: 트레이너 연동<br> 식단·운동 관리 서비스***

<br/><br/>

[![소개 페이지](https://img.shields.io/badge/INTRO_PAGE-소개_페이지-6B7280?style=for-the-badge&logo=googlechrome&logoColor=white)](https://ewhasudo.zapto.org/)
[![사용자 앱](https://img.shields.io/badge/APP-사용자-3eafdf?style=for-the-badge&logo=flutter&logoColor=white)](https://ewhasudo.zapto.org/frontend/#/dashboard)
[![트레이너 웹](https://img.shields.io/badge/WEB-트레이너-2E7DAB?style=for-the-badge&logo=safari&logoColor=white)](https://ewhasudo.zapto.org/trainer/)
[![데모 영상](https://img.shields.io/badge/YOUTUBE-데모_영상-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://youtu.be/C4ivM_dlAww?si=8iOWmOpSxcpQmlU3)

<br/>

<em><b>On-Care</b> turns scattered trainer–member messaging into data-driven coaching — a member's meals and workouts are auto-organized into daily reports for their trainer, and the trainer's routines flow straight back into the member's app. Built for personal training, where results are decided between sessions.</em>

</div>

---

## Overview

**On-Care**는 헬스 트레이너와 회원 사이의 식단·운동 관리 소통을 자동화하는 플랫폼입니다. 회원이 음식 사진 한 장·간단한 입력만 하면 앱이 식단과 운동을 회원별·날짜별로 정리해 트레이너에게 전달하고, 트레이너는 흩어진 메시지를 뒤지는 대신 정리된 리포트 위에서 코칭합니다.

**타깃 유저**는 **PT를 이용하는 회원과 이들을 관리하는 트레이너**입니다. PT의 성과는 주 1~2회 대면 세션이 아니라 **세션과 세션 사이의 식단·운동 관리**에서 갈리지만, 정작 그 구간은 개인 메신저에 맡겨져 있습니다. On-Care는 트레이너의 관리를 세션 밖으로 확장하는 것을 목표로 합니다.

---

## Problem

트레이너와 회원 모두 **"기록은 하는데, 그 기록이 관리로 이어지지 않는"** 같은 벽에 부딪힙니다.

| 대상 | 현재 겪는 어려움 |
| --- | --- |
| 🏋️ **트레이너** | 담당 회원의 식사·운동을 개별 메신저로 일일이 확인하느라 세션 밖 시간을 쓰지만, 대화가 흩어져 회원별 흐름이 한눈에 보이지 않습니다. 회원이 늘수록 관리 품질이 떨어져 **확장이 어렵습니다.** |
| 🧍 **회원** | 매 끼 검색·입력하는 번거로움에 기록을 며칠 만에 포기하고, 어렵게 남긴 기록도 **"그래서 무엇을 바꿔야 하는지"** 로 이어지지 않습니다. 세션에서 배운 루틴도 기억에 의존해 재현합니다. |

이 문제를 겨냥한 서비스는 이미 많았지만 정착하지 못했습니다. 회원용 기록 앱과 트레이너용 도구가 **서로 분리되어**, 회원의 데이터가 트레이너에게 정리된 형태로 닿지 않기 때문입니다. 결국 관리는 다시 메신저로 돌아옵니다. On-Care는 바로 이 **끊어진 연결**을 잇습니다.

---

## Background <sub>Evidence &amp; Data</sub>

헬스장 등록은 계속 늘지만, 그 대부분은 몇 달 안에 사라집니다. 무엇이 남는 사람과 사라지는 사람을 가르는지는 이미 연구로 밝혀져 있습니다 — **트레이너의 감독**입니다. 문제는 그 감독이 주 1~2회 대면 세션에서 끊긴다는 것입니다.

**① 수요는 크고, 계속 늘고 있다**

| 지표 (기준시점) | 수치 |
| --- | --- |
| **체력단련장업** 업소 수 (2024년 말) | **15,548개소** (전년 14,773개소 대비 **+5.2%**) |
| **체력단련시설 운영업** 규모 (2024년) | 매출 **2조 6,827억 원** · 사업체 12,152개 · 종사자 **42,645명** |
| 규칙적 운동 참여자의 **주 참여 종목** (2025년) | **보디빌딩(헬스) 17.5%** — 걷기(40.5%) 다음 2위 · **20대 30.9% / 30대 36.0%** |
| **생활스포츠지도사** 신규 배출 (2025년) | **16,281명** (2024년 12,915명) — 트레이너 공급 확대, 경쟁 심화 |

**② 그런데 등록의 대부분은 3개월을 넘기지 못한다**

| 지표 (대상 · 자료원) | 수치 |
| --- | --- |
| 헬스장 신규 회원 **이탈** (5,240명 생존분석 · 2016) | **63%가 3개월 이전 이탈** · 12개월 이상 지속 **4% 미만** |
| 유료 운동시설 등록 후 **미이용** (직장인 590명 · 2015) | 등록 후 **안 감 61%** · 등록자의 **71%가 1개월 이내 포기** |
| 운동을 **방해하는 요인** (성인 1,000명 · 2024) | 의지력 부족 **77%** · 시간 부족 60% *(복수응답)* |
| **앱 단독** 개입의 이탈률 (메타분석 17편 · 2020) | **43%** (95% CI 29–57) — 앱만으로는 지속되지 않음 |

**③ 차이를 만드는 것은 '감독'이다** — On-Care 설계의 근거

| 지표 (연구 설계) | 수치 |
| --- | --- |
| **운동 순응도** (10주 RCT · n=79 · 2025) | **대면 감독 88.2%** > **앱 코칭 81.2%** > **자율 52.2%** |
| 근력 성과 (동일 RCT) | 스쿼트 1RM 증가 감독군 **+26.6kg** vs 자율 +19.4kg (p≤0.044) · 제지방량은 감독군만 유의 증가 |
| 감독의 효과크기 (메타분석 12편 · 577명) | 근력 **SMD 0.40** (95% CI 0.06–0.74) · *단 체성분은 유의하지 않음(0.07)* |
| **세션 사이 접촉**의 순응도 효과 | 자동 문자 개입군 순응도 유의 개선 (p=.01) · 디지털 개입 RCT **10편 중 7편**이 순응도 우세 |

> 해당 RCT의 결론은 *"앱 기반 트레이닝은 완전한 감독이 불가능할 때 유효한 대안"* 입니다. 그러나 **앱 단독은 이탈률 43%**에 이릅니다. 근거가 가리키는 답은 앱도 트레이너도 아닌, **트레이너의 감독을 앱으로 세션 밖까지 연장하는 결합**입니다.

**④ 기록은 끊기고, 그 반대편에서 트레이너는 과부하다**

| 지표 (대상 · 자료원) | 수치 |
| --- | --- |
| 식단 **자기기록의 지속** (6개월 RCT · n=124) | **10주차에 절반 미만만 기록 지속** · 순응도가 체중변화 분산의 **27%** 설명 |
| 기록 수단별 지속 (6개월 RCT · n=128) | 앱 **92일** vs 종이일지 29일 · 6개월 유지율 앱 **93%** vs 종이 53% |
| **사진 기록만의 한계** (6개월 RCT · n=41) | 사진 앱과 칼로리 입력 앱의 **기록 일수 차이 없음(p=0.18)** — 자동화만으로는 부족, **피드백이 붙어야 함** |
| **PT 소비자 피해** 원인 (한국소비자원 · 2022) | *"**관리 회원이 많아** 예약 일정을 잡기 어려운 경우", "담당 트레이너가 자주 변경되어"* 를 주요 원인으로 명시 |
| 실내체육시설 **피해구제** (최근 3년 · 2025) | **14,857건** · 신청 사유 **계약 관련 97.5%** |

> ④의 세 번째 줄은 On-Care가 스스로에게 적용하는 제약이기도 합니다. **사진 인식으로 기록 마찰을 없애는 것만으로는 지속되지 않으며**, 24개월까지 유의한 성과가 남은 것은 *기록 + 일일 맞춤 피드백* 조건뿐이었습니다. On-Care가 사진 인식에서 멈추지 않고 **트레이너 리포트와 코칭 회신**까지를 한 루프로 묶는 이유입니다.

<sub>Sources — 시장·수요: [전국 등록·신고 체육시설업 현황 2024년 말 기준, 문체부 2026-03-11](https://www.mcst.go.kr/kor/s_policy/dept/deptView.jsp?pSeq=2115&pDataCD=0417000000&pType=07) · [스포츠산업조사 2024년 기준, 문체부](https://www.mcst.go.kr/kor/s_policy/dept/deptView.jsp?pSeq=2101&pDataCD=0417000000&pType=07) · [2025년 국민생활체육조사, 문체부](https://www.mcst.go.kr/kor/s_policy/dept/deptView.jsp?pSeq=2091&pDataCD=0417000000&pType=07) · [체육지도자 양성 현황, e-나라지표](https://www.index.go.kr/unity/potal/main/EachDtlPageDetail.do?idx_cd=1661) — 이탈·순응도: [Sperandei et al., *J Sci Med Sport* 2016](https://pubmed.ncbi.nlm.nih.gov/26874647/) · [한국건강증진개발원×인크루트 2015](https://www.khepi.or.kr/board/view?linkId=501805&menuId=MENU00907) · [한국리서치 2024](https://www.hankookilbo.com/news/article/A2024060609120001970) · [Meyerowitz-Katz et al., *JMIR* 2020](https://pubmed.ncbi.nlm.nih.gov/32990635/) — 감독 효과: [Gavanda et al., *J Strength Cond Res* 2025](https://pubmed.ncbi.nlm.nih.gov/40728831/) · [Fisher et al., *IJSC* 2022](https://journal.iusca.org/index.php/Journal/article/view/101) · [Bennell et al., *JMIR* 2020](https://www.jmir.org/2020/9/e21749/) · [Lang et al., *Arch Physiother* 2022](https://pubmed.ncbi.nlm.nih.gov/36184611/) — 기록 순응도: [Turner-McGrievy et al., *JAND* 2019](https://pubmed.ncbi.nlm.nih.gov/31155473/) · [Carter et al., *JMIR* 2013](https://pubmed.ncbi.nlm.nih.gov/23587561/) · [Dunn et al., *JAND* 2019](https://pubmed.ncbi.nlm.nih.gov/31155474/) · [Burke et al., *AJPM* 2012](https://pubmed.ncbi.nlm.nih.gov/22704741/) — 소비자 피해: [헬스장·PT 피해예방주의보, 한국소비자원 2022](https://www.kca.go.kr/home/sub.do?menukey=4005&mode=view&no=1003328536) · [서울시 체육시설 피해예방주의보, 한국소비자원 2025](https://www.kca.go.kr/home/sub.do?menukey=4005&mode=view&no=1003959737)</sub>

---

## Solution

회원의 기록은 앱 안에서 자동으로 정리되어 트레이너에게 넘어가고, 트레이너의 코칭은 다시 회원에게 돌아옵니다. 회원은 최소한의 노력으로 관리받고, 트레이너는 더 많은 회원을 더 높은 품질로 관리하며, 그 사이의 모든 판단은 감이 아닌 **데이터**를 근거로 이루어집니다.

<div align="center">
<img src="docs/assets/diagram-service-loop.svg" alt="Service Data Flow" width="88%" />
</div>

---

## Key Features

| 기능 | 설명 |
| --- | --- |
| 📷 **간편 식단 기록** | 음식 사진을 찍으면 AI(VLM)가 음식과 양을 추정하고, 식약처 공공 DB의 영양성분 참고값을 조회해 나트륨·칼로리·당 추정치를 제공합니다. 완벽한 자동 계산이 아니라 기록 부담을 없애는 것이 목적이며, **최종 값은 회원·트레이너가 확인·보정**해 신뢰도를 높입니다. |
| 🏋️ **운동 기록 자동 연동** | 트레이너가 세션에서 입력한 프로그램·수행이 회원 기록에 자동 반영되어, 회원이 일일이 적지 않아도 데이터가 쌓입니다. |
| 📊 **자동 요약 리포트** | 식단·운동·활동을 회원별·날짜별로 묶어 트레이너에게 전달합니다. *"이 회원, 이번 주 나트륨 과다 · 유산소 부족"* 을 한눈에 파악합니다. |
| 🔗 **데이터 기반 매칭** | 회원의 목표와 조건(지역·시간·성향)에 맞춰 트레이너·헬스장을 추천하고 앱 안에서 연결합니다. |
| 🎯 **목표·미션 관리** | 회원의 목표에 맞춘 영양·활동량 목표와 일일 미션. 많이 먹은 날은 활동량을, 적게 먹은 날은 식단을 조정하는 **식단↔운동 연동 코칭**을 제공합니다. |

---

## Diet Recognition Pipeline

사진에서 시작해 VLM이 음식과 양을 추정하고, **공공 영양성분 DB 참고값**으로 추정치를 보정한 뒤, 구조화된 기록과 트레이너 리포트로 이어집니다. 최종 값은 회원·트레이너가 확인·수정할 수 있습니다.

<div align="center">
<img src="docs/assets/diagram-diet-pipeline.svg" alt="Diet Recognition Pipeline" width="100%" />
</div>

---

## System Architecture

<div align="center">
<img src="docs/assets/diagram-architecture.svg" alt="System Architecture" width="94%" />
</div>

---

## Tech Stack

| 영역 | 사용 기술 |
| --- | --- |
| **Frontend** | Flutter · Dart · Riverpod · GoRouter (회원 앱(모바일) · 트레이너 웹 — 분리된 코드베이스, 아키텍처 패턴 미러링) |
| **Backend** | FastAPI · SQLAlchemy · Alembic · JWT · Docker |
| **Database** | PostgreSQL · pgvector |
| **AI** | Vision(VLM) 식단 인식 · 식약처 공공 영양성분 DB 매칭 · RAG 코치 |
| **Infra** | 백엔드 AWS ECR + App Runner · 프론트 GitHub Pages(커스텀 도메인) · GitHub Actions (CI/CD) |
| **External API** | 카카오 (지도 JS SDK · 로컬 장소 검색 · 소셜 로그인) · 공공데이터포털 (식약처 영양성분) |

---

## Docs

| 문서 | 내용 |
| --- | --- |
| [로컬 풀스택 실행](docs/local_fullstack.md) | 백엔드·회원 앱·트레이너 웹을 한 대에서 띄우는 절차 |
| [API 계약](backend/API_CONTRACT.md) | 엔드포인트·요청/응답 스키마 |
| [프론트엔드 배포](docs/frontend_deployment.md) | GitHub Pages 배포 구조와 운영 절차 |
| [백엔드 배포](backend/docs/DEPLOY.md) | 컨테이너 이미지·마이그레이션·환경변수 |

---

## Competitive Analysis

| 항목 | 필라이즈 | 밀리그램·인아웃 | **On-Care** |
| --- | :---: | :---: | :---: |
| **식단 기록** | 사진 AI 인식 | 사진·빠른 입력 | **사진 → 공공 영양 DB 매칭** |
| **트레이너 연동** | 앱 내 AI 코치만 | 없음 | **회원 데이터 자동 정리 → 트레이너 전달** |
| **회원 관리 확장성** | 없음 | 없음 | **1인이 다수 회원을 데이터로 관리** |
| **세션 밖 코칭** | AI 응답만 | 없음 | **담당 트레이너의 실제 코칭이 앱으로 연장** |
| **데이터 흐름** | 개인 앱 내 완결 | 개인 앱 내 완결 | **회원 ↔ 트레이너 양방향** |

> 기존 서비스는 회원 개인의 기록에서 끝납니다. On-Care는 그 기록을 **트레이너의 코칭 자원으로 연결**하는 흐름 자체가 차별점입니다.

---

## Target &amp; Business Model

On-Care의 **핵심 타깃**은 **PT를 이용하는 회원과 이들을 관리하는 트레이너**입니다. 회원은 이미 PT에 비용을 지불하고 있는 층이라 관리 품질에 대한 지불 의사가 높고, 트레이너는 담당 회원 수가 곧 수익인 만큼 **관리 효율을 높이는 도구에 직접적인 구매 동기**를 가집니다.

| 구분 | 모델 |
| --- | --- |
| **메인** | 트레이너·헬스장 **중개 수수료 / 구매 전환 커미션** · 트레이너용 **고도화 기능 구독** |
| **프리미엄** | 기본 기능은 무료로 진입장벽을 낮추고, 가치를 체감한 사용자가 고도화 기능을 결제 |
| **부수** | 광고(상위 노출 등)는 보조 수입으로만 |

> **확장 방향** — PT에서 자리 잡은 뒤에는 같은 구조(전문가가 개인의 생활 관리를 지속적으로 지도하는 관계)를 필라테스·요가 스튜디오, 기업 임직원 건강관리, 재활·시니어 운동 지도로 넓힐 수 있습니다.

---

## Team

|                                                         최지수                                                          |                                                            박서연                                                            |                                                           신수빈                                                           |
|:--------------------------------------------------------------------------------------------------------------------:|:-------------------------------------------------------------------------------------------------------------------------:|:-----------------------------------------------------------------------------------------------------------------------:|
| <a href="https://github.com/aJISUa"><img src="https://github.com/aJISUa.png" alt="최지수 프로필 사진" width="100"></a> | <a href="https://github.com/seoyeon0516"><img src="https://github.com/seoyeon0516.png" alt="박서연 프로필 사진" width="100"></a> | <a href="https://github.com/subin21cc"><img src="https://github.com/subin21cc.png" alt="신수빈 프로필 사진" width="100"></a> |
|                                         [@aJISUa](https://github.com/aJISUa)                                         |                                      [@seoyeon0516](https://github.com/seoyeon0516)                                       |                                       [@subin21cc](https://github.com/subin21cc)                                        |

> *지도교수: 황의원 교수님 (이화여자대학교 · 컴퓨터공학전공)*

---

## License

본 프로젝트는 [MIT License](LICENSE) 하에 배포됩니다. 자세한 내용은 [`LICENSE`](LICENSE) 파일을 참고하세요.

> Copyright © 2026 On-Care Team (CSE-Sudo-26: 최지수 · 박서연 · 신수빈)

<br/>

---

<div align="center">

<img src="docs/assets/oncare-logo.png" alt="On-Care" width="56" />

**2026 이화여자대학교 캡스톤디자인**

*Team 02 Sudo — Jisu Choi · Seoyeon Park · Subin Shin*

</div>
