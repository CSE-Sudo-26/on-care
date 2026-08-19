import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart'
    show elapsedWeekdays, weekdayCount, weekdayLabels;
import 'package:oncare_trainer/features/reports/data/repositories/report_repository.dart';
import 'package:oncare_trainer/features/reports/domain/report_summary.dart';
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/features/reports/services/report_pdf_actions.dart';
import 'package:oncare_trainer/features/reports/services/report_pdf_generator.dart';
import 'package:oncare_trainer/features/reports/services/report_pdf_sender.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/search/presentation/widgets/client_search_bar.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';
import 'package:oncare_trainer/shared/widgets/exercise_line.dart';
import 'package:oncare_trainer/shared/widgets/metric_trend_chart.dart';
import 'package:oncare_trainer/shared/widgets/mini_charts.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

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
  DateTime _weekStart = weekStartOf(nowKst());

  /// Clients whose report was sent this session — keeps the button from
  /// being pressed twice in a row by accident.
  final Set<String> _sent = <String>{};

  /// A send is in flight for this client.
  String? _sending;

  /// PDF binary를 만드는 동안 내보내기 중복 요청을 막는다.
  bool _generatingPdf = false;

  /// 피드백 입력창의 현재 내용. 전송 버튼이 헤더의 공유 메뉴로 올라가면서
  /// 입력창과 전송이 서로 다른 위젯에 있게 되어, 그 사이를 잇는 값이다.
  ///
  /// `setState` 를 부르지 않는다 — 메뉴는 열릴 때 `itemBuilder` 가 이 값을 다시
  /// 읽으므로, 글자 하나마다 리포트 화면 전체를 다시 그릴 이유가 없다.
  String? _feedbackDraft;

  /// [_feedbackDraft] 가 어느 리포트의 것인가(`고객|주`). 고객이나 주가 바뀌면
  /// 남의 리포트에 쓰던 문구가 따라가지 않게 버린다.
  String? _feedbackFor;

  /// 입력창을 새 문구로 다시 만들 때 올린다.
  ///
  /// `TextEditingController` 는 한 번 만들어지면 initialText 를 다시 읽지
  /// 않는다. 요약을 초안으로 가져오는 건 드문 동작이라, 컨트롤러를 밖으로
  /// 끌어내는 대신 위젯 키를 바꿔 다시 만든다.
  int _draftEpoch = 0;

  /// 입력창이 비었는가. 메뉴의 전송 항목을 잠그는 유일한 이유라, 이 값이
  /// 바뀔 때만 다시 그린다 — 글자마다 화면 전체를 다시 그리지 않는다.
  bool _feedbackBlank = false;

  /// 피드백 초안을 서버에 저장하는 중이다. (#821)
  bool _savingFeedback = false;

  /// 입력창이 출발점([_baseFor])과 달라졌는가. 되돌리기 버튼을 켜는 유일한
  /// 이유라, [_feedbackBlank] 와 같은 방식으로 이 값이 **바뀔 때만** 다시
  /// 그린다 — 글자마다 리포트 화면 전체를 다시 그리지 않는다. (#821)
  bool _feedbackDiffers = false;

  /// 입력창의 출발점 — 저장해 둔 초안이 있으면 그것, 없으면 수치에서 만든
  /// 자동 문구다. (#821)
  ///
  /// 빈 본문을 저장한 주는 빈 문자열이 출발점이다. 트레이너가 일부러 지운
  /// 것이라, "저장한 적 없음" 으로 보고 자동 문구를 되살리면 지운 일이
  /// 무의미해진다.
  String _baseFor(
    AppLocalizations l,
    WeeklyReport report,
    ReportFeedbackDraft? saved,
  ) => saved != null && saved.saved ? saved.body : reportMessage(l, report);

  /// 이 리포트에 대해 실제로 보낼 문구 — 트레이너가 고친 게 있으면 그것,
  /// 없으면 화면에 채워져 있는 기본 문구다.
  String _messageFor(
    AppLocalizations l,
    WeeklyReport report,
    ReportFeedbackDraft? saved,
  ) => _feedbackFor == _feedbackKey(report)
      ? (_feedbackDraft ?? _baseFor(l, report, saved))
      : _baseFor(l, report, saved);

  static String _feedbackKey(WeeklyReport report) =>
      '${report.client.id}|${report.weekStart.toIso8601String()}';

  static String _feedbackKeyOf(String clientId, DateTime weekStart) =>
      '$clientId|${weekStart.toIso8601String()}';

  /// 입력창의 현재 문구를 그 주의 초안으로 저장한다. (#821)
  ///
  /// 실패해도 입력 내용을 건드리지 않는다 — 저장하려다 잃는 것이 이 기능이
  /// 없애려던 바로 그 문제다.
  Future<void> _saveFeedback(WeeklyReport report, String body) async {
    if (_savingFeedback) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingFeedback = true);
    try {
      await ref
          .read(reportRepositoryProvider)
          .saveFeedbackDraft(
            clientId: report.client.id,
            weekStart: report.weekStart,
            body: body,
          );
      ref.invalidate(
        reportFeedbackDraftProvider((
          client: report.client,
          weekStart: report.weekStart,
        )),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l.reportsFeedbackSaved)),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l.reportsFeedbackSaveFailed)),
      );
    } finally {
      if (mounted) setState(() => _savingFeedback = false);
    }
  }

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
      _feedbackDiffers = false;
    });
  }

  /// `8월 3일 – 8월 9일`.
  ///
  /// 헤더의 주 이동 버튼은 **그 버튼이 데려갈 주**를 적는다. `이전` 만으로는
  /// 어디로 가는지 알 수 없고, 여러 번 눌러 과거로 가면 지금 보고 있는 주가
  /// 무엇인지도 헤더에서 사라졌다.
  ///
  /// `이전 주` 라고 쓰지 않는 이유는 그대로다 — 비교 카드의 `지난 주` 열과
  /// 같은 말이 되어 어느 주를 보고 있는지 오히려 헷갈린다. 날짜 범위는 그
  /// 셋(이번 주·지난 주·선택 주) 중 어느 것과도 겹치지 않는다.
  static String _weekRangeLabel(AppLocalizations l, DateTime weekStart) {
    final DateTime weekEnd = weekStart.add(const Duration(days: 6));
    return l.dateRange(
      l.dateMonthDay(weekStart.month, weekStart.day),
      l.dateMonthDay(weekEnd.month, weekEnd.day),
    );
  }

  /// 요약을 피드백 입력창으로 옮긴다.
  ///
  /// 요약 카드는 넓은 화면에서 왼쪽 열로, 좁은 화면에서는 리포트 흐름 안으로
  /// 자리를 옮겨 다녀 부르는 곳이 둘이다 — 옮기는 규칙은 한 곳에 둔다.
  void _useSummaryAsDraft(
    AppLocalizations l,
    WeeklyReport report,
    ReportFeedbackDraft? savedDraft,
    String draft,
  ) {
    setState(() {
      _feedbackDraft = draft;
      _feedbackFor = _feedbackKey(report);
      _feedbackBlank = draft.trim().isEmpty;
      _feedbackDiffers = draft != _baseFor(l, report, savedDraft);
      _draftEpoch++;
    });
  }

  void _goToCurrentWeek() {
    final currentWeek = weekStartOf(nowKst());
    if (_weekStart == currentWeek) return;
    setState(() {
      _weekStart = currentWeek;
      _sent.clear();
      _feedbackDraft = null;
      _feedbackFor = null;
      _feedbackBlank = false;
      _feedbackDiffers = false;
    });
  }

  /// 그 주에 저장된 초안. 아직 안 읽혔으면 null 이다 — 전송·PDF 처럼 지금
  /// 당장 값이 필요한 자리에서 쓴다. (#821)
  ReportFeedbackDraft? _savedDraftOf(WeeklyReport report) => ref
      .read(
        reportFeedbackDraftProvider((
          client: report.client,
          weekStart: report.weekStart,
        )),
      )
      .valueOrNull;

  /// 헤더 공유 메뉴의 전송. 화면에 떠 있는 리포트와 입력창의 현재 문구를 함께
  /// 보낸다 — 입력창과 전송 버튼이 서로 다른 위젯이 되면서 필요해진 연결이다.
  Future<void> _sendSelected(WeeklyReport report) {
    return _send(
      report,
      _messageFor(
        AppLocalizations.of(context),
        report,
        _savedDraftOf(report),
      ),
    );
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

  Future<void> _openPdfExport(WeeklyReport report) async {
    if (_generatingPdf) return;
    final messenger = ScaffoldMessenger.of(context);
    final feedback = _messageFor(
      AppLocalizations.of(context),
      report,
      _savedDraftOf(report),
    );
    setState(() => _generatingPdf = true);
    try {
      WeeklyReport? previous;
      try {
        previous = await ref.read(
          weeklyReportProvider((
            client: report.client,
            weekStart: report.weekStart.subtract(const Duration(days: 7)),
          )).future,
        );
      } catch (_) {
        // 전주 집계가 없어도 현재 주차 PDF는 생성할 수 있다.
      }
      final bytes = await ref
          .read(reportPdfGeneratorProvider)
          .generate(
            report: report,
            feedback: feedback,
            previousReport: previous,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => ReportPdfExportDialog(report: report, bytes: bytes),
      );
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).reportsPdfGenerationFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
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
    // 저장해 둔 초안이 도착하면 입력창을 그 문구로 다시 만든다. 이미 이 리포트를
    // 고치고 있었다면 건드리지 않는다 — 읽어 온 값이 트레이너가 방금 친 글을
    // 덮으면 안 된다. (#821)
    //
    // `ref.listen` 은 build 안에서만 부를 수 있어 본문(LayoutBuilder 콜백은
    // layout 단계에 돈다)이 아니라 여기에 둔다. 고객을 고르는 규칙은 본문과
    // 같은 [shareTarget] 이다.
    if (shareTarget != null) {
      ref.listen<AsyncValue<ReportFeedbackDraft>>(
        reportFeedbackDraftProvider((
          client: shareTarget,
          weekStart: _weekStart,
        )),
        (previous, next) {
          if (next.valueOrNull == null) return;
          if (_feedbackFor == _feedbackKeyOf(shareTarget.id, _weekStart)) {
            return;
          }
          setState(() => _draftEpoch++);
        },
      );
    }

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
          key: const ValueKey<String>('reports-prev-week'),
          label: _weekRangeLabel(
            l,
            _weekStart.subtract(const Duration(days: 7)),
          ),
          icon: Icons.chevron_left,
          onPressed: () => _shiftWeek(-1),
        ),
        if (_weekStart != weekStartOf(nowKst()))
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
          generatingPdf: _generatingPdf,
          onPdf: _openPdfExport,
        ),
      ],
      child: clientsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: AppSpacing.xxxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxxl),
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
              padding: const EdgeInsets.only(top: AppSpacing.xxxl),
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
                    // 좌측 열: 고객 목록. 넓은 화면에서는 이 열이 고정이고
                    // 오른쪽 리포트만 스크롤한다 — 리포트를 아래로 읽는 동안
                    // 다른 고객으로 넘어가려면 목록이 늘 보여야 한다.
                    final clientPicker = _ClientPicker(
                      clients: clients,
                      selectedId: selected.id,
                      onSelect: _selectClient,
                    );
                    // 좁은 화면에서 아직 아무도 고르지 않았을 때 — 여기가
                    // 유일하게 **고객이 정말 안 눌린** 상태다. 목록만 두면
                    // 고르면 무엇을 얻는지 알 수 없어, 그 자리에 무엇이 뜨는지
                    // 한 줄 적어 준다. 넓은 화면은 첫 고객이 자동으로 골라져
                    // 있어 이 상태가 없다.
                    if (!wide && _clientId == null) {
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            clientPicker,
                            const SizedBox(height: AppSpacing.lg),
                            _ReportSummaryHint(
                              message: l.reportsSummaryEmptyClient,
                            ),
                          ],
                        ),
                      );
                    }
                    // The report itself comes from the repository: local
                    // in demo, server-aggregated against the real API
                    // (only the backend has the member's full history).
                    final reportKey = (client: selected, weekStart: _weekStart);
                    final reportAsync = ref.watch(
                      weeklyReportProvider(reportKey),
                    );
                    // 저장해 둔 초안. 리포트와 따로 읽는다 — 초안은 트레이너가
                    // 쓰던 글이고, 리포트가 다시 계산돼도 사라지면 안 된다.
                    final savedDraft = ref
                        .watch(reportFeedbackDraftProvider(reportKey))
                        .valueOrNull;
                    final report = reportAsync.when(
                      loading: () => SectionCard(
                        title: l.reportsWeekly,
                        icon: Icons.description_outlined,
                        child: const Padding(
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
                        // 넓은 화면에서는 요약 카드가 왼쪽 열로 내려간다 —
                        // 고객을 고르는 자리와 그 고객의 요약이 같은 시선
                        // 안에 들어오고, 비어 있던 목록 아래를 쓴다.
                        showSummary: !wide,
                        draftEpoch: _draftEpoch,
                        initialFeedback: _messageFor(l, data, savedDraft),
                        savingFeedback: _savingFeedback,
                        onSaveFeedback: () => _saveFeedback(
                          data,
                          _messageFor(l, data, savedDraft),
                        ),
                        // 트레이너가 손댄 흔적이 있을 때만 켠다 — 누를 게
                        // 없는 버튼을 띄워 두지 않는다. 되돌릴 자리는 저장해
                        // 둔 초안이고, 저장한 적이 없으면 자동 생성 문구다.
                        canRestoreDraft:
                            _messageFor(l, data, savedDraft) !=
                            _baseFor(l, data, savedDraft),
                        onRestoreDraft: () => setState(() {
                          _feedbackDraft = null;
                          _feedbackFor = null;
                          _feedbackBlank = false;
                          _feedbackDiffers = false;
                          _draftEpoch++;
                        }),
                        onUseSummaryAsDraft: (draft) =>
                            _useSummaryAsDraft(l, data, savedDraft, draft),
                        onFeedbackChanged: (text) {
                          _feedbackDraft = text;
                          _feedbackFor = _feedbackKey(data);
                          // 비었는지, 출발점과 달라졌는지가 바뀔 때만 다시
                          // 그린다 — 앞은 전송 항목을, 뒤는 되돌리기 버튼을
                          // 가르는 값이다. 그 외에는 화면이 달라질 것이 없어
                          // 글자마다 다시 그리지 않는다.
                          final blank = text.trim().isEmpty;
                          final differs = text != _baseFor(l, data, savedDraft);
                          if (blank != _feedbackBlank ||
                              differs != _feedbackDiffers) {
                            setState(() {
                              _feedbackBlank = blank;
                              _feedbackDiffers = differs;
                            });
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
                    // 요약 카드가 놓일 자리. 리포트를 아직 못 읽었으면 그 자리에
                    // 무엇이 뜨는지만 적는다 — 빈 칸으로 두면 왼쪽 열이 목록
                    // 아래에서 그냥 잘린 것처럼 보인다.
                    final Widget summarySlot = reportAsync.when(
                      loading: () =>
                          _ReportSummaryHint(message: l.reportsAiLoading),
                      error: (_, _) =>
                          _ReportSummaryHint(message: l.reportsAiUnavailable),
                      data: (data) => _ReportAiCard(
                        report: data,
                        onUseAsDraft: (draft) =>
                            _useSummaryAsDraft(l, data, savedDraft, draft),
                      ),
                    );
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 292,
                          // 목록(5줄 고정)에 요약 카드가 더해지면 짧은 창에서는
                          // 열이 화면보다 길어진다. 이 열 안에서만 스크롤하게
                          // 두어 오른쪽 리포트와는 여전히 따로 움직인다.
                          child: SingleChildScrollView(
                            key: const ValueKey<String>('reports-left-scroll'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                clientPicker,
                                const SizedBox(height: AppSpacing.lg),
                                summarySlot,
                              ],
                            ),
                          ),
                        ),
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
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    l.reportsScheduleWarning,
                    style: const TextStyle(
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
class _ClientReport extends StatelessWidget {
  const _ClientReport({
    required this.report,
    required this.showSummary,
    required this.draftEpoch,
    required this.canRestoreDraft,
    required this.onRestoreDraft,
    required this.initialFeedback,
    required this.onUseSummaryAsDraft,
    required this.onFeedbackChanged,
    required this.savingFeedback,
    required this.onSaveFeedback,
  });

  final WeeklyReport report;

  /// 요약 카드를 이 흐름 안에 그릴 것인가. 넓은 화면에서는 왼쪽 고객 열이
  /// 가져가므로 `false` 다.
  final bool showSummary;

  /// 입력창에 채워 둘 문구. 트레이너가 고치던 중이면 그 내용이다.
  /// 바뀌면 입력창을 새 문구로 다시 만든다.
  final int draftEpoch;

  /// 입력창이 자동 생성 초안과 달라져 되돌릴 것이 있는가.
  final bool canRestoreDraft;

  /// 입력창을 자동 생성 초안으로 되돌린다.
  final VoidCallback onRestoreDraft;

  final String initialFeedback;

  /// 요약을 피드백 초안으로 옮긴다.
  final ValueChanged<String> onUseSummaryAsDraft;

  /// 입력창이 바뀔 때마다 현재 문구를 올려 준다 — 전송은 헤더 공유 메뉴가 한다.
  final ValueChanged<String> onFeedbackChanged;

  /// 초안을 서버에 저장하는 중이다. (#821)
  final bool savingFeedback;

  /// 입력창의 현재 문구를 그 주의 초안으로 저장한다. (#821)
  final VoidCallback onSaveFeedback;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final client = report.client;
    // 지난 날인데 기록이 없는 요일. 아직 오지 않은 날과 구분해서 그린다.
    final elapsed = report.isCurrentWeek
        ? elapsedWeekdays(nowKst())
        : weekdayCount;
    final unlogged = <int>{
      for (var i = 0; i < elapsed && i < report.weekCompletion.length; i++)
        if (report.weekCompletion[i] == 0) i,
    };
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
        if (showSummary) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _ReportAiCard(report: report, onUseAsDraft: onUseSummaryAsDraft),
        ],
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: l.reportsFeedbackTitle,
          // 저장 버튼을 제목 행에 둔다 — 입력창 위에 버튼만 있는 줄이 따로
          // 있으면 카드가 그만큼 세로로 늘어난다.
          // 되돌리기를 저장 옆에 둔다 — 입력창을 되돌릴 수단이 그 입력창 바로
          // 위에 있어야 한다.
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ActionButton(
                label: l.reportsFeedbackRestore,
                icon: Icons.undo,
                onPressed: canRestoreDraft ? onRestoreDraft : null,
              ),
              const SizedBox(width: AppSpacing.xs),
              ActionButton(
                key: const ValueKey<String>('report-feedback-save'),
                label: savingFeedback
                    ? l.reportsFeedbackSaving
                    : l.reportsFeedbackSave,
                icon: Icons.save_outlined,
                onPressed: savingFeedback ? null : onSaveFeedback,
              ),
            ],
          ),
          child: _FeedbackEditor(
            key: ValueKey<String>(
              'feedback-${report.client.id}-'
              '${report.weekStart.toIso8601String()}-$draftEpoch',
            ),
            initialText: initialFeedback,
            onChanged: onFeedbackChanged,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // 운동과 식단을 카드로 나눈다. 예전에는 나트륨 추이 그래프가 '요일별
        // 운동 이행률' 카드 안에 있어 제목과 내용이 서로 다른 말을 했다(#754).
        SectionCard(
          title: l.reportsCompletionByDay,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 계열은 리포트가 자기 주의 것을 들고 온다 — 보고 있는 주가
              // 어디든 같은 규칙으로 그린다(#752).
              if (report.weekCompletion.length == weekdayCount)
                BarSeriesChart(
                  values: report.weekCompletion,
                  labels: weekdayLabels(AppLocalizations.of(context)),
                  maxValue: 100,
                  height: 80,
                  showValues: true,
                  valueSuffix: '%',
                  // 아직 오지 않은 요일은 이번 주에만 있다.
                  pendingFromIndex: report.isCurrentWeek
                      ? elapsedWeekdays(nowKst())
                      : null,
                  // 기록이 없는 날을 0% 로 그리면 '0% 수행'이라는 다른 뜻이
                  // 되고, 평균에서 빠진 이유도 화면에서 사라진다.
                  missingIndices: unlogged,
                )
              else
                EmptyHint(message: l.reportsNoWorkoutsThisWeek),
              if (report.weekCompletion.length == weekdayCount) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                // 막대 바로 아래에 그날의 운동 내역. 67% 가 어디서 나온
                // 값인지 같은 카드 안에서 답이 난다(#754).
                _DailyDetail(report: report),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: l.reportsDietTrend,
          trailing: Text(
            l.reportsSodiumOverInline(report.sodiumOverDays ?? 0),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: (report.sodiumOverDays ?? 0) > 2
                  ? AppColors.overTarget
                  : AppColors.subtleForeground,
            ),
          ),
          child: _MetricTrendSection(report: report),
        ),
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
  const _MetricTrendSection({required this.report});

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
    final report = widget.report;
    final series = switch (_metric) {
      _TrendMetric.calories => report.caloriesWeek.map((v) => v.toDouble()),
      _TrendMetric.sodium => report.sodiumWeek.map((v) => v.toDouble()),
      _TrendMetric.sugar => report.sugarWeek,
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
        // 기록이 하나도 없는 주까지 바닥에 붙은 0 선을 그리면 "기록 없음"이
        // "하루 0kcal" 처럼 읽힌다.
        if (values.isEmpty || values.every((v) => v == 0))
          EmptyHint(
            message: widget.report.isCurrentWeek
                ? l.reportsNoMetricRecords(_label(l, _metric))
                : l.reportsNoLastWeekMetricTrend(_label(l, _metric)),
          )
        else
          MetricTrendChart(
            values: values,
            dayLabels: weekdayLabels(l),
            goal: _goal,
            ticks: _ticks,
            // 지난 주는 이미 다 지났으니 선을 일요일까지 잇되, 그 자리에
            // '오늘' 표시를 붙이지는 않는다.
            todayIndex: widget.report.isCurrentWeek
                ? elapsedWeekdays(nowKst()) - 1
                : weekdayCount - 1,
            markToday: widget.report.isCurrentWeek,
            // 지표를 바꾸면 선을 처음부터 다시 그려 값이 바뀐 것을 눈으로
            // 따라가게 한다.
            replayKey: _metric,
            goalLabel: l.chartGoalLabel(metricTrendNumber(_goal)),
            formatTick: metricTrendNumber,
          ),
        const Divider(height: AppSpacing.xl, color: AppColors.border),
        _FourWeekMetricTrend(
          report: widget.report,
          label: _label(l, _metric),
          values: (WeeklyReport r) => switch (_metric) {
            _TrendMetric.calories => r.caloriesWeek,
            _TrendMetric.sodium => r.sodiumWeek,
            _TrendMetric.sugar => r.sugarWeek,
          },
          goal: _goal,
          unit: switch (_metric) {
            _TrendMetric.calories => 'kcal',
            _TrendMetric.sodium => 'mg',
            _TrendMetric.sugar => 'g',
          },
        ),
      ],
    );
  }
}

/// 선택한 영양 지표의 최근 4주 주간 평균 — 운동 카드의 같은 블록과 짝이다.
///
/// 이번 주 꺾은선은 "이번 주에 언제 튀었나"만 말한다. 트레이너가 정말 알고
/// 싶은 건 **코칭이 먹히고 있나**이고, 그건 주 단위 평균 넷을 나란히 놓아야
/// 보인다(#754).
///
/// 새로 받아 오는 값이 없다 — 운동 카드가 이미 지난 세 주의 리포트를 보고
/// 있고, 그 리포트가 각자 자기 주의 계열을 들고 있다.
class _FourWeekMetricTrend extends ConsumerWidget {
  const _FourWeekMetricTrend({
    required this.report,
    required this.label,
    required this.values,
    required this.goal,
    required this.unit,
  });

  final WeeklyReport report;

  /// 지표 이름(칼로리·나트륨·당류).
  final String label;

  /// 한 주의 리포트에서 이 지표의 요일별 계열을 꺼내는 방법.
  final List<num> Function(WeeklyReport) values;

  /// 목표. 눈금과 주의 색의 기준을 겸한다.
  final double goal;

  /// 눈금 끝은 목표의 1.5배. 목표를 눈금 끝으로 삼으면 — 김민수의 나트륨처럼
  /// 네 주가 모두 목표를 넘은 경우 — 막대 넷이 전부 꽉 차 버려 어느 주가 더
  /// 나빴는지가 사라진다. 여유를 두고 2/3 지점에 목표선을 그으면 초과 여부와
  /// 주별 차이를 함께 읽는다.
  static const double _headroom = 1.5;

  /// 값 뒤에 붙는 단위.
  final String unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final weeks = <AsyncValue<WeeklyReport>>[
      for (var offset = 3; offset >= 0; offset--)
        ref.watch(
          weeklyReportProvider((
            client: report.client,
            weekStart: report.weekStart.subtract(Duration(days: 7 * offset)),
          )),
        ),
    ];
    final labels = <String>[
      l.reportsWeeksAgo(3),
      l.reportsWeeksAgo(2),
      l.reportsLastWeek,
      report.isCurrentWeek ? l.reportsThisWeek : l.reportsSelectedWeek,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${l.reportsRecentWeeks} · $label',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.subtleForeground,
                ),
              ),
            ),
            // 세로선이 무엇인지 한 번은 적어 준다.
            Text(
              l.reportsGoalMarker('${metricTrendNumber(goal)}$unit'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var i = 0; i < weeks.length; i++)
          () {
            final week = weeks[i].valueOrNull;
            // 기록한 날만 평균한다 — 아직 오지 않은 날을 0 으로 세면 이번 주가
            // 늘 나아 보인다. 화면 곳곳이 같은 규칙을 쓴다.
            final mean = week == null ? null : recordedMean(values(week));
            return _WeekTrendBar(
              label: labels[i],
              fraction: mean == null ? null : mean / (goal * _headroom),
              goalFraction: 1 / _headroom,
              text: mean == null
                  ? '-'
                  : '${metricTrendNumber(mean.round())}$unit',
              loading: weeks[i].isLoading,
              current: i == weeks.length - 1,
              warn: mean != null && mean > goal,
              valueWidth: 62,
            );
          }(),
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
      // 내용에 맞춰 자란다. 초안이 문단 글이 되면서 7줄에서 잘려, 트레이너가
      // 보낼 글을 스크롤해야만 다 읽을 수 있었다 — 손보기 전에 전체를 읽는
      // 것이 이 입력창의 용도다(#755).
      maxLines: null,
      // 입력 글씨의 기본은 bodyLarge(17)라 카드의 다른 글씨보다 유독 컸다.
      // 임의의 숫자 대신 타이포 스케일의 한 단계 아래를 쓴다.
      style: Theme.of(context).textTheme.bodySmall,
      decoration: InputDecoration(
        hintText: l.reportsFeedbackHint,
        // 이 글은 회원에게 그대로 나간다. 무엇이 이미 채워져 있는지와 보내기
        // 전에 할 일을 그 자리에서 말해 준다 — 'AI' 라고 하지 않는 이유는
        // 이 초안이 수치에서 조립한 템플릿이지 생성된 문장이 아니어서다.
        helperText: l.reportsFeedbackDraftNote,
        helperMaxLines: 2,
        // 본문과 같은 톤이면 초안의 일부처럼 읽힌다 — 안내는 한 단계 연하게.
        helperStyle: const TextStyle(
          color: AppColors.disabledForeground,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 최근 4주 이행률 — 얇은 가로 막대 넷.
///
/// 예전에는 세로 막대 네 개짜리 카드였다. 값이 넷뿐인데 카드 하나를 통째로
/// 썼다. 가로로 눕히면 길이를 바로 견줄 수 있어 자리를 훨씬 덜 쓰고도 흐름이
/// 읽힌다(#754).
///
/// 지난 주 대비 변화는 적지 않는다 — 위 '이번 주 vs 지난 주' 카드가 이미 같은
/// 값을 말한다. 이 블록이 더 말해 주는 것은 **네 주의 흐름**이다: 두 주만 보면
/// 나아지는 것처럼 보이는 주도 네 주를 늘어놓으면 오르내림이 드러난다.
class _FourWeekTrend extends ConsumerWidget {
  const _FourWeekTrend({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final weeks = <AsyncValue<WeeklyReport>>[
      for (var offset = 3; offset >= 0; offset--)
        ref.watch(
          weeklyReportProvider((
            client: report.client,
            weekStart: report.weekStart.subtract(Duration(days: 7 * offset)),
          )),
        ),
    ];
    final labels = <String>[
      l.reportsWeeksAgo(3),
      l.reportsWeeksAgo(2),
      l.reportsLastWeek,
      report.isCurrentWeek ? l.reportsThisWeek : l.reportsSelectedWeek,
    ];
    // 폭은 위 요일별 그래프에 맞춘다. 좁게 묶으면 같은 카드 안에서 두 블록이
    // 남남처럼 보이고, 길게 뻗을수록 84% 와 87% 의 차이가 눈에 들어온다.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l.reportsRecentWeeks,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.subtleForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var i = 0; i < weeks.length; i++)
          () {
            final value = weeks[i].valueOrNull?.completionAvg;
            return _WeekTrendBar(
              label: labels[i],
              fraction: value == null ? null : value / 100,
              text: value == null ? '-' : '$value%',
              loading: weeks[i].isLoading,
              current: i == weeks.length - 1,
              // 이행률이 이 아래면 주의로 본다 — 주의 배지와 같은 기준.
              warn: value != null && value < 70,
            );
          }(),
      ],
    );
  }
}

/// 한 주 한 줄 — 라벨 · 가로 막대 · 값.
///
/// 이행률(%)과 영양 지표(kcal·mg·g)가 같은 줄 모양을 쓴다. 값의 뜻은 부르는
/// 쪽이 정하고, 여기서는 **길이와 색만** 그린다.
class _WeekTrendBar extends StatelessWidget {
  const _WeekTrendBar({
    required this.label,
    required this.fraction,
    required this.text,
    required this.loading,
    required this.current,
    this.warn = false,
    this.goalFraction,
    this.valueWidth = 40,
  });

  final String label;

  /// 막대 길이(0~1). 기록이 없으면 null — 막대를 그리지 않는다.
  final double? fraction;

  /// 오른쪽에 찍을 값. 기록이 없으면 부르는 쪽이 '-' 를 준다.
  final String text;

  final bool loading;

  /// 보고 있는 주. 앞선 주와 눈에 띄게 구분한다.
  final bool current;

  /// 목표를 벗어난 주(이행률이 낮거나, 영양 지표가 목표를 넘었거나).
  final bool warn;

  /// 눈금 위 목표의 위치(0~1). 막대가 이 선을 넘었는지가 곧 목표 초과다.
  /// 목표가 눈금 끝과 같으면(이행률 100%) 선을 긋지 않는다 — 테두리와 겹친다.
  final double? goalFraction;

  /// 값 칸 너비. 'kcal' 처럼 단위가 붙으면 넓혀 준다.
  final double valueWidth;

  @override
  Widget build(BuildContext context) {
    // 목표를 벗어난 주는 빨강, 그 밖은 브랜드 색. 보고 있는 주만 제 색을
    // 쓰고 앞선 주는 흐리게 깔아, 색으로 초과 여부를 읽으면서도 어느 줄이
    // 이번 주인지 헷갈리지 않게 한다.
    final base = warn ? AppColors.overTarget : AppColors.primary;
    final tone = fraction == null
        ? AppColors.borderStrong
        : current
        ? base
        : base.withValues(alpha: 0.35);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                color: current
                    ? AppColors.foreground
                    : AppColors.subtleForeground,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.all(AppRadius.pill),
              child: Stack(
                children: <Widget>[
                  Container(height: 9, color: AppColors.inputBackground),
                  // 눈금 위쪽 끝을 고정해 둔다 — 그 주의 최댓값에 맞춰 늘이면
                  // 2,288 과 2,166 이 전혀 다른 길이로 보인다.
                  FractionallySizedBox(
                    widthFactor: (fraction ?? 0).clamp(0.0, 1.0),
                    child: Container(height: 9, color: tone),
                  ),
                  // 목표선은 채움 위에 긋는다 — 아래 깔면 넘긴 주에서 가려져,
                  // 정작 넘겼는지 봐야 할 때 보이지 않는다.
                  if (goalFraction != null && goalFraction! < 1)
                    FractionallySizedBox(
                      widthFactor: goalFraction!,
                      alignment: Alignment.centerLeft,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 1.5,
                          height: 9,
                          color: AppColors.accentDark,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: valueWidth,
            child: Text(
              loading ? '…' : text,
              textAlign: TextAlign.right,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                color: current
                    ? AppColors.foreground
                    : AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 리포트 요약 카드 — 트레이너가 매주 같은 문장을 처음부터 쓰지 않게 한다.
///
/// 결과는 그대로 읽는 글이 아니라 **피드백 초안으로 가져다 고칠 재료**다.
/// 그래서 `피드백으로 가져오기` 가 이 카드의 본래 동선이고, 문장이 마음에 안
/// 들면 다시 생성한다(#755).
///
/// 데모에는 모델이 없어 수치에서 조립한 문장이 온다. 실서버도 공급자 장애면
/// 같은 문장으로 되돌아온다 — 그 경우 `생성` 배지를 달지 않아, 트레이너가 이
/// 문장을 어디까지 믿을지 알 수 있다.
class _ReportAiCard extends ConsumerWidget {
  const _ReportAiCard({required this.report, required this.onUseAsDraft});

  final WeeklyReport report;

  /// 요약을 피드백 입력창으로 옮긴다.
  final void Function(String draft) onUseAsDraft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final key = (client: report.client, weekStart: report.weekStart);
    final summary = ref.watch(reportSummaryProvider(key));
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.aiCardGradientStart,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.aiCardGradientEnd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.auto_awesome, color: AppColors.primary, size: 19),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l.reportsAiTitle,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (summary.valueOrNull?.isGenerated ?? false)
                      Text(
                        l.reportsAiGenerated,
                        style: const TextStyle(
                          color: AppColors.subtleForeground,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                summary.when(
                  loading: () => Text(
                    l.reportsAiLoading,
                    style: const TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // 생성이 실패해도 카드가 비지 않는다 — 예전 안내문으로
                  // 되돌아가 그 자리에 무엇이 올지는 말해 준다.
                  error: (_, _) => Text(
                    l.reportsAiUnavailable,
                    style: const TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  data: (value) => _SummaryBody(
                    summary: value,
                    onRegenerate: () =>
                        ref.invalidate(reportSummaryProvider(key)),
                    onUseAsDraft: () => onUseAsDraft(value.asDraft),
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

/// 요약 자리에 아직 내용이 없을 때 — 그 자리에 **무엇이 뜨는지**만 적는다.
///
/// 빈 칸으로 두면 왼쪽 열이 목록 아래로 그냥 잘린 것처럼 보이고, 고객을 고르면
/// 무엇을 얻는지도 알 수 없다. 카드 껍데기는 [_ReportAiCard] 와 같게 두어,
/// 내용이 채워질 때 자리가 흔들리지 않는다.
class _ReportSummaryHint extends StatelessWidget {
  const _ReportSummaryHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      key: const ValueKey<String>('reports-summary-hint'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.aiCardGradientStart,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.aiCardGradientEnd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  message,
                  style: const TextStyle(
                    color: AppColors.mutedForeground,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
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

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.summary,
    required this.onRegenerate,
    required this.onUseAsDraft,
  });

  final ReportSummary summary;
  final VoidCallback onRegenerate;
  final VoidCallback onUseAsDraft;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          summary.headline,
          style: const TextStyle(
            color: AppColors.foreground,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
        for (final point in summary.points) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            '· $point',
            style: const TextStyle(
              color: AppColors.mutedForeground,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        // 카드가 292px 왼쪽 열로 내려오면서(#897) 두 동작이 한 줄에 들어가지
        // 않는 조합이 생겼다 — 영어 · 배율 1.3 이 그렇다. 줄을 접어 받는다.
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            _SummaryAction(
              label: l.reportsAiUseAsDraft,
              icon: Icons.edit_note,
              onTap: onUseAsDraft,
            ),
            _SummaryAction(
              label: l.reportsAiRegenerate,
              icon: Icons.refresh,
              onTap: onRegenerate,
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryAction extends StatelessWidget {
  const _SummaryAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: const BorderRadius.all(AppRadius.sm),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 3),
          // 한 동작만으로도 열 폭을 넘는 조합이 있다 — 잘라내지 않고 접는다.
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
    required this.generatingPdf,
    required this.onPdf,
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
  final bool generatingPdf;
  final Future<void> Function(WeeklyReport report) onPdf;

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
        style: const MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.card),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(AppRadius.md),
              side: BorderSide(color: AppColors.borderStrong),
            ),
          ),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: AppSpacing.xs),
          ),
          minimumSize: WidgetStatePropertyAll(Size(_menuMinWidth, 0)),
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
          Directionality(
            textDirection: TextDirection.ltr,
            child: MenuItemButton(
              key: const ValueKey<String>('reports-share-pdf'),
              style: _itemStyle,
              leadingIcon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
              onPressed: target == null || generatingPdf
                  ? null
                  : () => _pdf(ref, target),
              child: Text(
                generatingPdf ? l.reportsPdfGenerating : l.reportsPdfLabel,
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

  void _pdf(WidgetRef ref, TrainerClient target) {
    final report = ref
        .read(weeklyReportProvider((client: target, weekStart: weekStart)))
        .valueOrNull;
    if (report != null) onPdf(report);
  }
}

/// A generated report's explicit delivery actions.
///
/// Kept public so the save and print boundaries can be exercised without
/// generating a PDF in a widget test.
class ReportPdfExportDialog extends ConsumerStatefulWidget {
  const ReportPdfExportDialog({
    required this.report,
    required this.bytes,
    super.key,
  });

  final WeeklyReport report;
  final Uint8List bytes;

  @override
  ConsumerState<ReportPdfExportDialog> createState() =>
      _ReportPdfExportDialogState();
}

class _ReportPdfExportDialogState extends ConsumerState<ReportPdfExportDialog> {
  bool _sending = false;

  /// 파일명은 로컬 저장뿐 아니라 multipart 헤더의 `filename` 으로도 그대로
  /// 나간다. 경로 구분자 외에 제어문자까지 지우는 이유다 — 고객 이름에 개행이
  /// 섞이면 헤더가 깨진다. 지운 결과가 비면 날짜만 남은 이름이 되므로 대체어를
  /// 쓴다.
  String _fileNameFor(AppLocalizations l) {
    final safeName = widget.report.client.name
        .replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f\x7f]'), '_')
        .trim();
    final name = safeName.replaceAll('_', '').trim().isEmpty
        ? l.reportsPdfFallbackClient
        : safeName;
    return '${name}_${ymd(widget.report.weekStart)}_주간리포트.pdf';
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(success)));
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.reportsPdfActionFailed)),
        );
      }
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    final l = AppLocalizations.of(context);
    await _run(
      () => ref
          .read(reportPdfSenderProvider)
          .send(
            clientId: widget.report.client.id,
            weekStart: widget.report.weekStart,
            bytes: widget.bytes,
            fileName: _fileNameFor(l),
            message: l.reportsPdfMessage,
          ),
      l.reportsPdfSent(widget.report.client.name),
    );
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final actions = ref.read(reportPdfActionsProvider);
    return AlertDialog(
      title: Text(l.reportsPdfLabel),
      content: Text(l.reportsPdfReady(widget.report.client.name)),
      actions: <Widget>[
        TextButton.icon(
          key: const ValueKey<String>('report-pdf-send'),
          onPressed: _sending ? null : _send,
          icon: const Icon(Icons.send_outlined),
          label: Text(
            _sending ? l.reportsPdfSending : l.reportsPdfSendToClient,
          ),
        ),
        TextButton.icon(
          key: const ValueKey<String>('report-pdf-save'),
          onPressed: () => _run(
            () => actions.save(widget.bytes, _fileNameFor(l)),
            l.reportsPdfSaveStarted,
          ),
          icon: const Icon(Icons.download_outlined),
          label: Text(l.reportsPdfSave),
        ),
        TextButton.icon(
          key: const ValueKey<String>('report-pdf-print'),
          onPressed: () => _run(
            () => actions.print(widget.bytes, _fileNameFor(l)),
            l.reportsPdfPrintOpened,
          ),
          icon: const Icon(Icons.print_outlined),
          label: Text(l.reportsPdfPrint),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.reportsPdfClose),
        ),
      ],
    );
  }
}

/// 요일별 운동 내역 — 막대 아래에 하루하루를 이행률·운동 이름과 함께 적는다.
///
/// 예전에는 이행률·PT 세션·나트륨 초과를 큰 숫자로 보여 주는 카드가 따로
/// 있었다. 그 세 숫자는 트레이너 피드백 초안에 문장으로 이미 적혀 있어 같은
/// 값을 두 번 보여 주는 셈이었고, 정작 "87% 가 어디서 나왔나" 는 어디에도
/// 없었다. 막대 바로 아래에 표로 두면 같은 카드 안에서 답이 난다(#754).
class _DailyDetail extends StatelessWidget {
  const _DailyDetail({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 막대 아래에 요일 칸을 그대로 이어 붙인다 — 월요일 막대 밑에
        // 월요일에 한 운동이 온다.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var i = 0; i < weekdayCount; i++)
              _DailyDetailColumn(
                day: i < report.days.length ? report.days[i] : null,
              ),
          ],
        ),
        if (report.completionAvg != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.sm),
          // 마지막 줄에 이번 주를 앞선 세 주 옆에 놓는다. 며칠을 나눈
          // 값인지는 따로 적지 않는다 — 값이 있는 막대를 세면 나온다(#754).
          _FourWeekTrend(report: report),
        ],
      ],
    );
  }
}

/// 요일 한 칸의 내역 — 막대 바로 아래에 그날 한 일을 세로로 적는다.
class _DailyDetailColumn extends StatelessWidget {
  const _DailyDetailColumn({required this.day});

  final ReportDay? day;

  @override
  Widget build(BuildContext context) {
    final names = day?.exercises ?? const <String>[];
    return Expanded(
      // 막대와 같은 좌우 여백을 써야 칸이 세로로 맞는다.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 이행률과 몇 개 중 몇 개인지는 적지 않는다 — 퍼센트는 바로 위
            // 막대가 이미 말하고, 개수는 아래 ✓/✗ 를 세면 나온다. 기록이 없는
            // 날은 막대 쪽에 '기록 없음' 이 적히고, 아직 오지 않은 날은 비워
            // 둔다 — 빈칸이 곧 "아직" 이다.
            for (final name in names)
              ExerciseLine(line: name, fontSize: 11.5, maxLines: 2),
          ],
        ),
      ),
    );
  }
}
