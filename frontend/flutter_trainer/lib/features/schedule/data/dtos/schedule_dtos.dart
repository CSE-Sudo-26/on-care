import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';

/// Maps the FastAPI `ScheduleSessionOut` JSON onto [ScheduleSession].
///
/// Every field is read defensively: a slot with one unexpected value
/// should render with a blank field, not blank the whole timeline.
ScheduleSession scheduleSessionFromJson(Map<String, dynamic> json) {
  return ScheduleSession(
    id: _str(json['id']),
    date: _str(json['date']),
    time: _str(json['time']),
    // 서버는 고객을 member_id 로 참조한다. 빈 문자열은 미등록(상담) 슬롯이라
    // null 로 눕혀 이름 폴백 경로와 같은 의미가 되게 한다(#386).
    clientId: _str(json['member_id']).isEmpty ? null : _str(json['member_id']),
    clientName: _str(json['client_name']),
    type: _str(json['type']),
    durationMinutes: _int(json['duration_minutes']),
    status: _str(json['status']),
    note: _str(json['note']),
    program: _programFromJson(json['program']),
    programSent: json['program_sent'] == true,
    cancelledAt: _time(json['cancelled_at']),
    cancellationSource: _str(json['cancellation_source']),
    cancellationReason: _str(json['cancellation_reason']),
    noShowAt: _time(json['no_show_at']),
  );
}

/// Encodes a program for `ScheduleCreateRequest` / `ScheduleUpdateRequest`.
List<Map<String, Object?>> programToJson(List<ProgramItem> program) {
  return <Map<String, Object?>>[
    for (final item in program) programItemToJson(item),
  ];
}

/// 항목 하나의 계약 형태. 서버 `ProgramItem` 스키마와 1:1 이다 (#1276).
Map<String, Object?> programItemToJson(ProgramItem item) => <String, Object?>{
  'name': item.name,
  'type': item.type,
  'date': item.date == null ? null : ymd(item.date!),
  'duration': item.duration,
  'sets': item.sets,
  'reps': item.reps,
  'weight': item.weight,
  'intensity': item.intensity,
  'session': item.session,
};

List<ProgramItem> _programFromJson(Object? raw) {
  if (raw is! List) return const <ProgramItem>[];
  return <ProgramItem>[
    for (final entry in raw)
      if (entry is Map<String, dynamic>) programItemFromJson(entry),
  ];
}

/// 계약 형태 → [ProgramItem].
///
/// 세트·중량·시간은 예전에 자유 문자열("10회"·"20kg")로 저장됐다 — 숫자만
/// 되짚어 읽는다(#1276). 서버의 `LooseInt`/`LooseFloat` 와 같은 규칙이다.
ProgramItem programItemFromJson(Map<String, Object?> entry) => ProgramItem(
  name: _str(entry['name']),
  // 이 키가 없던 예전 일정은 기본값으로 읽힌다(#1233).
  type: entry['type'] is String && (entry['type'] as String).isNotEmpty
      ? entry['type'] as String
      : '근력',
  date: DateTime.tryParse(_str(entry['date'])),
  duration: looseInt(entry['duration']),
  sets: looseInt(entry['sets']),
  reps: looseInt(entry['reps']),
  weight: looseDouble(entry['weight']),
  intensity:
      entry['intensity'] is String && (entry['intensity'] as String).isNotEmpty
      ? entry['intensity'] as String
      : 'moderate',
  // 세션 키가 없던 예전 일정은 빈 문자열 — 평면 목록으로 읽힌다(#709).
  session: _str(entry['session']),
);

/// 숫자거나 숫자를 품은 문자열("10회")이면 정수로. 아니면 null.
int? looseInt(Object? v) {
  if (v is num) return v.toInt();
  if (v is! String) return null;
  final String digits = v.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : int.parse(digits);
}

/// [looseInt] 의 소수 판 — 중량("20kg"·"12.5")용.
double? looseDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is! String) return null;
  return double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), ''));
}

String _str(Object? v) => v is String ? v : '';

/// 서버 타임스탬프. 값이 없거나 읽을 수 없으면 null — 취소 시각 하나 때문에
/// 하루 전체가 비지 않게 한다(다른 필드와 같은 방어 규약).
DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;

// FastAPI emits JSON numbers that can decode as double on web — normalise
// through num so `as int` never throws.
int _int(Object? v) => v is num ? v.toInt() : 0;
