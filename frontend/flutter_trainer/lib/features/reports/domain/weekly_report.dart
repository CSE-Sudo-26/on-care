import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

/// Monday of the week containing [day], stripped to a date.
DateTime weekStartOf(DateTime day) {
  final date = DateTime(day.year, day.month, day.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

/// One client's week, as the trainer would summarise it to them.
///
/// This is the retention loop of an O2O coaching product: the member
/// stays because they can see they improved. Everything here is derived
/// from data the two apps already share — no new tracking.
class WeeklyReport {
  /// Creates a report.
  const WeeklyReport({
    required this.client,
    required this.weekStart,
    required this.sessionsBooked,
    required this.sessionsDone,
    required this.completionAvg,
    required this.sodiumOverDays,
    required this.sodiumAvg,
  });

  /// Who the report is about.
  final TrainerClient client;

  /// Monday of the reported week.
  final DateTime weekStart;

  /// PT sessions booked in the week.
  final int sessionsBooked;

  /// Of those, how many were completed.
  final int sessionsDone;

  /// Mean routine completion (%) across recorded days; null when the
  /// client logged nothing.
  final int? completionAvg;

  /// Days over the sodium target.
  final int sodiumOverDays;

  /// Mean daily sodium (mg); null when there's no history.
  final int? sodiumAvg;

  /// Sunday of the reported week.
  DateTime get weekEnd => weekStart.add(const Duration(days: 6));

  /// `M월 D일 – M월 D일`.
  String get rangeLabel =>
      '${weekStart.month}월 ${weekStart.day}일 – ${weekEnd.month}월 ${weekEnd.day}일';

  /// Session attendance as a percentage; null when nothing was booked.
  int? get attendanceRate => sessionsBooked == 0
      ? null
      : ((sessionsDone / sessionsBooked) * 100).round();

  /// Whether the week is worth celebrating — drives the headline's tone.
  bool get isGoodWeek => (completionAvg ?? 0) >= 70 && sodiumOverDays <= 2;
}

/// Builds [client]'s report for the week starting [weekStart].
///
/// [sessions] should be that client's sessions; entries outside the week
/// are ignored here rather than at the call site, so a caller passing
/// the full history still gets a correct week.
WeeklyReport buildWeeklyReport({
  required TrainerClient client,
  required List<ScheduleSession> sessions,
  required DateTime weekStart,
}) {
  final start = weekStartOf(weekStart);
  final end = start.add(const Duration(days: 6));
  final inWeek = sessions.where((s) {
    final day = DateTime.tryParse(s.date);
    if (day == null || s.isGap) return false;
    return !day.isBefore(start) && !day.isAfter(end);
  }).toList();

  final recorded = client.weekCompletion.where((d) => d > 0).toList();

  return WeeklyReport(
    client: client,
    weekStart: start,
    sessionsBooked: inWeek.length,
    sessionsDone: inWeek.where((s) => s.isDone).length,
    completionAvg: recorded.isEmpty
        ? null
        : (recorded.reduce((a, b) => a + b) / recorded.length).round(),
    sodiumOverDays: client.sodiumOverDays,
    sodiumAvg: client.sodiumWeekAvg,
  );
}

/// The message body sent to the member's chat thread.
///
/// Plain text on purpose: it lands in the same thread the member already
/// reads, so it must look like something their trainer wrote, not a
/// system dump.
String reportMessage(WeeklyReport report) {
  final lines = <String>[
    '📊 ${report.rangeLabel} 주간 리포트',
    'PT 세션 ${report.sessionsDone}/${report.sessionsBooked}회 완료',
    if (report.completionAvg != null) '운동 이행률 평균 ${report.completionAvg}%',
    if (report.sodiumAvg != null)
      '나트륨 평균 ${report.sodiumAvg}mg · 목표 초과 ${report.sodiumOverDays}일',
    report.isGoodWeek
        ? '이번 주 정말 잘하셨어요. 다음 주도 이 페이스 유지해요!'
        : '다음 주에는 조금만 더 챙겨봐요. 제가 루틴을 조정해 둘게요.',
  ];
  return lines.join('\n');
}

/// The trainer's own week — the numbers that answer "how am I doing?".
class TrainerWeekStats {
  /// Creates the stats.
  const TrainerWeekStats({
    required this.sessionsBooked,
    required this.sessionsDone,
    required this.activeClients,
    required this.programsSent,
  });

  /// Sessions booked this week.
  final int sessionsBooked;

  /// Sessions completed this week.
  final int sessionsDone;

  /// Clients marked 활성.
  final int activeClients;

  /// Sessions that carry a program (i.e. a routine was prepared).
  final int programsSent;

  /// Completion rate as a percentage; null when nothing was booked.
  int? get completionRate => sessionsBooked == 0
      ? null
      : ((sessionsDone / sessionsBooked) * 100).round();
}

/// Aggregates the trainer's week from every session in the range.
TrainerWeekStats buildTrainerWeekStats({
  required List<ScheduleSession> sessions,
  required List<TrainerClient> clients,
}) {
  final booked = sessions.where((s) => !s.isGap).toList();
  return TrainerWeekStats(
    sessionsBooked: booked.length,
    sessionsDone: booked.where((s) => s.isDone).length,
    activeClients: clients.where((c) => c.active).length,
    programsSent: booked.where((s) => s.program.isNotEmpty).length,
  );
}
