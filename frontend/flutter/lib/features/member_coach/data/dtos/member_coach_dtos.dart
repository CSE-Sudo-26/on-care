import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';

/// `/me/coach` (MemberCoachOut) → [MemberCoach].
MemberCoach memberCoachFromJson(Map<String, Object?> json) {
  final gym = json['gym'];
  return MemberCoach(
    trainerId: _str(json['trainer_id']),
    name: _str(json['name']),
    specialty: _str(json['specialty']),
    career: _str(json['career']),
    intro: _str(json['intro']),
    gymName: gym is Map<String, Object?> ? _str(gym['name']) : '',
    goal: _str(json['goal']),
  );
}

/// `/me/coach/routines` element (RoutineOut) → [CoachRoutine].
CoachRoutine coachRoutineFromJson(Map<String, Object?> json) {
  return CoachRoutine(
    id: _str(json['id']),
    name: _str(json['name']),
    minutes: json['minutes'] is num ? (json['minutes']! as num).toInt() : 0,
    type: _str(json['type']),
    reason: _str(json['reason']),
    source: _str(json['source']),
    completed: json['completed'] == true,
    completedAt: DateTime.tryParse(_str(json['completed_at'])),
    completedMinutes: json['completed_minutes'] is num
        ? (json['completed_minutes']! as num).toInt()
        : null,
    completedIntensity: json['completed_intensity'] as String?,
    memberNote: _str(json['member_note']),
    trainerFeedback: _str(json['trainer_feedback']),
    programName: _str(json['program_name']),
    sessionName: _str(json['session_name']),
    sessionOrder: json['session_order'] is num
        ? (json['session_order']! as num).toInt()
        : 0,
    exercises: _coachRoutineExercises(json['exercises']),
  );
}

/// `RoutineOut.exercises` → [CoachRoutineExercise] 목록. (#709)
///
/// 키가 아예 없던 예전 응답은 빈 목록이라, 화면이 예전처럼 [CoachRoutine.reason]
/// 만 보여 준다.
List<CoachRoutineExercise> _coachRoutineExercises(Object? raw) {
  if (raw is! List) return const <CoachRoutineExercise>[];
  return <CoachRoutineExercise>[
    for (final entry in raw)
      if (entry is Map<String, Object?>)
        CoachRoutineExercise(
          name: _str(entry['name']),
          sets: _str(entry['sets']),
          reps: _str(entry['reps']),
          weight: _str(entry['weight']),
          duration: _str(entry['duration']),
          rest: _str(entry['rest']),
          memo: _str(entry['memo']),
        ),
  ];
}

/// `/me/coach/sessions` element (ScheduleSessionOut) → [CoachSession].
///
/// 날짜가 깨져도 던지지 않는다 — 한 행 때문에 일정 전체가 사라지면 안 된다.
/// 화면이 date == null 인 항목을 걸러낸다.
CoachSession coachSessionFromJson(Map<String, Object?> json) {
  final Object? rawProgram = json['program'];
  return CoachSession(
    id: _str(json['id']),
    date: DateTime.tryParse(_str(json['date'])),
    time: _str(json['time']),
    type: _str(json['type']),
    durationMinutes: json['duration_minutes'] is num
        ? (json['duration_minutes']! as num).toInt()
        : 0,
    status: _str(json['status']),
    note: _str(json['note']),
    program: rawProgram is List<Object?>
        ? rawProgram
              .map((Object? item) {
                if (item is! Map<String, Object?>) {
                  throw const FormatException('Invalid coach program item.');
                }
                return CoachProgramItem(
                  name: _str(item['name']),
                  sets: item['sets'] is num
                      ? (item['sets']! as num).toInt()
                      : 0,
                  reps: _str(item['reps']),
                  weight: _str(item['weight']),
                );
              })
              .toList(growable: false)
        : const <CoachProgramItem>[],
  );
}

/// `/me/coach/chat` element (ChatMessageOut) → [CoachMessage]. From the
/// member's viewpoint `sender` is `me` | `trainer`.
CoachMessage coachMessageFromJson(Map<String, Object?> json) {
  final CoachSender sender = switch (json['sender']) {
    'me' => CoachSender.me,
    'trainer' => CoachSender.trainer,
    _ => throw const FormatException('Invalid member chat sender.'),
  };

  return CoachMessage(
    id: _requiredString(json, 'id'),
    sender: sender,
    body: _requiredString(json, 'body'),
    timeLabel: _requiredString(json, 'time_label'),
    createdAt: _requiredDateTime(json, 'created_at'),
  );
}

String _str(Object? v) => v is String ? v : '';

String _requiredString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is String) return value;
  throw FormatException('Invalid member chat $key.');
}

DateTime _requiredDateTime(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is String) {
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Invalid member chat $key.');
}
