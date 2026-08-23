import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/reports/data/repositories/report_repository.dart';
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/features/reports/presentation/widgets/client_report_view.dart';
import 'package:oncare_trainer/features/reports/presentation/widgets/report_ai_card.dart';
import 'package:oncare_trainer/features/reports/presentation/widgets/report_client_picker.dart';
import 'package:oncare_trainer/features/reports/presentation/widgets/report_pdf_export_dialog.dart';
import 'package:oncare_trainer/features/reports/presentation/widgets/report_share_menu.dart';
import 'package:oncare_trainer/features/reports/presentation/widgets/report_summary_hint.dart';
import 'package:oncare_trainer/features/reports/presentation/widgets/report_week_nav.dart';
import 'package:oncare_trainer/features/reports/services/report_pdf_generator.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/search/presentation/widgets/client_search_bar.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
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
      messenger.showSnackBar(SnackBar(content: Text(l.reportsFeedbackSaved)));
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

  /// `8월 3일 – 8월 9일` — 카드 제목 줄에 적는 지금 보고 있는 주.
  static String _weekRangeLabel(AppLocalizations l, DateTime weekStart) {
    final DateTime weekEnd = weekStart.add(const Duration(days: 6));
    return l.dateRange(
      l.dateMonthDay(weekStart.month, weekStart.day),
      l.dateMonthDay(weekEnd.month, weekEnd.day),
    );
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
      _messageFor(AppLocalizations.of(context), report, _savedDraftOf(report)),
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
    // await 를 넘어 `context` 를 다시 읽지 않도록 messenger 와 함께 미리 잡아
    // 둔다. PDF 문구도 화면과 같은 로케일이어야 한다 (#964).
    final AppLocalizations l = AppLocalizations.of(context);
    final feedback = _messageFor(l, report, _savedDraftOf(report));
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
            l: l,
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
          SnackBar(content: Text(l.reportsPdfGenerationFailed)),
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
        // `이번 주로` 는 늘 같은 자리에 있다. 지난 주를 볼 때만 나타나던 때에는
        // 버튼이 생겼다 없어지며 공유 메뉴가 좌우로 밀려, 주를 몇 번 옮기면
        // 누르던 자리를 매번 눈으로 다시 찾아야 했다. 이번 주에서는 갈 곳이
        // 없으므로 회색으로 죽여 둔다(#1177).
        //
        // 주를 옮기는 화살표는 헤더가 아니라 리포트 카드 제목 줄에 있다 —
        // 날짜 버튼이 헤더 폭을 먹어 가운데 고객 검색 바가 다른 탭과 다른
        // 모양으로 접혔다.
        ActionButton(
          key: const ValueKey<String>('reports-go-this-week'),
          label: l.reportsGoThisWeek,
          icon: Icons.today_outlined,
          onPressed: _weekStart == weekStartOf(nowKst())
              ? null
              : _goToCurrentWeek,
        ),
        ReportShareMenu(
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
                    final clientPicker = ReportClientPicker(
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
                            ReportSummaryHint(
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
                    // 주 이동은 리포트를 못 읽은 화면에도 있어야 한다 —
                    // 카드 안에만 두면 실패한 주에서 나갈 길이 사라진다.
                    final Widget weekNav = ReportWeekNav(
                      rangeLabel: _weekRangeLabel(l, _weekStart),
                      onPrev: () => _shiftWeek(-1),
                      // 앞으로는 이번 주까지만 간다 — 아직 오지 않은 주의
                      // 리포트는 빈 화면이다.
                      onNext: _weekStart.isBefore(weekStartOf(nowKst()))
                          ? () => _shiftWeek(1)
                          : null,
                    );
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
                        trailing: weekNav,
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
                        trailing: weekNav,
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
                      data: (data) => ClientReportView(
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
                        weekNav: weekNav,
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
                          ReportSummaryHint(message: l.reportsAiLoading),
                      error: (_, _) =>
                          ReportSummaryHint(message: l.reportsAiUnavailable),
                      data: (data) => ReportAiCard(
                        report: data,
                        // 목록 아래 남는 자리를 채운다. 카드 안에서 스크롤하므로
                        // 열이 화면 밖으로 자라지 않는다(#1177).
                        fill: true,
                        onUseAsDraft: (draft) =>
                            _useSummaryAsDraft(l, data, savedDraft, draft),
                      ),
                    );
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          key: const ValueKey<String>('reports-left-column'),
                          // 프로그램 탭의 왼쪽 고객 열과 같은 폭이다 — 두 탭이
                          // 같은 자리에 같은 목록을 놓는데 카드 폭만 달라
                          // 탭을 오갈 때 열이 흔들려 보였다. 줄어든 만큼은
                          // 오른쪽 리포트 카드들이 가져간다. (#958)
                          width: 260,
                          // 목록(5줄 고정)에 요약 카드가 더해지면 짧은 창에서는
                          // 열이 화면보다 길어진다. 이 열 안에서만 스크롤하게
                          // 두어 오른쪽 리포트와는 여전히 따로 움직인다.
                          child: LayoutBuilder(
                            builder: (context, column) {
                              // 창이 짧으면 예전처럼 열 안에서 스크롤한다 —
                              // 목록만으로도 자리가 모자란 높이에서 요약까지
                              // 늘리면 둘 다 못 읽는다.
                              if (column.maxHeight <
                                  AppLayout.reportsSummaryFillMinHeight) {
                                return SingleChildScrollView(
                                  key: const ValueKey<String>(
                                    'reports-left-scroll',
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      clientPicker,
                                      const SizedBox(height: AppSpacing.lg),
                                      summarySlot,
                                    ],
                                  ),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  clientPicker,
                                  const SizedBox(height: AppSpacing.lg),
                                  Expanded(child: summarySlot),
                                ],
                              );
                            },
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
