import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';

/// One exercise in a PT session's program (e.g. 레그프레스 3세트 × 12회 · 80kg).
class ProgramItem {
  /// Creates a program item.
  const ProgramItem({
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
    this.session = '',
  });

  /// Exercise name.
  final String name;

  /// Set count.
  final int sets;

  /// Reps label (e.g. "12회", "10분", "45초").
  final String reps;

  /// Weight label (e.g. "80kg", "자체중량", "-" for none).
  final String weight;

  /// Which session of a multi-session program this item belongs to (#709).
  ///
  /// Empty for a single-session program and for rows written before sessions
  /// existed — the schedule then reads as the flat list it always was.
  final String session;
}

/// One slot on the trainer's daily timeline (스케줄 탭). Decoded from
/// the drift `TrainerScheduleEntries` row (`programJson` → [program]).
class ScheduleSession {
  /// Creates a schedule slot.
  const ScheduleSession({
    required this.id,
    required this.date,
    required this.time,
    this.clientId,
    required this.clientName,
    required this.type,
    required this.durationMinutes,
    required this.status,
    required this.note,
    required this.program,
  });

  /// Row id.
  final String id;

  /// Calendar day (`YYYY-MM-DD`). Carried on the entity because the week
  /// calendar and the client's 루틴 tab both render sessions from more
  /// than one day at a time.
  final String date;

  /// Slot time (e.g. "10:00").
  final String time;

  /// Booked client's id. Null for gap slots, 미등록(상담) 고객, and rows
  /// stored before v3 — see the drift column comment (#386).
  final String? clientId;

  /// Booked client's display name — empty for a gap slot. 표시 전용이다.
  /// 조회는 [clientId] 로 한다.
  final String clientName;

  /// Session kind (e.g. "1:1 PT", "상담") — empty for a gap.
  final String type;

  /// Duration in minutes (0 for a gap).
  final int durationMinutes;

  /// 완료 | 예정 | 공백.
  final String status;

  /// Trainer's note for the session (may be empty).
  final String note;

  /// The session's exercise program (empty when none).
  final List<ProgramItem> program;

  /// Whether this is an empty ("빈 시간") slot.
  bool get isGap => status == ScheduleStatus.gap;

  /// Whether the session is done.
  bool get isDone => status == ScheduleStatus.done;

  /// Whether the session is still upcoming (예정).
  bool get isUpcoming => status == ScheduleStatus.upcoming;

  /// Whether the card can expand. Every booked session opens: 완료 shows
  /// the finished program, 예정 shows the plan (or a no-plan hint), and
  /// both expose the manage/chat actions.
  bool get expandable => !isGap;
}

/// [session] 이 지금부터 [leadMinutes] 안에 시작하는가. (#817)
///
/// 이미 지난 시각과 완료·공백 슬롯은 대상이 아니다 — 강조는 "곧 해야 할 일"
/// 을 가리키는 표시이고, 끝난 수업을 다시 눈에 띄게 만들 이유가 없다.
/// `HH:mm` 이 아닌 값(빈 시간 등)은 시각을 알 수 없으므로 조용히 false 다.
bool startsWithin(ScheduleSession session, int leadMinutes, {DateTime? now}) {
  if (!session.isUpcoming || leadMinutes <= 0) return false;
  final parts = session.time.split(':');
  if (parts.length != 2) return false;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return false;
  final current = now ?? DateTime.now();
  final startsAt = DateTime(
    current.year,
    current.month,
    current.day,
    hour,
    minute,
  );
  if (!startsAt.isAfter(current)) return false;
  return startsAt.difference(current).inMinutes <= leadMinutes;
}
