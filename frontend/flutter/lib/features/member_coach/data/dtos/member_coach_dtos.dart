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
/// member's viewpoint `sender` is `me` | `trainer`; anything that isn't
/// `trainer` maps to [CoachSender.me].
CoachMessage coachMessageFromJson(Map<String, Object?> json) {
  return CoachMessage(
    id: _str(json['id']),
    sender: json['sender'] == 'trainer' ? CoachSender.trainer : CoachSender.me,
    body: _str(json['body']),
    timeLabel: _str(json['time_label']),
  );
}

String _str(Object? v) => v is String ? v : '';
