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
import 'package:oncare_trainer/features/search/presentation/widgets/client_search_bar.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';
import 'package:oncare_trainer/shared/widgets/metric_trend_chart.dart';
import 'package:oncare_trainer/shared/widgets/mini_charts.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';
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

  /// 피드백 입력창의 현재 내용. 전송 버튼이 헤더의 공유 메뉴로 올라가면서
  /// 입력창과 전송이 서로 다른 위젯에 있게 되어, 그 사이를 잇는 값이다.
  ///
  /// `setState` 를 부르지 않는다 — 메뉴는 열릴 때 `itemBuilder` 가 이 값을 다시
  /// 읽으므로, 글자 하나마다 리포트 화면 전체를 다시 그릴 이유가 없다.
  String? _feedbackDraft;

  /// [_feedbackDraft] 가 어느 리포트의 것인가(`고객|주`). 고객이나 주가 바뀌면
  /// 남의 리포트에 쓰던 문구가 따라가지 않게 버린다.
  String? _feedbackFor;

  /// 입력창이 비었는가. 메뉴의 전송 항목을 잠그는 유일한 이유라, 이 값이
  /// 바뀔 때만 다시 그린다 — 글자마다 화면 전체를 다시 그리지 않는다.
  bool _feedbackBlank = false;

  /// 이 리포트에 대해 실제로 보낼 문구 — 트레이너가 고친 게 있으면 그것,
  /// 없으면 화면에 채워져 있는 기본 문구다.
  String _messageFor(AppLocalizations l, WeeklyReport report) =>
      _feedbackFor == _feedbackKey(report)
      ? (_feedbackDraft ?? reportMessage(l, report))
      : reportMessage(l, report);

  static String _feedbackKey(WeeklyReport report) =>
      '${report.client.id}|${report.weekStart.toIso8601String()}';

  @override
  void didUpdateWidget(ReportsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clientId != oldWidget.clientId) {
      _clientId = widget.clientId;
    }
  }

  void _selectClient(String id) {
    if (_clientId == id) return;
    context.go(AppRoutes.reportFor(id));
  }

  void _shiftWeek(int direction) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * direction));
      // A different week is a different report — allow sending again.
      _sent.clear();
      _feedbackDraft = null;
      _feedbackFor = null;
      _feedbackBlank = false;
    });
  }

  void _goToCurrentWeek() {
    final currentWeek = weekStartOf(DateTime.now());
    if (_weekStart == currentWeek) return;
    setState(() {
      _weekStart = currentWeek;
      _sent.clear();
      _feedbackDraft = null;
      _feedbackFor = null;
      _feedbackBlank = false;
    });
  }

  /// 헤더 공유 메뉴의 전송. 화면에 떠 있는 리포트와 입력창의 현재 문구를 함께
  /// 보낸다 — 입력창과 전송 버튼이 서로 다른 위젯이 되면서 필요해진 연결이다.
  Future<void> _sendSelected(WeeklyReport report) {
    return _send(report, _messageFor(AppLocalizations.of(context), report));
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
    // 헤더는 본문(LayoutBuilder)보다 위에 있어 본문이 고른 고객을 볼 수 없다.
    // 본문과 **같은 규칙**으로 여기서 한 번 더 고른다 — 메뉴 항목에 이름을
    // 함께 보여 주므로 누구에게 가는 리포트인지 화면에서 드러난다.
    final roster = clientsAsync.valueOrNull ?? const <TrainerClient>[];
    final TrainerClient? shareTarget = roster.isEmpty
        ? null
        : roster.firstWhere(
            (c) => c.id == _clientId,
            orElse: () => roster.first,
          );

    return PageScaffold(
      key: ValueKey<String>('reports-${_clientId ?? 'list'}'),
      title: l.reportsTitle,
      subtitle: l.reportsSubtitle,
      // 페이지 전체 스크롤을 끈다 — 넓은 화면에서 왼쪽 고객 열을 고정하고
      // 오른쪽 리포트만 스크롤하기 위해서다. 좁은 화면은 아래 분기에서
      // 스스로 스크롤을 갖는다.
      scrollable: false,
      headerCenter: const ClientSearchBar(),
      actions: <Widget>[
        ActionButton(
          label: l.reportsPrevWeek,
          icon: Icons.chevron_left,
          onPressed: () => _shiftWeek(-1),
        ),
        if (_weekStart != weekStartOf(DateTime.now()))
          ActionButton(
            label: l.reportsGoThisWeek,
            icon: Icons.today_outlined,
            onPressed: _goToCurrentWeek,
          ),
        _ShareMenu(
          client: shareTarget,
          weekStart: _weekStart,
          sent: shareTarget != null && _sent.contains(shareTarget.id),
          sending: shareTarget != null && _sending == shareTarget.id,
          feedbackBlank: _feedbackBlank,
          onSend: _sendSelected,
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide =
                        constraints.maxWidth >= AppLayout.splitBreakpoint;
                    // 좌측 열: 고객 목록 + 이번 주 먼저 볼 고객. 넓은 화면에서는
                    // 이 열이 고정이고 오른쪽 리포트만 스크롤한다 — 리포트를 아래로
                    // 읽는 동안 다른 고객으로 넘어가려면 목록이 늘 보여야 한다.
                    final leftColumn = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _ClientPicker(
                          clients: clients,
                          selectedId: selected.id,
                          onSelect: _selectClient,
                        ),
                      ],
                    );
                    if (!wide && _clientId == null) {
                      return SingleChildScrollView(child: leftColumn);
                    }
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
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.xl,
                          ),
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
                        initialFeedback: _messageFor(l, data),
                        onFeedbackChanged: (text) {
                          _feedbackDraft = text;
                          _feedbackFor = _feedbackKey(data);
                          // 비었는지 여부가 바뀔 때만 다시 그린다 — 그 외에는
                          // 화면이 달라질 것이 없다.
                          final blank = text.trim().isEmpty;
                          if (blank != _feedbackBlank) {
                            setState(() => _feedbackBlank = blank);
                          }
                        },
                      ),
                    );

                    if (!wide) {
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                key: const ValueKey<String>(
                                  'reports-back-to-list',
                                ),
                                onPressed: () => context.go(AppRoutes.reports),
                                icon: const Icon(Icons.arrow_back),
                                label: Text(l.reportsBackToList),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            report,
                          ],
                        ),
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(width: 292, child: leftColumn),
                        const SizedBox(width: AppSpacing.lg),
                        // 스크롤은 이 열 안에서만 일어난다. 페이지 전체가 스크롤
                        // 되면 왼쪽 목록이 함께 밀려 올라가 버린다.
                        Expanded(
                          child: SingleChildScrollView(
                            key: const ValueKey<String>(
                              'reports-report-scroll',
                            ),
                            child: report,
                          ),
                        ),
                      ],
                    );
                  },
                ),
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

class _ClientPicker extends StatefulWidget {
  const _ClientPicker({
    required this.clients,
    required this.selectedId,
    required this.onSelect,
  });

  final List<TrainerClient> clients;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  State<_ClientPicker> createState() => _ClientPickerState();
}

class _ClientPickerState extends State<_ClientPicker> {
  /// 한 줄 높이. 아바타(38)에 위아래 숨 쉴 자리를 더한 값이다.
  static const double _rowHeight = 56;

  /// 한 번에 보여 줄 줄 수. 나머지는 스크롤한다.
  static const int _visibleRows = 5;

  /// 목록과 스크롤바가 같은 위치를 가리키도록 컨트롤러를 공유한다.
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final clients = widget.clients;
    final selectedId = widget.selectedId;
    final onSelect = widget.onSelect;
    return SectionCard(
      title: l.navClients,
      icon: Icons.people_outline,
      dense: true,
      // 다섯 명까지만 보여 주고 나머지는 스크롤한다. 로스터가 열다섯 명이면
      // 카드가 화면 높이를 다 먹어 오른쪽 리포트와 나란히 읽기 어려웠다.
      child: SizedBox(
        height: _rowHeight * _visibleRows,
        child: Scrollbar(
          controller: _scroll,
          thumbVisibility: true,
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            itemCount: clients.length,
            itemExtent: _rowHeight,
            itemBuilder: (context, index) {
              final client = clients[index];
              final selected = client.id == selectedId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Material(
                  color: selected
                      ? AppColors.accentSurface
                      : Colors.transparent,
                  borderRadius: const BorderRadius.all(AppRadius.md),
                  child: InkWell(
                    onTap: () => onSelect(client.id),
                    borderRadius: const BorderRadius.all(AppRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Row(
                        children: <Widget>[
                          ClientAvatar(label: client.avatar, size: 38),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: ClientIdentity(
                              client: client,
                              nameStyle: TextStyle(
                                fontSize: 15,
                                fontWeight: selected
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
              );
            },
          ),
        ),
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
    required this.initialFeedback,
    required this.onFeedbackChanged,
  });

  final WeeklyReport report;

  /// 입력창에 채워 둘 문구. 트레이너가 고치던 중이면 그 내용이다.
  final String initialFeedback;

  /// 입력창이 바뀔 때마다 현재 문구를 올려 준다 — 전송은 헤더 공유 메뉴가 한다.
  final ValueChanged<String> onFeedbackChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final client = report.client;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionCard(
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
              ClientIdentity(
                client: client,
                nameStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _WeekComparison(report: report),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: l.reportsFeedbackTitle,
          // 저장 버튼을 제목 행에 둔다 — 입력창 위에 버튼만 있는 줄이 따로
          // 있으면 카드가 그만큼 세로로 늘어난다.
          trailing: Tooltip(
            message: l.reportsFeedbackSaveUnsupported,
            child: ActionButton(label: l.reportsFeedbackSave, onPressed: null),
          ),
          child: _FeedbackEditor(
            key: ValueKey<String>(
              'feedback-${report.client.id}-${report.weekStart.toIso8601String()}',
            ),
            initialText: initialFeedback,
            onChanged: onFeedbackChanged,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: l.reportsWeekly,
          child: Row(
            children: <Widget>[
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
                label: l.reportsPtSessions,
                value: '${report.sessionsDone}/${report.sessionsBooked}',
                unit: l.unitTimes,
              ),
              _Figure(
                label: l.reportsSodiumOver,
                value: report.sodiumOverDays?.toString() ?? '-',
                unit: l.unitDays,
                tone: _verdictTone(
                  report.sodiumOverDays,
                  (v) => v > 2 ? AppColors.overTarget : AppColors.success,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: l.reportsCompletionByDay,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (!report.isCurrentWeek)
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
              _MetricTrendSection(client: client, report: report),
              const SizedBox(height: AppSpacing.md),
              _FourWeekTrend(report: report),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _ReportAiCard(),
      ],
    );
  }
}

/// 어떤 영양 지표의 주간 추이를 볼지 고르는 식별자.
///
/// 화면에 보이는 라벨과 분리해 둔다 — 로케일이 내부 키가 되면 영어에서
/// 선택이 깨진다.
enum _TrendMetric { calories, sodium, sugar }

/// 칼로리·나트륨·당류 주간 추이 — 선택한 지표 하나를 사용자 앱 홈 탭과 **같은
/// 그림**으로 그린다(#746).
///
/// 눈금은 사용자 앱 `dashboard_content.dart` 의 값을 그대로 쓴다. 지표를 바꿔도
/// 축 바닥이 항상 0 이라 세 그래프를 번갈아 봐도 기준선이 흔들리지 않는다.
class _MetricTrendSection extends StatefulWidget {
  const _MetricTrendSection({required this.client, required this.report});

  final TrainerClient client;
  final WeeklyReport report;

  @override
  State<_MetricTrendSection> createState() => _MetricTrendSectionState();
}

class _MetricTrendSectionState extends State<_MetricTrendSection> {
  _TrendMetric _metric = _TrendMetric.calories;

  String _label(AppLocalizations l, _TrendMetric metric) => switch (metric) {
    _TrendMetric.calories => l.metricCalories,
    _TrendMetric.sodium => l.metricSodium,
    _TrendMetric.sugar => l.metricSugar,
  };

  /// 선택한 지표의 요일별 값. 계열이 7일이 아니면(구버전 응답) 비워 둔다.
  List<double> get _values {
    final client = widget.client;
    final series = switch (_metric) {
      _TrendMetric.calories => client.caloriesWeek.map((v) => v.toDouble()),
      _TrendMetric.sodium => client.sodiumWeek.map((v) => v.toDouble()),
      _TrendMetric.sugar => client.sugarWeek,
    }.toList(growable: false);
    return series.length == weekdayCount ? series : const <double>[];
  }

  double get _goal => switch (_metric) {
    _TrendMetric.calories => calorieTargetKcal.toDouble(),
    _TrendMetric.sodium => sodiumTargetMg.toDouble(),
    _TrendMetric.sugar => sugarTargetG.toDouble(),
  };

  List<double> get _ticks => switch (_metric) {
    _TrendMetric.calories => const <double>[0, 1500, 2500],
    _TrendMetric.sodium => const <double>[0, 1750, 3500],
    _TrendMetric.sugar => const <double>[0, 25, 50],
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final values = _values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l.reportsMetricTrend(_label(l, _metric)),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.subtleForeground,
                ),
              ),
            ),
            for (final metric in _TrendMetric.values) ...<Widget>[
              const SizedBox(width: AppSpacing.xs),
              _MetricChip(
                key: ValueKey<String>('trend-metric-${metric.name}'),
                label: _label(l, metric),
                selected: metric == _metric,
                onTap: () => setState(() => _metric = metric),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // 주간 계열은 이번 주치만 들고 있다. 지난 주를 열면 나트륨 때와 같이
        // 없다고 말한다 — 이번 주 선을 지난 주 자리에 그리지 않는다.
        if (!widget.report.isCurrentWeek)
          EmptyHint(message: l.reportsNoLastWeekMetricTrend(_label(l, _metric)))
        // 기록이 하나도 없는 고객까지 바닥에 붙은 0 선을 그리면 "기록 없음"이
        // "하루 0kcal" 처럼 읽힌다.
        else if (values.isEmpty || values.every((v) => v == 0))
          EmptyHint(message: l.reportsNoMetricRecords(_label(l, _metric)))
        else
          MetricTrendChart(
            values: values,
            dayLabels: weekdayLabels(l),
            goal: _goal,
            ticks: _ticks,
            todayIndex: elapsedWeekdays(DateTime.now()) - 1,
            // 지표를 바꾸면 선을 처음부터 다시 그려 값이 바뀐 것을 눈으로
            // 따라가게 한다.
            replayKey: _metric,
            formatTick: metricTrendNumber,
          ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.accentSurface : AppColors.inputBackground,
    borderRadius: const BorderRadius.all(AppRadius.pill),
    child: InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(AppRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.mutedForeground,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

class _WeekComparison extends ConsumerWidget {
  const _WeekComparison({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
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
          Text(
            l.reportsComparisonTitle(
              report.isCurrentWeek ? l.reportsThisWeek : l.reportsSelectedWeek,
            ),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (previous.isLoading)
            const LinearProgressIndicator(minHeight: 2)
          else if (previous.hasError)
            Text(
              l.reportsPreviousLoadFailed,
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final charts = <Widget>[
                  _ComparisonMetric(
                    key: const ValueKey<String>('completion-comparison-chart'),
                    label: l.reportsCompletionAvg,
                    current: report.completionAvg,
                    previous: before?.completionAvg,
                    previousLabel: l.reportsLastWeek,
                    currentLabel: report.isCurrentWeek
                        ? l.reportsThisWeek
                        : l.reportsSelectedWeek,
                    maxValue: 100,
                    valueSuffix: '%',
                    delta: completionDelta == null
                        ? null
                        : '${completionDelta >= 0 ? '+' : ''}$completionDelta%p',
                    positive: completionDelta == null || completionDelta >= 0,
                  ),
                  _ComparisonMetric(
                    key: const ValueKey<String>('sodium-comparison-chart'),
                    label: l.reportsAverageSodium,
                    current: report.sodiumAvg,
                    previous: before?.sodiumAvg,
                    previousLabel: l.reportsLastWeek,
                    currentLabel: report.isCurrentWeek
                        ? l.reportsThisWeek
                        : l.reportsSelectedWeek,
                    valueSuffix: 'mg',
                    delta: sodiumDelta == null
                        ? null
                        : '${sodiumDelta >= 0 ? '+' : ''}${sodiumDelta}mg',
                    positive: sodiumDelta == null || sodiumDelta <= 0,
                  ),
                ];
                if (constraints.maxWidth < 520) {
                  return Column(
                    children: <Widget>[
                      charts.first,
                      const SizedBox(height: AppSpacing.sm),
                      charts.last,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: charts.first),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: charts.last),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  static int? _delta(int? current, int? previous) =>
      current == null || previous == null ? null : current - previous;
}

class _ComparisonMetric extends StatelessWidget {
  const _ComparisonMetric({
    super.key,
    required this.label,
    required this.current,
    required this.previous,
    required this.previousLabel,
    required this.currentLabel,
    required this.valueSuffix,
    required this.delta,
    required this.positive,
    this.maxValue,
  });

  final String label;
  final int? current;
  final int? previous;
  final String previousLabel;
  final String currentLabel;
  final String valueSuffix;
  final String? delta;
  final bool positive;
  final int? maxValue;

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
          BarSeriesChart(
            values: <int>[previous ?? 0, current ?? 0],
            labels: <String>[previousLabel, currentLabel],
            maxValue: maxValue,
            height: 96,
            showValues: true,
            valueSuffix: valueSuffix,
            highlightIndex: 1,
            missingIndices: <int>{
              if (previous == null) 0,
              if (current == null) 1,
            },
          ),
          if (delta != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                delta!,
                style: TextStyle(
                  color: positive ? AppColors.success : AppColors.overTarget,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackEditor extends StatefulWidget {
  const _FeedbackEditor({
    super.key,
    required this.initialText,
    required this.onChanged,
  });

  final String initialText;

  /// 전송은 헤더의 공유 메뉴가 한다 — 이 위젯은 문구만 들고 올려 준다.
  final ValueChanged<String> onChanged;

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
    final l = AppLocalizations.of(context);
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      minLines: 4,
      maxLines: 7,
      // 입력 글씨의 기본은 bodyLarge(17)라 카드의 다른 글씨보다 유독 컸다.
      // 임의의 숫자 대신 타이포 스케일의 한 단계 아래를 쓴다.
      style: Theme.of(context).textTheme.bodySmall,
      decoration: InputDecoration(hintText: l.reportsFeedbackHint),
    );
  }
}

class _FourWeekTrend extends ConsumerWidget {
  const _FourWeekTrend({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
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
          Text(
            l.reportsTrendTitle,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (var index = 0; index < reports.length; index++)
                Expanded(
                  child: _TrendBar(
                    label: l.reportsTrendWeek(index + 1),
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
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.aiCardGradientStart,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.aiCardGradientEnd),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.auto_awesome, color: AppColors.primary, size: 19),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l.reportsAiTitle,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l.reportsAiUnavailable,
                  style: const TextStyle(
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

/// 리포트를 내보내는 두 경로를 한 메뉴로 모은 헤더 액션. (#735)
///
/// 전에는 동작하는 `고객에게 전송` 이 피드백 입력창 아래에, 눌리지 않는
/// `PDF 내보내기` 가 헤더에 따로 있어서 "이 리포트를 어떻게 내보내지"의 답이
/// 화면 두 곳에 나뉘어 있었다.
///
/// 항목에 고객 이름을 함께 적는다 — 헤더는 본문보다 위에 있어 어느 리포트가
/// 열려 있는지 눈으로 잇기 어렵고, 잘못된 고객에게 보내는 실수가 되돌릴 수
/// 없는 종류이기 때문이다.
class _ShareMenu extends ConsumerWidget {
  /// 메뉴 최소 너비. 두 항목 중 긴 쪽이 한 줄에 들어가는 폭이다.
  static const double _menuMinWidth = 200;

  /// 메뉴 한 줄. Material 기본은 글씨 16 · 높이 48 이라 12~13 으로 짜인 이
  /// 콘솔에서 혼자 커 보였다. 글씨는 여는 버튼(`ActionButton` 라벨)과 같은
  /// 크기·굵기로 맞춘다 — 버튼과 그 메뉴가 다른 크기로 보일 이유가 없다.
  static const ButtonStyle _itemStyle = ButtonStyle(
    textStyle: WidgetStatePropertyAll(
      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
    ),
    minimumSize: WidgetStatePropertyAll(Size(0, 36)),
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: AppSpacing.md),
    ),
  );

  const _ShareMenu({
    required this.client,
    required this.weekStart,
    required this.sent,
    required this.sending,
    required this.feedbackBlank,
    required this.onSend,
  });

  /// 리포트를 보고 있는 고객. 로스터가 비어 있으면 null.
  final TrainerClient? client;

  /// 화면이 보고 있는 주. 헤더의 주 이동과 같은 값을 써야 다른 주의 리포트를
  /// 보내는 일이 없다.
  final DateTime weekStart;
  final bool sent;
  final bool sending;

  /// 피드백 입력창이 비었는가. 리포트 수치만 덩그러니 보내면 회원은 무슨 뜻인지
  /// 알 수 없어, 전에도 빈 피드백은 보낼 수 없었다.
  final bool feedbackBlank;

  final Future<void> Function(WeeklyReport report) onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final target = client;
    // 메뉴의 **오른쪽 변**을 버튼 오른쪽 변에 맞춘다.
    //
    // 기본(LTR)은 버튼 왼쪽에 붙어 오른쪽으로 자라, 헤더 끝에 있는 이 버튼에서는
    // 창 가장자리에 닿는다. 버튼 너비를 숫자로 추정해 offset 으로 당기는 방법은
    // 라벨·글꼴이 바뀌면 곧바로 어긋나므로, 펼침 방향 자체를 뒤집는다. 안쪽
    // 내용은 다시 LTR 로 돌려 아이콘·글자 순서는 그대로 둔다.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: MenuAnchor(
        // 메뉴는 앱의 다른 메뉴와 같은 면으로 그린다 — Material 기본 표면은 이
        // 콘솔의 카드보다 밝고 모서리도 달라 혼자 떠 보였다.
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(AppColors.card),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(AppRadius.md),
              side: BorderSide(color: AppColors.borderStrong),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: AppSpacing.xs),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(_menuMinWidth, 0)),
        ),
        // 헤더와 한 칸 띄운다. 가로 위치는 아래 Directionality 가 맞춘다.
        alignmentOffset: const Offset(0, AppSpacing.xs),
        menuChildren: <Widget>[
          Directionality(
            textDirection: TextDirection.ltr,
            child: MenuItemButton(
              key: const ValueKey<String>('reports-share-send'),
              style: _itemStyle,
              leadingIcon: Icon(
                sent ? Icons.check : Icons.send_outlined,
                size: 16,
              ),
              onPressed: target == null || sent || sending || feedbackBlank
                  ? null
                  : () => _send(context, ref, target),
              child: Tooltip(
                message: feedbackBlank && target != null && !sent && !sending
                    ? l.reportsShareNeedsFeedback
                    : '',
                child: Text(
                  target == null
                      ? l.reportsShareNoClient
                      : (sent
                            ? l.reportsSendStateSent
                            : (sending
                                  ? l.reportsSendStateSending
                                  : l.reportsShareSendTo(target.name))),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          // PDF 생성 경로가 아직 없다. 항목을 숨기지 않는 이유는, 없는 기능이
          // 아니라 아직 준비되지 않은 기능임을 화면에서 알 수 있어야 해서다.
          Directionality(
            textDirection: TextDirection.ltr,
            child: MenuItemButton(
              key: const ValueKey<String>('reports-share-pdf'),
              style: _itemStyle,
              leadingIcon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
              onPressed: null,
              child: Tooltip(
                message: l.reportsPdfUnsupported,
                child: Text(l.reportsPdfLabel),
              ),
            ),
          ),
        ],
        builder: (context, controller, _) => Directionality(
          textDirection: TextDirection.ltr,
          child: ActionButton(
            key: const ValueKey<String>('reports-share-action'),
            label: l.reportsShare,
            icon: Icons.ios_share,
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
          ),
        ),
      ),
    );
  }

  /// 화면에 떠 있는 그 주의 리포트를 읽어 전송한다.
  ///
  /// 아직 로딩 중이면 보낼 내용이 없으므로 아무 일도 하지 않는다 — 빈 리포트를
  /// 보내는 것보다 낫다.
  void _send(BuildContext context, WidgetRef ref, TrainerClient target) {
    final report = ref
        .read(weeklyReportProvider((client: target, weekStart: weekStart)))
        .valueOrNull;
    if (report == null) return;
    onSend(report);
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
