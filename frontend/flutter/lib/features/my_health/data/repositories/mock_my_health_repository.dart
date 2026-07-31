import 'package:oncare/features/my_health/domain/entities/health_history.dart';
import 'package:oncare/features/my_health/domain/repositories/my_health_repository.dart';

class MockMyHealthRepository implements MyHealthRepository {
  const MockMyHealthRepository();

  @override
  Future<MyHealthState> fetchState() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return const MyHealthState(
      profile: UserProfile(name: '김민수', email: 'minsu@oncare.com'),
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
