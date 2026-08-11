import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

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
    required this.isCurrentWeek,
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

  /// Days over the sodium target; null when unknown for this week.
  final int? sodiumOverDays;

  /// Mean daily sodium (mg); null when there's no history.
  final int? sodiumAvg;

  /// Whether [weekStart] is the week we're currently in. The roster's
  /// weekday aggregates only describe this week, so a past week must not
  /// render them.
  final bool isCurrentWeek;

  /// Sunday of the reported week.
  DateTime get weekEnd => weekStart.add(const Duration(days: 6));

  /// `M월 D일 – M월 D일` / `M/D – M/D`, in the current locale.
  String rangeLabel(AppLocalizations l) => l.dateRange(
    l.dateMonthDay(weekStart.month, weekStart.day),
    l.dateMonthDay(weekEnd.month, weekEnd.day),
  );

  /// Session attendance as a percentage; null when nothing was booked.
  int? get attendanceRate => sessionsBooked == 0
      ? null
      : ((sessionsDone / sessionsBooked) * 100).round();

  /// Whether the week is worth celebrating — drives the headline's tone.
  /// An unknown figure is not a good one: praise has to be earned by
  /// data we actually have.
  bool get isGoodWeek =>
      (completionAvg ?? 0) >= 70 && (sodiumOverDays ?? 99) <= 2;
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
  DateTime? today,
}) {
  final start = weekStartOf(weekStart);
  final end = start.add(const Duration(days: 6));
  final inWeek = sessions.where((s) {
    final day = DateTime.tryParse(s.date);
    if (day == null || s.isGap) return false;
    return !day.isBefore(start) && !day.isAfter(end);
  }).toList();

  // `weekCompletion` / `sodiumWeek` are THIS week's aggregates, computed
  // by the roster — they carry no week of their own. Attaching them to a
  // past week would report this week's numbers under last week's dates,
  // and the trainer can SEND that to the member. Leave them unknown
  // instead: the screen shows "-", which reads as missing rather than
  // wrong.
  final isThisWeek = start == weekStartOf(today ?? DateTime.now());
  // Same "recorded days only" rule the 주의 badge and 고객 검색 use.
  final mean = isThisWeek ? recordedCompletionMean(client) : null;

  return WeeklyReport(
    isCurrentWeek: isThisWeek,
    client: client,
    weekStart: start,
    sessionsBooked: inWeek.length,
    sessionsDone: inWeek.where((s) => s.isDone).length,
    completionAvg: mean?.round(),
    sodiumOverDays: isThisWeek ? client.sodiumOverDays : null,
    sodiumAvg: isThisWeek ? client.sodiumWeekAvg : null,
  );
}

/// The message body sent to the member's chat thread.
///
/// Plain text on purpose: it lands in the same thread the member already
/// reads, so it must look like something their trainer wrote, not a
/// system dump.
String reportMessage(AppLocalizations l, WeeklyReport report) {
  final lines = <String>[
    l.reportBodyTitle(report.rangeLabel(l)),
    l.reportBodySessions(report.sessionsDone, report.sessionsBooked),
    if (report.completionAvg != null)
      l.reportBodyCompletion(report.completionAvg!),
    if (report.sodiumAvg != null)
      l.reportBodySodium(report.sodiumAvg!, report.sodiumOverDays ?? 0),
    report.isGoodWeek ? l.reportBodyPraise : l.reportBodyEncourage,
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
