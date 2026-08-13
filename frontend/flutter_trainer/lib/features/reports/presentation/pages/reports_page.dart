import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart'
    show elapsedWeekdays, weekdayCount, weekdayLabels;
import 'package:oncare_trainer/features/reports/data/repositories/report_repository.dart';
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/search/domain/client_search_scope.dart';
import 'package:oncare_trainer/features/search/presentation/widgets/client_search_bar.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/mini_charts.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';
import 'package:oncare_trainer/shared/widgets/stat_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 리포트 — the week, from two angles.
///
/// **운영 지표** answers "how did my week go?" (sessions, completion,
/// programs prepared). **고객 주간 리포트** turns one client's week into
/// something the trainer can send them — the retention loop of an O2O
/// coaching product, since a member renews when they can see progress.
///
/// Sending delivers into the member's existing chat thread rather than a
/// separate report inbox: it arrives where they already read, and it
/// works identically in demo and against the real API.
class ReportsPage extends ConsumerStatefulWidget {
  /// Creates the reports page. [clientId] preselects a client.
  const ReportsPage({super.key, this.clientId});

  /// Client focused via the `client` query parameter.
  final String? clientId;

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  /// Selected client id; null falls back to the first in the roster.
  late String? _clientId = widget.clientId;

  /// Monday of the week being reported. Starts on this week.
  DateTime _weekStart = weekStartOf(DateTime.now());

  /// Clients whose report was sent this session — keeps the button from
  /// being pressed twice in a row by accident.
  final Set<String> _sent = <String>{};

  /// A send is in flight for this client.
  String? _sending;

  @override
  void didUpdateWidget(ReportsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clientId != null && widget.clientId != oldWidget.clientId) {
      setState(() => _clientId = widget.clientId);
    }
  }

  void _selectClient(String id) {
    if (_clientId == id) return;
    setState(() => _clientId = id);
    context.go(AppRoutes.reportFor(id));
  }

  void _shiftWeek(int direction) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * direction));
      // A different week is a different report — allow sending again.
      _sent.clear();
    });
  }

  Future<void> _send(WeeklyReport report, String message) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final id = report.client.id;
    if (_sending != null || _sent.contains(id)) return;
    // messenger 와 마찬가지로 l 도 위에서 await 전에 잡아 뒀다.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = id);
    try {
      await ref
          .read(reportRepositoryProvider)
          .send(clientId: id, weekStart: report.weekStart, message: message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = null);
      messenger.showSnackBar(SnackBar(content: Text(l.reportsSendFailed)));
      return;
    }
    if (!mounted) return;
    setState(() {
      _sending = null;
      _sent.add(id);
    });
    messenger.showSnackBar(
      SnackBar(content: Text(l.reportsSent(report.client.name))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final clientsAsync = ref.watch(clientsProvider);
    final range = (
      from: ymd(_weekStart),
      to: ymd(_weekStart.add(const Duration(days: 6))),
    );
    final weekSessions = ref.watch(scheduleRangeProvider(range));

    return PageScaffold(
      title: l.reportsTitle,
      subtitle: l.reportsSubtitle(
        l.dateMonthDay(_weekStart.month, _weekStart.day),
      ),
      // 리포트 asks how the week went, so the rows lead with this week's
      // completion and picking one opens that client's report.
      headerCenter: const ClientSearchBar(scope: ClientSearchScope.reports),
      actions: <Widget>[
        ActionButton(
          label: l.reportsPrevWeek,
          icon: Icons.chevron_left,
          onPressed: () => _shiftWeek(-1),
        ),
        ActionButton(
          label: l.reportsNextWeek,
          icon: Icons.chevron_right,
          onPressed: () => _shiftWeek(1),
        ),
      ],
      child: clientsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: AppSpacing.xxxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: EdgeInsets.only(top: AppSpacing.xxxl),
          child: EmptyHint(
            message: l.reportsLoadFailed,
            icon: Icons.error_outline,
            action: ActionButton(
              key: const ValueKey<String>('reports-clients-retry'),
              label: l.actionRetry,
              onPressed: clientsAsync.isLoading
                  ? null
                  : () => ref.invalidate(clientsProvider),
            ),
          ),
        ),
        data: (clients) {
          if (clients.isEmpty) {
            return Padding(
              padding: EdgeInsets.only(top: AppSpacing.xxxl),
              child: EmptyHint(
                message: l.reportsNoClients,
                icon: Icons.insights_outlined,
              ),
            );
          }
          final selected = clients.firstWhere(
            (c) => c.id == _clientId,
            orElse: () => clients.first,
          );
          // The week query covers every client; each consumer filters.
          // A failed load leaves it empty rather than blanking the page —
          // the client-side figures below are still meaningful.
          final sessions = weekSessions.valueOrNull ?? const [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _TrainerStats(
                stats: buildTrainerWeekStats(
                  sessions: sessions,
                  clients: clients,
                ),
                loading: weekSessions.isLoading,
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide =
                      constraints.maxWidth >= AppLayout.twoColumnBreakpoint;
                  final picker = _ClientPicker(
                    clients: clients,
                    selectedId: selected.id,
                    onSelect: _selectClient,
                  );
                  // The report itself comes from the repository: local
                  // in demo, server-aggregated against the real API
                  // (only the backend has the member's full history).
                  final reportKey = (client: selected, weekStart: _weekStart);
                  final reportAsync = ref.watch(
                    weeklyReportProvider(reportKey),
                  );
                  final report = reportAsync.when(
                    loading: () => SectionCard(
                      title: l.reportsWeekly,
                      icon: Icons.description_outlined,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (e, _) => SectionCard(
                      title: l.reportsWeekly,
                      icon: Icons.description_outlined,
                      child: EmptyHint(
                        message: l.reportsLoadFailed,
                        icon: Icons.error_outline,
                        action: ActionButton(
                          key: const ValueKey<String>('reports-weekly-retry'),
                          label: l.actionRetry,
                          onPressed: reportAsync.isLoading
                              ? null
                              : () => ref.invalidate(
                                  weeklyReportProvider(reportKey),
                                ),
                        ),
                      ),
                    ),
                    data: (data) => _ClientReport(
                      report: data,
                      sent: _sent.contains(selected.id),
                      sending: _sending == selected.id,
                      onSend: _send,
                    ),
                  );

                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        picker,
                        const SizedBox(height: AppSpacing.lg),
                        report,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(width: 260, child: picker),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(child: report),
                    ],
                  );
                },
              ),
              if (weekSessions.hasError)
                Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    l.reportsScheduleWarning,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The trainer's own week.
class _TrainerStats extends StatelessWidget {
  const _TrainerStats({required this.stats, required this.loading});

  final TrainerWeekStats stats;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    String value(int n) => loading ? '-' : '$n';
    final rate = stats.completionRate;

    return LayoutBuilder(
      builder: (context, constraints) {
        final AppLocalizations l = AppLocalizations.of(context);
        final cards = <Widget>[
          StatCard(
            label: l.reportsSessionsThisWeek,
            value: value(stats.sessionsBooked),
            unit: l.unitTimes,
            icon: Icons.event_note_outlined,
          ),
          StatCard(
            label: l.legendDone,
            value: value(stats.sessionsDone),
            unit: l.unitTimes,
            icon: Icons.check_circle_outline,
            tone: StatTone.positive,
            hint: rate == null || loading
                ? null
                : l.reportsCompletionRate(rate),
          ),
          StatCard(
            label: l.reportsProgramReady,
            value: value(stats.programsSent),
            unit: l.dashUnitCount,
            icon: Icons.assignment_outlined,
            hint: l.reportsSessionsWithRoutine,
          ),
          StatCard(
            label: l.reportsActiveClients,
            value: '${stats.activeClients}',
            unit: l.dashUnitPeople,
            icon: Icons.groups_outlined,
          ),
        ];
        final wide = constraints.maxWidth >= AppLayout.twoColumnBreakpoint;
        // IntrinsicHeight so every card in a row matches the tallest —
        // only some carry a hint line, and without this the row reads as
        // four cards of four different heights.
        if (wide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < cards.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(child: cards[i]),
                ],
              ],
            ),
          );
        }
        return Column(
          children: <Widget>[
            for (var i = 0; i < cards.length; i += 2) ...<Widget>[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: cards[i]),
                    const SizedBox(width: AppSpacing.md),
                    if (i + 1 < cards.length)
                      Expanded(child: cards[i + 1])
                    else
                      const Spacer(),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ClientPicker extends StatelessWidget {
  const _ClientPicker({
    required this.clients,
    required this.selectedId,
    required this.onSelect,
  });

  final List<TrainerClient> clients;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return SectionCard(
      title: l.reportsPickClient,
      icon: Icons.people_outline,
      dense: true,
      child: Column(
        children: <Widget>[
          for (final client in clients)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Material(
                color: client.id == selectedId
                    ? AppColors.accentSurface
                    : Colors.transparent,
                borderRadius: const BorderRadius.all(AppRadius.md),
                child: InkWell(
                  onTap: () => onSelect(client.id),
                  borderRadius: const BorderRadius.all(AppRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: <Widget>[
                        ClientAvatar(label: client.avatar, size: 26),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            client.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: client.id == selectedId
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: AppColors.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One client's week, ready to send.
/// Colour for a figure that may be unknown.
///
/// A null value renders "-", and painting that with the good/bad colour
/// would state a verdict the data can't support — an unknown week would
/// read as a clean one. Unknown gets the neutral foreground.
Color _verdictTone(int? value, Color Function(int) verdict) =>
    value == null ? AppColors.subtleForeground : verdict(value);

class _ClientReport extends StatelessWidget {
  const _ClientReport({
    required this.report,
    required this.sent,
    required this.sending,
    required this.onSend,
  });

  final WeeklyReport report;
  final bool sent;
  final bool sending;
  final void Function(WeeklyReport report, String message) onSend;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final client = report.client;
    return SectionCard(
      title: l.reportsClientWeekly(client.name),
      icon: Icons.description_outlined,
      trailing: Text(
        report.rangeLabel(l),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.subtleForeground,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              _Figure(
                label: l.reportsPtSessions,
                value: '${report.sessionsDone}/${report.sessionsBooked}',
                unit: l.unitTimes,
              ),
              _Figure(
                label: l.reportsCompletionAvg,
                value: report.completionAvg == null
                    ? '-'
                    : '${report.completionAvg}',
                unit: '%',
                tone: _verdictTone(
                  report.completionAvg,
                  (v) => v >= 70 ? AppColors.success : AppColors.warning,
                ),
              ),
              _Figure(
                label: l.reportsSodiumOver,
                // "-" for a past week: the roster only aggregates the
                // current one, so anything else would be this week's
                // number under last week's dates.
                value: report.sodiumOverDays?.toString() ?? '-',
                unit: l.unitDays,
                tone: _verdictTone(
                  report.sodiumOverDays,
                  (v) => v > 2 ? AppColors.overTarget : AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _WeekComparison(report: report),
          const SizedBox(height: AppSpacing.lg),
          _FeedbackEditor(
            key: ValueKey<String>(
              'feedback-${report.client.id}-${report.weekStart.toIso8601String()}',
            ),
            initialText: reportMessage(l, report),
            sent: sent,
            sending: sending,
            onSend: (message) => onSend(report, message),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l.reportsCompletionByDay,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.subtleForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!report.isCurrentWeek)
            // 요일별 시리즈는 이번 주 것뿐이다. 지난 주 제목 아래 이번 주
            // 막대를 그리면 트레이너가 그대로 고객에게 보낸다.
            EmptyHint(message: l.reportsNoLastWeekDaily)
          else if (client.weekCompletion.length == weekdayCount)
            BarSeriesChart(
              values: client.weekCompletion,
              labels: weekdayLabels(AppLocalizations.of(context)),
              maxValue: 100,
              height: 80,
              showValues: true,
              valueSuffix: '%',
              pendingFromIndex: elapsedWeekdays(DateTime.now()),
            )
          else
            EmptyHint(message: l.reportsNoWorkoutsThisWeek),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l.reportsSodiumTrend,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.subtleForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (report.isCurrentWeek)
            Sparkline(
              values: client.sodiumWeek,
              threshold: sodiumTargetMg,
              height: 56,
            )
          else
            // `sodiumWeek` is this week's series, same as the weekday
            // chart above — drawing it under a past week's dates would
            // put today's numbers in a report the trainer can send.
            EmptyHint(message: l.reportsNoLastWeekSodium),
          const SizedBox(height: AppSpacing.md),
          _FourWeekTrend(report: report),
          const SizedBox(height: AppSpacing.md),
          const _ReportAiCard(),
          const SizedBox(height: AppSpacing.md),
          const _UnsupportedExportActions(),
        ],
      ),
    );
  }
}

class _WeekComparison extends ConsumerWidget {
  const _WeekComparison({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previousStart = report.weekStart.subtract(const Duration(days: 7));
    final previous = ref.watch(
      weeklyReportProvider((client: report.client, weekStart: previousStart)),
    );
    final before = previous.valueOrNull;
    final completionDelta = _delta(report.completionAvg, before?.completionAvg);
    final sodiumDelta = _delta(report.sodiumAvg, before?.sodiumAvg);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.all(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            '이번 주 vs 지난 주',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (previous.isLoading)
            const LinearProgressIndicator(minHeight: 2)
          else if (previous.hasError)
            const Text(
              '지난주 데이터를 불러오지 못했어요.',
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: _ComparisonMetric(
                    label: '운동 이행률',
                    current: _percent(report.completionAvg),
                    previous: _percent(before?.completionAvg),
                    delta: completionDelta == null
                        ? null
                        : '${completionDelta >= 0 ? '+' : ''}$completionDelta%p',
                    positive: completionDelta == null || completionDelta >= 0,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _ComparisonMetric(
                    label: '평균 나트륨',
                    current: report.sodiumAvg == null
                        ? '-'
                        : '${report.sodiumAvg}mg',
                    previous: before?.sodiumAvg == null
                        ? '-'
                        : '${before!.sodiumAvg}mg',
                    delta: sodiumDelta == null
                        ? null
                        : '${sodiumDelta >= 0 ? '+' : ''}${sodiumDelta}mg',
                    positive: sodiumDelta == null || sodiumDelta <= 0,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static int? _delta(int? current, int? previous) =>
      current == null || previous == null ? null : current - previous;

  static String _percent(int? value) => value == null ? '-' : '$value%';
}

class _ComparisonMetric extends StatelessWidget {
  const _ComparisonMetric({
    required this.label,
    required this.current,
    required this.previous,
    required this.delta,
    required this.positive,
  });

  final String label;
  final String current;
  final String previous;
  final String? delta;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.all(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: AppColors.subtleForeground,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: <Widget>[
              Text(
                current,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (delta != null) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  delta!,
                  style: TextStyle(
                    color: positive ? AppColors.success : AppColors.overTarget,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
          Text(
            '지난주 $previous',
            style: const TextStyle(
              color: AppColors.subtleForeground,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackEditor extends StatefulWidget {
  const _FeedbackEditor({
    super.key,
    required this.initialText,
    required this.sent,
    required this.sending,
    required this.onSend,
  });

  final String initialText;
  final bool sent;
  final bool sending;
  final ValueChanged<String> onSend;

  @override
  State<_FeedbackEditor> createState() => _FeedbackEditorState();
}

class _FeedbackEditorState extends State<_FeedbackEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                '트레이너 피드백',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            ),
            Tooltip(
              message: '피드백 초안 저장 API가 아직 없어요.',
              child: const ActionButton(label: '피드백 저장', onPressed: null),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _controller,
          minLines: 4,
          maxLines: 7,
          decoration: const InputDecoration(
            hintText: '회원에게 전달할 코칭 피드백을 작성하세요.',
            helperText: '초안은 서버에 저장되지 않으며, 전송 시 기존 채팅으로 전달됩니다.',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: ActionButton(
            label: widget.sent ? '전송됨' : (widget.sending ? '전송 중' : '고객에게 전송'),
            icon: widget.sent ? Icons.check : Icons.send_outlined,
            primary: true,
            onPressed: widget.sent || widget.sending
                ? null
                : () {
                    final text = _controller.text.trim();
                    if (text.isEmpty) return;
                    widget.onSend(text);
                  },
          ),
        ),
      ],
    );
  }
}

class _FourWeekTrend extends ConsumerWidget {
  const _FourWeekTrend({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = <AsyncValue<WeeklyReport>>[
      for (var offset = 3; offset >= 0; offset--)
        ref.watch(
          weeklyReportProvider((
            client: report.client,
            weekStart: report.weekStart.subtract(Duration(days: 7 * offset)),
          )),
        ),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            '운동 이행률 추세 · 최근 4주',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (var index = 0; index < reports.length; index++)
                Expanded(
                  child: _TrendBar(
                    label: '${index + 1}주',
                    value: reports[index].valueOrNull?.completionAvg,
                    loading: reports[index].isLoading,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.label,
    required this.value,
    required this.loading,
  });

  final String label;
  final int? value;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Text(
          loading ? '…' : (value == null ? '-' : '$value%'),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Container(
          width: 36,
          height: value == null ? 12 : 18 + value!.clamp(0, 100) * 0.55,
          decoration: BoxDecoration(
            color: value == null
                ? AppColors.inputBackground
                : AppColors.primary.withValues(alpha: 0.25 + 0.007 * value!),
            borderRadius: const BorderRadius.vertical(top: AppRadius.sm),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.subtleForeground,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _ReportAiCard extends StatelessWidget {
  const _ReportAiCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.aiCardGradientStart,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.aiCardGradientEnd),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.auto_awesome, color: AppColors.primary, size: 19),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'AI 코칭 보조 · 리포트 요약',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '실제 리포트 요약 API 연결 후 사용할 수 있어요. 현재 문구는 자동 생성하지 않습니다.',
                  style: TextStyle(
                    color: AppColors.mutedForeground,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnsupportedExportActions extends StatelessWidget {
  const _UnsupportedExportActions();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Tooltip(
          message: 'PDF 생성 API가 아직 없어요.',
          child: ActionButton(
            label: '회원 공유용 PDF',
            icon: Icons.picture_as_pdf_outlined,
            onPressed: null,
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Tooltip(
          message: 'PDF/인쇄용 report snapshot 지원 후 사용할 수 있어요.',
          child: ActionButton(
            label: '인쇄',
            icon: Icons.print_outlined,
            onPressed: null,
          ),
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.unit,
    this.tone,
  });

  final String label;
  final String value;
  final String unit;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.subtleForeground,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: tone ?? AppColors.foreground,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.subtleForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
