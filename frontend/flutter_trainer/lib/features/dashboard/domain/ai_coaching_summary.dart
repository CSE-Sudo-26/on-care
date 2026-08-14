/// 대시보드에 표시할 고객 한 명의 실행 가능한 코칭 인사이트.
class AiCoachingClientInsight {
  const AiCoachingClientInsight({
    required this.memberId,
    required this.memberName,
    required this.priority,
    required this.statusSummary,
    required this.evidence,
    required this.exerciseFocus,
    required this.caution,
  });

  final String memberId;
  final String memberName;
  final CoachingPriority priority;
  final String statusSummary;
  final List<String> evidence;
  final String exerciseFocus;
  final String caution;

  factory AiCoachingClientInsight.fromJson(Map<String, Object?> json) {
    return AiCoachingClientInsight(
      memberId: _requiredString(json, 'member_id'),
      memberName: _requiredString(json, 'member_name'),
      priority: CoachingPriority.fromWire(_requiredString(json, 'priority')),
      statusSummary: _requiredString(json, 'status_summary'),
      evidence: _stringList(json['evidence']),
      exerciseFocus: _requiredString(json, 'exercise_focus'),
      caution: _optionalString(json, 'caution'),
    );
  }
}

enum CoachingPriority {
  high,
  medium,
  low;

  static CoachingPriority fromWire(String value) {
    return switch (value) {
      'high' => high,
      'medium' => medium,
      'low' => low,
      _ => throw FormatException('Unknown coaching priority: $value'),
    };
  }
}

/// 문장 자체가 아니라 화면이 로케일에 맞춰 표현해야 하는 규칙형 요약 상태.
enum CoachingSummaryKind { details, noClients, allOnTrack }

/// 식단·운동·건강 프로필·대화 기록을 종합한 오늘의 AI 코칭 요약.
class AiCoachingSummary {
  const AiCoachingSummary({
    required this.headline,
    required this.clients,
    required this.generatedBy,
    required this.dataAsOf,
    this.kind = CoachingSummaryKind.details,
    this.totalClients = 0,
  });

  final String headline;
  final List<AiCoachingClientInsight> clients;
  final String generatedBy;
  final DateTime? dataAsOf;
  final CoachingSummaryKind kind;
  final int totalClients;

  factory AiCoachingSummary.fromJson(Map<String, Object?> json) {
    final rawClients = json['clients'];
    if (rawClients is! List) {
      throw const FormatException('Coaching summary clients must be a list.');
    }
    final clients = <AiCoachingClientInsight>[];
    for (final item in rawClients) {
      if (item is! Map<String, Object?>) {
        throw const FormatException(
          'Coaching summary client must be an object.',
        );
      }
      clients.add(AiCoachingClientInsight.fromJson(item));
    }
    final generatedBy = _requiredString(json, 'generated_by');
    if (generatedBy != 'ai' && generatedBy != 'rule') {
      throw FormatException('Unknown coaching summary source: $generatedBy');
    }
    final dataAsOf = DateTime.tryParse(_requiredString(json, 'data_as_of'));
    if (dataAsOf == null) {
      throw const FormatException('Invalid coaching summary date.');
    }
    return AiCoachingSummary(
      headline: _requiredString(json, 'headline'),
      clients: List<AiCoachingClientInsight>.unmodifiable(clients),
      generatedBy: generatedBy,
      dataAsOf: dataAsOf,
    );
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing coaching summary field: $key');
  }
  return value;
}

String _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return '';
  if (value is! String) {
    throw FormatException('Invalid coaching summary field: $key');
  }
  return value;
}

List<String> _stringList(Object? value) {
  if (value is! List || value.any((item) => item is! String)) {
    throw const FormatException(
      'Coaching summary evidence must be a string list.',
    );
  }
  return List<String>.unmodifiable(value.cast<String>());
}
