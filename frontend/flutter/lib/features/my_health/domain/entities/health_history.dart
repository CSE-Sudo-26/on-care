class UserProfile {
  const UserProfile({required this.name, required this.email, this.id = ''});
  final String name;
  final String email;

  /// 회원 고유번호(`User.id`) — MY 탭이 "내 회원번호"로 보여주는 값이다.
  /// 트레이너웹의 신규 고객 등록이 이 값으로 회원을 찾아 연결한다.
  final String id;

  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
    name: json['name']! as String,
    email: json['email']! as String,
    id: (json['id'] as String?) ?? '',
  );
}

enum RiskLevel { low, medium, high }

RiskLevel _riskFromString(String s) => RiskLevel.values.firstWhere(
  (r) => r.name == s,
  orElse: () => RiskLevel.low,
);

class RiskAlert {
  const RiskAlert({
    required this.title,
    required this.body,
    required this.level,
  });
  final String title;
  final String body;
  final RiskLevel level;

  factory RiskAlert.fromJson(Map<String, Object?> json) => RiskAlert(
    title: json['title']! as String,
    body: json['body']! as String,
    level: _riskFromString(json['level']! as String),
  );
}

enum SettingsKind { myProfile, notification, support }

SettingsKind _settingsKindFromWire(String s) => switch (s) {
  'notification' => SettingsKind.notification,
  'support' => SettingsKind.support,
  _ => SettingsKind.myProfile,
};

class SettingsItem {
  const SettingsItem({
    required this.label,
    required this.icon,
    required this.kind,
  });
  final String label;
  final String icon; // emoji
  final SettingsKind kind;

  factory SettingsItem.fromJson(Map<String, Object?> json) => SettingsItem(
    label: json['label']! as String,
    icon: json['icon']! as String,
    kind: _settingsKindFromWire(json['kind']! as String),
  );
}

class MyHealthState {
  const MyHealthState({
    required this.profile,
    required this.risk,
    required this.activityPoints,
    required this.activityRank,
    required this.settings,
  });

  final UserProfile profile;
  final RiskAlert risk;
  final int activityPoints;
  // 백엔드 계약상 nullable(schemas/user.py: activity_rank: Optional[int]).
  // 온보딩만 마친 일반 사용자는 순위가 아직 없어 null 로 온다 — 강제 언랩하면
  // My Health 화면 전체가 파싱 오류가 되므로 null 을 그대로 수용한다(UI 는 배지 숨김).
  final int? activityRank;
  final List<SettingsItem> settings;

  factory MyHealthState.fromJson(Map<String, Object?> json) => MyHealthState(
    profile: UserProfile.fromJson(json['profile']! as Map<String, Object?>),
    risk: RiskAlert.fromJson(json['risk']! as Map<String, Object?>),
    activityPoints: (json['activity_points']! as num).toInt(),
    activityRank: (json['activity_rank'] as num?)?.toInt(),
    settings: (json['settings']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(SettingsItem.fromJson)
        .toList(),
  );
}
