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
  );
}

/// Encodes a program for `ScheduleCreateRequest` / `ScheduleUpdateRequest`.
List<Map<String, Object?>> programToJson(List<ProgramItem> program) {
  return <Map<String, Object?>>[
    for (final item in program)
      <String, Object?>{
        'name': item.name,
        'sets': item.sets,
        'reps': item.reps,
        'weight': item.weight,
      },
  ];
}

List<ProgramItem> _programFromJson(Object? raw) {
  if (raw is! List) return const <ProgramItem>[];
  return <ProgramItem>[
    for (final entry in raw)
      if (entry is Map<String, dynamic>)
        ProgramItem(
          name: _str(entry['name']),
          sets: _int(entry['sets']),
          reps: _str(entry['reps']),
          weight: _str(entry['weight']),
        ),
  ];
}

String _str(Object? v) => v is String ? v : '';

// FastAPI emits JSON numbers that can decode as double on web — normalise
// through num so `as int` never throws.
int _int(Object? v) => v is num ? v.toInt() : 0;
