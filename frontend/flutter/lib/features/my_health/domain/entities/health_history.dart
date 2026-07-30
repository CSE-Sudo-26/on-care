class UserProfile {
  const UserProfile({required this.name, required this.email});
  final String name;
  final String email;

  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
    name: json['name']! as String,
    email: json['email']! as String,
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

enum IndicatorKind { weight, bloodPressure, bloodSugar }

/// Hyphenated wire form: weight | blood-pressure | blood-sugar.
/// Same convention as `VitalKind` so the wire format stays consistent.
IndicatorKind _indicatorFromWire(String s) => switch (s) {
  'blood-pressure' => IndicatorKind.bloodPressure,
  'blood-sugar' => IndicatorKind.bloodSugar,
  _ => IndicatorKind.weight,
};

/// One row in the trend modal's "최근 기록" list (label like "오늘" /
/// "1일 전" plus the pre-formatted value string such as "72 kg").
class IndicatorRecord {
  const IndicatorRecord({required this.label, required this.value});
  final String label;
  final String value;

  factory IndicatorRecord.fromJson(Map<String, Object?> json) =>
      IndicatorRecord(
        label: json['label']! as String,
        value: json['value']! as String,
      );
}

class IndicatorTrend {
  const IndicatorTrend({
    required this.kind,
    required this.label,
    required this.latestValue,
    required this.unit,
    required this.deltaText,
    required this.improving,
    required this.last7Days,
    required this.chartValues,
    required this.chartMinY,
    required this.chartMaxY,
    required this.chartInterval,
    required this.recentRecords,
  });

  final IndicatorKind kind;
  final String label;
  final String latestValue;
  final String unit;
  final String deltaText;
  final bool improving;

  /// Normalised series (0..1) used to paint the small inline sparkline
  /// on the My page indicator tile.
  final List<double> last7Days;

  /// Real values over the last 14 days, oldest → newest. Drives the
  /// trend-modal line chart.
  final List<double> chartValues;

  /// Y-axis floor for the trend-modal chart. Each indicator picks a
  /// clinically meaningful range (e.g. 70 for weight) rather than
  /// auto-fitting from the data, so day-to-day changes read at the
  /// right scale.
  final double chartMinY;

  /// Y-axis ceiling for the trend-modal chart. See [chartMinY].
  final double chartMaxY;

  /// Spacing between horizontal gridlines / Y-axis labels (e.g. 1 for
  /// weight 70-75, 10 for BP 100-140). Picked per indicator so the
  /// gridlines land on round numbers that fit the visible range.
  final double chartInterval;

  /// Five most-recent records (오늘 / 1일 전 / …) rendered in the
  /// trend modal's "최근 기록" section.
  final List<IndicatorRecord> recentRecords;

  factory IndicatorTrend.fromJson(Map<String, Object?> json) => IndicatorTrend(
    kind: _indicatorFromWire(json['kind']! as String),
    label: json['label']! as String,
    latestValue: json['latest_value']! as String,
    unit: json['unit']! as String,
    deltaText: json['delta_text']! as String,
    improving: json['improving']! as bool,
    last7Days: (json['last_7_days']! as List<Object?>)
        .map((v) => (v! as num).toDouble())
        .toList(),
    chartValues: (json['chart_values']! as List<Object?>)
        .map((v) => (v! as num).toDouble())
        .toList(),
    chartMinY: (json['chart_min_y']! as num).toDouble(),
    chartMaxY: (json['chart_max_y']! as num).toDouble(),
    chartInterval: (json['chart_interval']! as num).toDouble(),
    recentRecords: (json['recent_records']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(IndicatorRecord.fromJson)
        .toList(),
  );
}

enum SettingsKind { myProfile, healthGoal, notification, support }

SettingsKind _settingsKindFromWire(String s) => switch (s) {
  'health-goal' => SettingsKind.healthGoal,
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
    required this.indicators,
    required this.activityPoints,
    required this.activityRank,
    required this.settings,
  });

  final UserProfile profile;
  final RiskAlert risk;
  final List<IndicatorTrend> indicators;
  final int activityPoints;
  // 백엔드 계약상 nullable(schemas/user.py: activity_rank: Optional[int]).
  // 온보딩만 마친 일반 사용자는 순위가 아직 없어 null 로 온다 — 강제 언랩하면
  // My Health 화면 전체가 파싱 오류가 되므로 null 을 그대로 수용한다(UI 는 배지 숨김).
  final int? activityRank;
  final List<SettingsItem> settings;

  factory MyHealthState.fromJson(Map<String, Object?> json) => MyHealthState(
    profile: UserProfile.fromJson(json['profile']! as Map<String, Object?>),
    risk: RiskAlert.fromJson(json['risk']! as Map<String, Object?>),
    indicators: (json['indicators']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(IndicatorTrend.fromJson)
        .toList(),
    activityPoints: (json['activity_points']! as num).toInt(),
    activityRank: (json['activity_rank'] as num?)?.toInt(),
    settings: (json['settings']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(SettingsItem.fromJson)
        .toList(),
  );
}
