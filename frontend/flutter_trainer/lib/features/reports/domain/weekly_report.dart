import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
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
    this.weekCompletion = const <int>[],
    this.sodiumWeek = const <int>[],
    this.caloriesWeek = const <int>[],
    this.sugarWeek = const <double>[],
    this.days = const <ReportDay>[],
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

  /// Whether [weekStart] is the week we're currently in. Charts no longer
  /// depend on this — the report carries its own week — but the headline
  /// still says "이번 주" or "선택 주".
  final bool isCurrentWeek;

  /// 그 주(월→일)의 요일별 값. **로스터의 같은 이름 필드를 쓰지 않는다** —
  /// 그건 이번 주 것이라, 과거 주를 열면 지난 주 날짜 아래 이번 주 수치가
  /// 실린다. 트레이너는 그 리포트를 회원에게 그대로 보낼 수 있다(#752).
  final List<int> weekCompletion;

  /// 그 주의 일별 나트륨(mg).
  final List<int> sodiumWeek;

  /// 그 주의 일별 칼로리(kcal).
  final List<int> caloriesWeek;

  /// 그 주의 일별 당류(g). 소수를 유지한다.
  final List<double> sugarWeek;

  /// 요일별 상세(월→일). 이행률과 그날 배정된 운동을 함께 담는다 — 67% 가
  /// 어디서 나온 값인지 화면에서 보이게 하는 자료다(#754).
  final List<ReportDay> days;

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
  WeekSeries? week,
}) {
  final start = weekStartOf(weekStart);
  final end = start.add(const Duration(days: 6));
  final inWeek = sessions.where((s) {
    final day = DateTime.tryParse(s.date);
    if (day == null || s.isGap) return false;
    return !day.isBefore(start) && !day.isAfter(end);
  }).toList();

  // 로스터가 준 계열(`client.*Week`)은 **이번 주** 것이라 그 주에만 붙인다.
  // 과거 주에 붙이면 지난 주 날짜 아래 이번 주 수치가 실리고, 트레이너는 그
  // 리포트를 회원에게 그대로 보낼 수 있다. 과거 주의 계열은 호출자가
  // [week] 로 넘겨 준다(데모는 drift 이력에서, 실서버는 리포트 응답에서).
  final isThisWeek = start == weekStartOf(today ?? DateTime.now());
  final series = week ?? (isThisWeek ? WeekSeries.of(client) : null);
  // Same "recorded days only" rule the 주의 badge and 고객 검색 use.
  final mean = series == null
      ? null
      : recordedMean(series.completion)?.round();

  return WeeklyReport(
    isCurrentWeek: isThisWeek,
    client: client,
    weekStart: start,
    sessionsBooked: inWeek.length,
    sessionsDone: inWeek.where((s) => s.isDone).length,
    completionAvg: mean,
    sodiumOverDays: series == null ? null : sodiumOverDaysOf(series.sodium),
    sodiumAvg: series == null ? null : recordedMean(series.sodium)?.round(),
    weekCompletion: series?.completion ?? const <int>[],
    days: series?.days ?? const <ReportDay>[],
    sodiumWeek: series?.sodium ?? const <int>[],
    caloriesWeek: series?.calories ?? const <int>[],
    sugarWeek: series?.sugar ?? const <double>[],
  );
}

/// 리포트의 하루 — 이행률과 그날 배정된 운동.
class ReportDay {
  /// Creates a day.
  const ReportDay({required this.completion, this.exercises = const <String>[]});

  /// 그날 이행률(%). 0 은 기록이 없다는 뜻이다.
  final int completion;

  /// 배정된 운동 이름. 끝의 '✗' 는 건너뛴 운동을 뜻하는 저장 규칙이다 —
  /// 운동 기록 탭과 같은 규칙을 쓴다.
  final List<String> exercises;

  /// 건너뛰지 않은 운동 수.
  int get done => exercises.where((e) => !e.contains('✗')).length;

  /// 배정된 운동 수.
  int get total => exercises.length;
}

/// 한 주의 요일별 값 묶음(월→일). 데모는 drift 이력에서, 실서버는 리포트
/// 응답에서 만든다.
class WeekSeries {
  /// Creates a week's series.
  const WeekSeries({
    required this.completion,
    required this.sodium,
    required this.calories,
    required this.sugar,
    this.days = const <ReportDay>[],
  });

  /// 로스터가 준 이번 주 계열.
  factory WeekSeries.of(TrainerClient client) => WeekSeries(
    days: <ReportDay>[
      for (final rate in client.weekCompletion) ReportDay(completion: rate),
    ],
    completion: client.weekCompletion,
    sodium: client.sodiumWeek,
    calories: client.caloriesWeek,
    sugar: client.sugarWeek,
  );

  /// 일별 이행률(%).
  final List<int> completion;

  /// 일별 나트륨(mg).
  final List<int> sodium;

  /// 일별 칼로리(kcal).
  final List<int> calories;

  /// 일별 당류(g).
  final List<double> sugar;

  /// 요일별 상세. 데모는 drift 이력에서, 실서버는 리포트 응답에서 온다.
  final List<ReportDay> days;
}

/// 기록된 날(0 초과)만의 평균. 하나도 없으면 null — 0 으로 보고하면
/// "아무것도 안 했다"는 거짓말이 된다.
double? recordedMean(List<num> series) {
  final recorded = series.where((v) => v > 0).toList(growable: false);
  if (recorded.isEmpty) return null;
  // fold<double> 로 더한다 — `List<int>` 를 `List<num>` 으로 받으면 reduce 의
  // 결합 함수가 런타임 타입(int)과 맞지 않아 던진다.
  return recorded.fold<double>(0, (sum, v) => sum + v) / recorded.length;
}

/// 나트륨 목표를 넘긴 날 수.
int sodiumOverDaysOf(List<int> sodium) =>
    sodium.where((mg) => mg > sodiumTargetMg).length;

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
