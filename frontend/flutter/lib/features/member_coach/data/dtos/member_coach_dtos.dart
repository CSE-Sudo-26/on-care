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
