import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/core/utils/request_id.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/consultations/data/repositories/consultation_repository.dart';
import 'package:oncare_trainer/features/consultations/presentation/widgets/consultation_inbox_sheet.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/cancel_session_dialog.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/complete_session_dialog.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/consultation_inbox_action.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/reservation_slots_sheet.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/schedule_date_nav_bar.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/schedule_timeline_row.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/schedule_week_grid.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/schedule_week_strip.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/session_card.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/session_program_editor.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/session_sheet.dart';
import 'package:oncare_trainer/features/search/presentation/widgets/client_search_bar.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';

/// 스케줄 tab — the trainer's calendar, in two views.
///
/// **일** is the timeline: every booked session expands, 완료 shows the
/// finished program and can be sent to the client, 예정 shows the plan
/// (or a no-plan hint) with a chat shortcut. Add / edit (15-minute
/// steps) / delete / 완료 처리 all live here.
///
/// **주** is a seven-column overview for the question the timeline can't
/// answer — where the gaps are. Picking a day from it drops back into
/// the timeline.
///
/// Both the view and the browsed day come from the URL (`?v=week&d=…`)
/// so the dashboard can link to a specific day and a refresh keeps it.
class SchedulePage extends ConsumerStatefulWidget {
  /// Creates the schedule tab.
  const SchedulePage({super.key, this.view, this.date});

  /// `day` (default) or `week`.
  final String? view;

  /// Browsed day as `YYYY-MM-DD`; invalid or absent means today.
  final String? date;

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  /// The calendar day being browsed (defaults to today).
  late DateTime _selectedDay = _resolveDay(widget.date);

  /// Leftmost day of the visible 7-day strip. Centred on today (D-3) so
  /// today sits in the middle; chevrons shift it a week at a time.
  late DateTime _weekAnchor = _selectedDay.subtract(const Duration(days: 3));

  /// Whether the week grid is showing.
  late bool _weekView = widget.view == 'week';

  /// Session shown in the week view's detail panel.
  String? _selectedSessionId;

  /// 프로그램 전송이 진행 중인 세션. 두 번 눌러 두 번 보내지 않는다.
  String? _sendingProgramId;

  /// 세션별 전송 멱등키. 실패한 시도의 키를 그대로 다시 써야 재시도가 중복
  /// 배정을 만들지 않는다(#581 과 같은 규약).
  final Map<String, String> _sendRequestIds = <String, String>{};

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Parses a `YYYY-MM-DD` route parameter, falling back to today. A
  /// malformed date in the URL should land the trainer on today rather
  /// than an error page.
  static DateTime _resolveDay(String? raw) {
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    return _dateOnly(parsed ?? nowKst());
  }

  @override
  void didUpdateWidget(SchedulePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The URL is the source of truth: a link from the dashboard, or
    // back/forward, must move the calendar.
    if (widget.date != oldWidget.date) {
      final next = _resolveDay(widget.date);
      setState(() {
        _selectedDay = next;
        _weekAnchor = next.subtract(const Duration(days: 3));
      });
    }
    if (widget.view != oldWidget.view) {
      setState(() => _weekView = widget.view == 'week');
    }
  }

  /// Moves to [day], keeping the URL in step so the view is shareable.
  void _selectDay(DateTime day, {bool toTimeline = false}) {
    setState(() {
      _selectedDay = _dateOnly(day);
      _selectedSessionId = null;
      if (toTimeline) _weekView = false;
    });
    context.go(
      AppRoutes.scheduleView(
        _weekView ? 'week' : 'day',
        date: ymd(_selectedDay),
      ),
    );
  }

  final Set<String> _expanded = <String>{};
  String? _editingScheduleId;
  String? _editingProgramId;

  void _toggle(ScheduleSession s) {
    if (!s.expandable) return;
    setState(() {
      _expanded.contains(s.id) ? _expanded.remove(s.id) : _expanded.add(s.id);
    });
  }

  /// New schedules use a sheet; existing schedules are edited in their card.
  Future<void> _openSessionSheet() async {
    final clients = ref.read(clientsProvider).valueOrNull ?? const [];
    if (clients.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.card),
      ),
      builder: (context) => SessionSheet(
        clientNames: clients.map((c) => c.name).toList(),
        date: _selectedYmd,
        existing: null,
      ),
    );
  }

  Future<void> _openReservationSlotsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.card),
      ),
      builder: (context) => ReservationSlotsSheet(selectedDay: _selectedDay),
    );
  }

  Future<void> _openConsultationInbox() async {
    final date = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.card),
      ),
      builder: (_) => const ConsultationInboxSheet(),
    );
    final day = date == null ? null : DateTime.tryParse(date);
    if (day != null && mounted) _selectDay(day, toTimeline: true);
  }

  Future<void> _confirmDelete(ScheduleSession s) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(AppRadius.card),
        ),
        title: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.all(AppRadius.md),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: AppColors.destructive,
                size: 19,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(l.schedDeleteTitle, style: const TextStyle(fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l.schedDeleteConfirm(s.time, s.clientName),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.sm),
            // 삭제와 취소를 가르는 문장이다(#871). 실제 PT 가 진행되지 않은
            // 경우까지 삭제로 처리하면 그 사실이 어디에도 남지 않는다.
            Text(
              l.schedDeleteMeansRemove,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.subtleForeground,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          ActionButton(
            label: l.actionCancel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ActionButton(
            label: l.actionDelete,
            primary: true,
            tone: AppColors.destructive,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(scheduleRepositoryProvider).deleteSession(s.id);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.schedDeleteFailed)));
    }
  }

  /// 완료 처리 — asks for an optional trainer memo, then flips the
  /// session to 완료 and logs it to the client's 운동기록. The dialog
  /// pops `null` on cancel, or the (possibly empty) memo on confirm.
  Future<void> _confirmComplete(ScheduleSession s) async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) => CompleteSessionDialog(session: s),
    );
    if (note == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .completeSession(s.id, note: note);
    } catch (_) {
      // A DB or programJson-decode failure must not escape to the UI —
      // the session stays 예정 and the trainer is told (review PR 237).
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.schedCompleteFailed)));
    }
  }

  /// 취소 처리 — 취소 주체와 (선택) 사유를 받고 세션을 `취소` 로 남긴다. (#871)
  ///
  /// 삭제와 달리 일정 행이 남는다. 다이얼로그가 주체를 **고르게** 하는 까닭은
  /// 지표 때문이다 — 트레이너 사정의 취소와 고객 취소를 구분하지 않으면 나중에
  /// 회원의 낮은 이행률을 잘못 읽는다.
  Future<void> _confirmCancel(ScheduleSession s) async {
    final result = await showDialog<({String source, String reason})>(
      context: context,
      builder: (context) => CancelSessionDialog(session: s),
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .cancelSession(s.id, source: result.source, reason: result.reason);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.schedCancelFailed)));
    }
  }

  /// 노쇼 처리 — 예약된 시간에 회원이 오지 않았다는 기록. (#871)
  Future<void> _confirmNoShow(ScheduleSession s) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(AppRadius.card),
        ),
        title: Text(l.schedNoShowTitle, style: const TextStyle(fontSize: 17)),
        content: Text(
          l.schedNoShowConfirm(s.time, s.clientName),
          style: const TextStyle(fontSize: 14),
        ),
        actions: <Widget>[
          ActionButton(
            label: l.actionCancel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ActionButton(
            key: const ValueKey<String>('session-no-show-confirm'),
            label: l.schedNoShow,
            primary: true,
            tone: AppColors.warning,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(scheduleRepositoryProvider).markNoShow(s.id);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.schedNoShowFailed)));
    }
  }

  /// 완료한 세션의 프로그램을 그 회원에게 보낸다. (#822)
  ///
  /// 멱등키를 실어 보내므로 실패 후 다시 눌러도 회원의 루틴이 두 벌 생기지
  /// 않는다. 성공하면 세션 행에 남아, 화면이 '전송됨' 을 사실대로 말한다.
  Future<void> _sendProgram(ScheduleSession s) async {
    if (_sendingProgramId != null) return;
    final messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    setState(() => _sendingProgramId = s.id);
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .sendProgram(
            s.id,
            clientRequestId: _sendRequestIds[s.id] ??= newClientRequestId(),
          );
      if (!mounted) return;
      _sendRequestIds.remove(s.id); // 다음 전송은 새 시도다.
      messenger.showSnackBar(
        SnackBar(content: Text(l.schedSentTo(s.clientName))),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.coachSendFailed)));
    } finally {
      if (mounted) setState(() => _sendingProgramId = null);
    }
  }

  /// Jumps to the client's 채팅. The 고객 page decides whether that is a
  /// split panel or a full-width detail, so one location covers both.
  /// Falls back to the roster when the name can't be resolved (e.g. a
  /// renamed client).
  void _openChat(ScheduleSession s) {
    final clients = ref.read(clientsProvider).valueOrNull ?? const [];
    final match = clients.where((c) => c.name == s.clientName);
    if (match.isEmpty) {
      context.go(AppRoutes.clients);
      return;
    }
    context.go(AppRoutes.messagesFor(match.first.id));
  }

  String get _selectedYmd => ymd(_selectedDay);

  /// 날짜 행 오른쪽에 붙는 컨트롤 — `오늘` 과 `일|주`. (#882)
  ///
  /// 예전에는 페이지 헤더 오른쪽 끝에서 `예약 슬롯`·`새 일정` 같은 문서 액션과
  /// 섞여 있었다. 둘 다 **날짜를 바꾸는** 컨트롤인데 조작 대상(날짜 행)과 100px
  /// 넘게 떨어져 있었다. 일 보기와 주 보기가 같은 자리에 같은 것을 두도록
  /// 양쪽 날짜 행이 이 위젯을 함께 쓴다.
  Widget _viewControls() {
    final AppLocalizations l = AppLocalizations.of(context);
    final today = _dateOnly(nowKst());
    final defaultAnchor = today.subtract(const Duration(days: 3));
    final showToday = _selectedDay != today || _weekAnchor != defaultAnchor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showToday) ...<Widget>[
          ActionButton(
            label: l.labelToday,
            icon: Icons.today_outlined,
            onPressed: () {
              setState(() => _weekAnchor = defaultAnchor);
              _selectDay(today);
            },
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        SegmentedSwitch(
          labels: <String>[l.schedViewDay, l.schedViewWeek],
          selected: _weekView ? 1 : 0,
          onChanged: (i) {
            setState(() => _weekView = i == 1);
            context.go(
              AppRoutes.scheduleView(
                _weekView ? 'week' : 'day',
                date: _selectedYmd,
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final schedule = ref.watch(scheduleForDateProvider(_selectedYmd));
    // Keep the client stream live so the booking sheet and the chat
    // shortcut have data even when this tab is the first one opened.
    ref.watch(clientsProvider);
    // 오늘·기본 앵커 계산은 이제 [_viewControls] 안에 있다 — 그 버튼들이
    // 헤더가 아니라 날짜 행에 살기 때문이다(#882).
    final consultationInbox = ref.watch(consultationInboxEnabledProvider);
    final pendingConsultations = consultationInbox
        ? ref.watch(consultationPendingCountProvider).valueOrNull
        : null;

    return PageScaffold(
      title: l.schedTitle,
      subtitle: dateLabel(l, _selectedDay),
      headerCenter: const ClientSearchBar(),
      actions: <Widget>[
        // 오늘·일|주 는 날짜를 바꾸는 컨트롤이라 날짜 행 오른쪽으로 내렸다.
        // 비워진 이 자리에 상담 요청이 들어온다(#882).
        if (consultationInbox)
          ConsultationInboxAction(
            pending: pendingConsultations,
            onTap: _openConsultationInbox,
          ),
        ActionButton(
          key: const ValueKey<String>('schedule-open-slots'),
          label: l.schedSlots,
          icon: Icons.event_available_outlined,
          onPressed: () => _openReservationSlotsSheet(),
        ),
        ActionButton(
          label: l.schedNewSession,
          icon: Icons.add,
          primary: true,
          onPressed: () => _openSessionSheet(),
        ),
      ],
      scrollable: false,
      contentPadding: EdgeInsets.zero,
      // The week strip lives OUTSIDE the async `when()`: switching days
      // spins up a new provider that starts in `loading`, and blanking
      // the whole page to a spinner each tap made the strip flicker.
      // Only the session list reacts to the async state (review PR 245).
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _weekView ? _buildWeekGrid() : _buildDayView(schedule),
          ),
        ],
      ),
    );
  }

  /// 주 — a seven-column grid of the week's sessions. One range query
  /// backs it, so switching weeks doesn't fan out into seven streams.
  Widget _buildWeekGrid() {
    final AppLocalizations l = AppLocalizations.of(context);
    final start = _dateOnly(_weekAnchor);
    final end = start.add(const Duration(days: 6));
    final range = (from: ymd(start), to: ymd(end));
    final week = ref.watch(scheduleRangeProvider(range));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppLayout.pagePadding,
            AppLayout.pagePadding,
            AppLayout.pagePadding,
            AppSpacing.sm,
          ),
          child: ScheduleDateNavBar(
            start: start,
            end: end,
            onShift: (dir) => setState(
              () => _weekAnchor = _weekAnchor.add(Duration(days: 7 * dir)),
            ),
            trailing: _viewControls(),
          ),
        ),
        Expanded(
          child: week.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                l.schedLoadFailed,
                style: const TextStyle(color: AppColors.mutedForeground),
              ),
            ),
            data: (sessions) {
              ScheduleSession? selected;
              for (final session in sessions) {
                if (session.id == _selectedSessionId &&
                    session.date == _selectedYmd) {
                  selected = session;
                  break;
                }
              }
              if (selected == null) {
                for (final session in sessions) {
                  if (session.date == _selectedYmd) {
                    selected = session;
                    break;
                  }
                }
              }

              final grid = ScheduleWeekGrid(
                start: start,
                sessions: sessions,
                selectedDay: _selectedDay,
                onPickDay: _selectDay,
                onPickSession: (session) {
                  final day = DateTime.tryParse(session.date);
                  if (day == null) return;
                  setState(() {
                    _selectedDay = _dateOnly(day);
                    _selectedSessionId = session.id;
                    _expanded.add(session.id);
                  });
                  context.go(
                    AppRoutes.scheduleView('week', date: session.date),
                  );
                },
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 980) {
                    // 좁은 화면에는 오른쪽에 패널을 둘 폭이 없다. 예전에는
                    // 패널을 통째로 버렸는데, 탭 핸들러는 그대로 살아 있어서
                    // 누르면 선택만 바뀌고 화면은 그대로였다 — 트레이너에게는
                    // 버튼이 고장 난 것으로 보인다(#881).
                    //
                    // 같은 패널을 그리드 아래로 쌓는다. 표현을 바꾸지 않으므로
                    // 넓은 화면에서 익힌 것이 좁은 화면에서도 그대로 통한다.
                    if (selected == null) return grid;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(flex: 3, child: grid),
                        const Divider(height: 1, color: AppColors.borderStrong),
                        Expanded(flex: 2, child: _buildWeekDetail(selected)),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: grid),
                      const VerticalDivider(
                        width: 1,
                        color: AppColors.borderStrong,
                      ),
                      SizedBox(width: 340, child: _buildWeekDetail(selected)),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeekDetail(ScheduleSession? session) {
    final l = AppLocalizations.of(context);
    if (session == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            l.schedEmptyDay,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedForeground),
          ),
        ),
      );
    }

    final day = DateTime.tryParse(session.date) ?? _selectedDay;
    final today = _dateOnly(nowKst());
    final isFuture = day.isAfter(today);
    final dateText = day == today
        ? l.labelToday
        : l.dateMonthDay(day.month, day.day);
    final clients = ref.read(clientsProvider).valueOrNull ?? const [];

    return ListView(
      key: const Key('week-detail'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Text(
          l.schedTitle,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.md),
        SessionCard(
          session: session,
          expanded: true,
          onToggle: () {},
          onEditSchedule: () => setState(() {
            _editingScheduleId = session.id;
            _editingProgramId = null;
          }),
          onEditProgram: () => setState(() {
            _editingProgramId = session.id;
            _editingScheduleId = null;
          }),
          onDelete: () => _confirmDelete(session),
          onChat: () => _openChat(session),
          onComplete: (session.isUpcoming && !isFuture)
              ? () => _confirmComplete(session)
              : null,
          // 취소는 앞으로의 약속에도 열려 있다 — 거두는 것이 취소다. 노쇼는
          // 지나간 약속에만: 오지 않았다는 사실은 그 시간이 지나야 안다(#871).
          onCancel: session.isUpcoming ? () => _confirmCancel(session) : null,
          onNoShow: (session.isUpcoming && !isFuture)
              ? () => _confirmNoShow(session)
              : null,
          programDateLabel: dateText,
          sendingProgram: _sendingProgramId == session.id,
          onSendProgram: () => _sendProgram(session),
          inlineEditor: _editingScheduleId == session.id
              ? SessionSheet(
                  key: ValueKey<String>('week-session-editor-${session.id}'),
                  clientNames: clients.map((client) => client.name).toList(),
                  date: session.date,
                  existing: session,
                  inline: true,
                  onSaved: () => setState(() => _editingScheduleId = null),
                  onCancel: () => setState(() => _editingScheduleId = null),
                )
              : _editingProgramId == session.id
              ? SessionProgramEditor(
                  key: ValueKey<String>('week-program-editor-${session.id}'),
                  session: session,
                  onSaved: () => setState(() => _editingProgramId = null),
                  onCancel: () => setState(() => _editingProgramId = null),
                )
              : null,
        ),
      ],
    );
  }

  /// 일 — the week strip plus the day's timeline.
  Widget _buildDayView(AsyncValue<List<ScheduleSession>> schedule) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppLayout.pagePadding,
            AppLayout.pagePadding,
            AppLayout.pagePadding,
            AppSpacing.sm,
          ),
          child: ScheduleWeekStrip(
            weekAnchor: _weekAnchor,
            selectedDay: _selectedDay,
            bookedDates:
                ref.watch(bookedDatesProvider).valueOrNull ?? const <String>{},
            onSelect: _selectDay,
            onShiftWeek: (dir) => setState(
              () => _weekAnchor = _weekAnchor.add(Duration(days: 7 * dir)),
            ),
            trailing: _viewControls(),
          ),
        ),
        Expanded(child: _buildTimeline(schedule)),
      ],
    );
  }

  /// The scrollable timeline for the selected day.
  Widget _buildTimeline(AsyncValue<List<ScheduleSession>> schedule) {
    final AppLocalizations l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.pagePadding,
        AppSpacing.sm,
        AppLayout.pagePadding,
        AppLayout.pagePadding,
      ),
      children: <Widget>[
        ...schedule.when(
          loading: () => const <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (e, _) => <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(
                child: Text(
                  l.schedLoadFailed,
                  style: const TextStyle(color: AppColors.mutedForeground),
                ),
              ),
            ),
          ],
          data: _timelineChildren,
        ),
      ],
    );
  }

  /// The empty-state box or the session rows for [sessions].
  List<Widget> _timelineChildren(List<ScheduleSession> sessions) {
    final AppLocalizations l = AppLocalizations.of(context);
    // 완료 is offered only for 예정 sessions that aren't dated in the
    // future — you can't complete a class that hasn't happened yet. The
    // repository enforces the same rule (review PR 245).
    final isFuture = _selectedDay.isAfter(_dateOnly(nowKst()));
    final clients = ref.read(clientsProvider).valueOrNull ?? const [];
    final today = _dateOnly(nowKst());
    final dateLabel = _selectedDay == today
        ? l.labelToday
        : l.dateMonthDay(_selectedDay.month, _selectedDay.day);
    return <Widget>[
      if (sessions.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(AppRadius.card),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Text(
            l.schedEmptyDay,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
              height: 1.5,
            ),
          ),
        ),
      for (final s in sessions) ...<Widget>[
        ScheduleTimelineRow(
          session: s,
          expanded: _expanded.contains(s.id),
          onToggle: () => _toggle(s),
          onEditSchedule: () => setState(() {
            _editingScheduleId = s.id;
            _editingProgramId = null;
            _expanded.add(s.id);
          }),
          onEditProgram: () => setState(() {
            _editingProgramId = s.id;
            _editingScheduleId = null;
            _expanded.add(s.id);
          }),
          onDelete: () => _confirmDelete(s),
          onChat: () => _openChat(s),
          onComplete: (s.isUpcoming && !isFuture)
              ? () => _confirmComplete(s)
              : null,
          onCancel: s.isUpcoming ? () => _confirmCancel(s) : null,
          onNoShow: (s.isUpcoming && !isFuture)
              ? () => _confirmNoShow(s)
              : null,
          programDateLabel: dateLabel,
          sendingProgram: _sendingProgramId == s.id,
          onSendProgram: () => _sendProgram(s),
          inlineEditor: _editingScheduleId == s.id
              ? SessionSheet(
                  key: ValueKey<String>('inline-session-editor-${s.id}'),
                  clientNames: clients.map((c) => c.name).toList(),
                  date: _selectedYmd,
                  existing: s,
                  inline: true,
                  onSaved: () => setState(() => _editingScheduleId = null),
                  onCancel: () => setState(() => _editingScheduleId = null),
                )
              : _editingProgramId == s.id
              ? SessionProgramEditor(
                  key: ValueKey<String>('inline-program-editor-${s.id}'),
                  session: s,
                  onSaved: () => setState(() => _editingProgramId = null),
                  onCancel: () => setState(() => _editingProgramId = null),
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    ];
  }
}
