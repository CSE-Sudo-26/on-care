import 'package:oncare/features/my_health/domain/entities/health_history.dart';
import 'package:oncare/features/my_health/domain/repositories/my_health_repository.dart';

class MockMyHealthRepository implements MyHealthRepository {
  const MockMyHealthRepository();

  @override
  Future<MyHealthState> fetchState() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return const MyHealthState(
      // 트레이너웹 데모의 김민수(`seed-client-1`)와 같은 사람이다. MY 탭이
      // 보여주는 이 id는 트레이너웹의 "회원 ID로 신규 고객 등록" 데모가
      // 인식하는 `demoAlreadyLinkedMemberId` 와 일부러 맞춰 뒀다 — 두 데모를
      // 오가며 같은 ID가 통해야 시연이 앞뒤가 맞는다.
      //
      // 이 앱의 실제 데모 계정 id(`user-demo`, 로그인·채팅·운동 픽스처 등
      // 수십 곳이 공유)를 그대로 쓰지 않는 이유: 실 서비스 회원 ID는
      // `user-<12자리 hex>` 형태로 짧고 추측하기 쉬운 값이 아닌데, `user-demo`
      // 는 그 감이 오지 않는다. 계정 id 자체를 복잡한 형태로 바꾸는 일은
      // 서버 배포 시점의 후속 작업으로 미루고, 지금은 이 화면이 보여주는
      // 값만 그 형태를 흉내낸다.
      profile: UserProfile(
        name: '김민수',
        email: 'minsu@oncare.com',
        id: 'user-7d4e9a2c5f18',
      ),
      risk: RiskAlert(
        title: '고혈압·당뇨 위험 주의',
        body: '최근 혈압과 혈당 추세가 다소 높습니다. 식단·운동 관리에 신경 써주세요.',
        level: RiskLevel.medium,
      ),
      activityPoints: 1240,
      activityRank: 14,
      settings: <SettingsItem>[
        SettingsItem(
          label: '내 프로필',
          icon: '👤',
          kind: SettingsKind.myProfile,
        ),
        SettingsItem(
          label: '알림 설정',
          icon: '🔔',
          kind: SettingsKind.notification,
        ),
        SettingsItem(
          label: '고객 지원',
          icon: '💬',
          kind: SettingsKind.support,
        ),
      ],
    );
  }
}
