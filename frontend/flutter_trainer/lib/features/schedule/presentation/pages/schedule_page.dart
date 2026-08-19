import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/core/utils/request_id.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/consultations/data/repositories/consultation_repository.dart';
import 'package:oncare_trainer/features/consultations/presentation/widgets/consultation_inbox_sheet.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_recurrence.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/reservation_slots_sheet.dart';
import 'package:oncare_trainer/features/search/presentation/widgets/client_search_bar.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';
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
      builder: (context) => _SessionSheet(
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
      builder: (context) => _CompleteDialog(session: s),
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
      builder: (context) => _CancelDialog(session: s),
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
          _ConsultationInboxAction(
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
          child: _DateNavBar(
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

              final grid = _WeekGrid(
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
        _SessionCard(
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
              ? _SessionSheet(
                  key: ValueKey<String>('week-session-editor-${session.id}'),
                  clientNames: clients.map((client) => client.name).toList(),
                  date: session.date,
                  existing: session,
                  inline: true,
                  onSaved: () => setState(() => _editingScheduleId = null),
                  onCancel: () => setState(() => _editingScheduleId = null),
                )
              : _editingProgramId == session.id
              ? _ProgramEditor(
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
          child: _ScheduleWeekStrip(
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
        _TimelineRow(
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
              ? _SessionSheet(
                  key: ValueKey<String>('inline-session-editor-${s.id}'),
                  clientNames: clients.map((c) => c.name).toList(),
                  date: _selectedYmd,
                  existing: s,
                  inline: true,
                  onSaved: () => setState(() => _editingScheduleId = null),
                  onCancel: () => setState(() => _editingScheduleId = null),
                )
              : _editingProgramId == s.id
              ? _ProgramEditor(
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

/// 완료 처리 확인 다이얼로그 — owns the memo controller so it outlives
/// the route's exit transition (disposing it in the caller races the
/// dialog teardown).
class _CompleteDialog extends StatefulWidget {
  const _CompleteDialog({required this.session});

  final ScheduleSession session;

  @override
  State<_CompleteDialog> createState() => _CompleteDialogState();
}

class _CompleteDialogState extends State<_CompleteDialog> {
  final TextEditingController _memo = TextEditingController();

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final s = widget.session;
    return AlertDialog(
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
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(AppRadius.md),
            ),
            child: const Icon(
              Icons.task_alt,
              color: AppColors.success,
              size: 19,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(l.schedCompleteTitle, style: const TextStyle(fontSize: 17)),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l.schedCompleteBody(s.time, s.clientName),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _memo,
              decoration: InputDecoration(
                hintText: l.schedNoteOptional,
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        ActionButton(
          label: l.actionCancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ActionButton(
          label: l.schedCompleteAction,
          primary: true,
          onPressed: () => Navigator.of(context).pop(_memo.text.trim()),
        ),
      ],
    );
  }
}

/// 저장하면 만들어질 회차 요약 — "총 8회 · 8/24 ~ 10/12". (#870)
///
/// 반복은 한 번에 여러 건을 만든다. 요일이나 종료일을 잘못 골랐을 때 되돌리는
/// 비용이 한 건씩 지우는 일이라, 만들기 전에 몇 회차인지 말해 준다.
class _RepeatPreview extends StatelessWidget {
  const _RepeatPreview({required this.dates});

  final List<DateTime> dates;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      key: const ValueKey<String>('repeat-preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.accentSurface,
        borderRadius: BorderRadius.all(AppRadius.md),
      ),
      child: Text(
        dates.isEmpty
            ? l.schedRepeatNeedsDays
            : l.schedRepeatPreview(
                dates.length,
                ymd(dates.first),
                ymd(dates.last),
              ),
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

/// 겹치는 회차 — 어느 주가 문제인지 짚어 준다. (#870)
///
/// 목록을 보여 주는 까닭은 "겹칩니다" 만으로는 트레이너가 무엇을 고쳐야 할지
/// 모르기 때문이다. 이 상태에서는 **아무 일정도 만들어지지 않았다.**
class _RepeatConflicts extends StatelessWidget {
  const _RepeatConflicts({required this.total, required this.conflicts});

  final int total;
  final List<ScheduleSession> conflicts;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      key: const ValueKey<String>('repeat-conflicts'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.schedRepeatConflictTitle(conflicts.length, total),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final conflict in conflicts.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                l.schedRepeatConflictRow(
                  conflict.date,
                  conflict.time,
                  conflict.clientName,
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.foreground,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.schedRepeatConflictHint,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.subtleForeground,
            ),
          ),
        ],
      ),
    );
  }
}

/// 취소 확인 — 주체를 고르고 (선택) 사유를 남긴다. (#871)
///
/// 주체에 기본값을 두지 않는다. 무엇이든 기본으로 저장되면 그 값이 사실인지 알
/// 수 없고, 나중에 "고객 취소가 몇 건이었나" 를 읽을 때 그대로 거짓이 된다.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.session});

  final ScheduleSession session;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final TextEditingController _reason = TextEditingController();
  String? _source;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final s = widget.session;
    return AlertDialog(
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
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(AppRadius.md),
            ),
            child: const Icon(
              Icons.event_busy_outlined,
              color: AppColors.warning,
              size: 19,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l.schedCancelTitle,
              style: const TextStyle(fontSize: 17),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l.schedCancelConfirm(s.time, s.clientName),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l.schedCancelSource,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.subtleForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final source in CancellationSource.all)
                  ChoiceChip(
                    key: ValueKey<String>('cancel-source-$source'),
                    label: Text(cancellationSourceLabel(l, source)),
                    selected: _source == source,
                    onSelected: (_) => setState(() => _source = source),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('cancel-reason-input'),
              controller: _reason,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: l.schedCancelReasonHint,
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        ActionButton(
          label: l.actionCancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ActionButton(
          key: const ValueKey<String>('session-cancel-confirm'),
          label: l.schedCancel,
          primary: true,
          tone: AppColors.warning,
          // 주체를 고르기 전에는 저장할 수 없다 — 기본값으로 채우면 그 값이
          // 사실인지 알 수 없다.
          onPressed: _source == null
              ? null
              : () => Navigator.of(
                  context,
                ).pop((source: _source!, reason: _reason.text.trim())),
        ),
      ],
    );
  }
}

/// Bottom sheet for booking or editing a session: client, type, time
/// (15-minute steps), and duration.
class _SessionSheet extends ConsumerStatefulWidget {
  const _SessionSheet({
    required this.clientNames,
    required this.date,
    required this.existing,
    this.inline = false,
    this.onSaved,
    this.onCancel,
    super.key,
  });

  final List<String> clientNames;

  /// The browsed calendar day new sessions are booked on (`YYYY-MM-DD`).
  final String date;

  final ScheduleSession? existing;
  final bool inline;
  final VoidCallback? onSaved;
  final VoidCallback? onCancel;

  @override
  ConsumerState<_SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends ConsumerState<_SessionSheet> {
  static const List<String> _types = SessionType.all;
  static const List<int> _durations = <int>[30, 45, 60, 90];

  late String _client;
  late String _type;
  late int _hour;
  late int _minute;
  late int _duration;
  bool _saving = false;
  late final TextEditingController _note;

  // ---- 반복(#870) — 새 일정에서만 쓴다. 수정은 그 회차 하나의 일이다. ----

  /// 반복 요일(ISO: 월=1 … 일=7). 비어 있으면 `반복 없음`이다.
  final Set<int> _repeatDays = <int>{};

  /// 종료 기준을 횟수로 잡는가(아니면 종료일). 둘을 동시에 두지 않는 까닭은
  /// 어느 쪽이 이겼는지 화면과 서버의 해석이 갈리기 때문이다.
  bool _endsByCount = true;
  int _repeatCount = 8;
  DateTime? _repeatUntil;

  /// 저장 시도가 찾아낸 겹치는 회차. 비어 있지 않으면 아무것도 만들어지지 않았다.
  List<ScheduleSession> _conflicts = const <ScheduleSession>[];

  // Option lists always CONTAIN the edited session's own values. Falling
  // back to a default instead would silently rewrite the session on an
  // otherwise no-op save — e.g. a 상담 booked for l.schedNewClient (not a
  // registered client) would be reassigned to the first client, and a
  // 50-minute session would become 60 (review PR 218).
  late List<String> _clientOptions;
  late List<String> _typeOptions;
  late List<int> _hourOptions;
  late List<int> _minuteOptions;
  late List<int> _durationOptions;

  /// [base] plus [current] when it isn't already offered.
  static List<T> _withCurrent<T>(List<T> base, T? current) {
    if (current == null || base.contains(current)) return List<T>.of(base);
    return <T>[...base, current];
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _note = TextEditingController(text: e?.note ?? '');

    _client = e?.clientName.isNotEmpty ?? false
        ? e!.clientName
        : widget.clientNames.first;
    _clientOptions = _withCurrent(widget.clientNames, _client);

    _type = e != null && e.type.isNotEmpty ? e.type : _types.first;
    _typeOptions = _withCurrent(_types, _type);

    final parts = e?.time.split(':');
    _hour = parts != null ? int.tryParse(parts[0]) ?? 10 : 10;
    _minute = parts != null && parts.length > 1
        ? int.tryParse(parts[1]) ?? 0
        : 0;
    _hourOptions = _withCurrent(<int>[for (var h = 6; h <= 22; h++) h], _hour)
      ..sort();
    _minuteOptions = _withCurrent(const <int>[0, 15, 30, 45], _minute)..sort();

    _duration = e?.durationMinutes ?? 60;
    _durationOptions = _withCurrent(_durations, _duration)..sort();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String get _time =>
      '${_hour.toString().padLeft(2, '0')}:'
      '${_minute.toString().padLeft(2, '0')}';

  /// 지금 화면이 나타내는 반복 규칙.
  WeeklyRecurrence get _rule => WeeklyRecurrence(
    weekdays: _repeatDays,
    count: _endsByCount ? _repeatCount : null,
    until: _endsByCount ? null : _repeatUntil,
  );

  /// 저장하면 만들어질 날짜들. 서버와 같은 규칙을 쓰므로(`seriesOccurrences`)
  /// 화면이 보여 준 회차 수와 실제로 만들어지는 수가 어긋나지 않는다.
  List<DateTime> get _occurrences =>
      seriesOccurrences(DateTime.parse(widget.date), _rule);

  /// 반복 등록 시도 하나의 멱등키. 재시도에 같은 값을 다시 보내야 회차가 두 벌
  /// 생기지 않는다 — 시트를 여는 동안 고정한다.
  late final String _requestId = newClientRequestId();

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final repo = ref.read(scheduleRepositoryProvider);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    try {
      final e = widget.existing;
      if (e == null && _repeatDays.isNotEmpty) {
        final start = DateTime.parse(widget.date);
        final rule = _rule;
        // 만들기 전에 충돌을 먼저 본다. 서버도 같은 검사로 409 를 주지만, 화면이
        // 겹친 회차를 짚어 주려면 목록이 필요하다(#870).
        final preview = await repo.previewRecurring(
          start: start,
          time: _time,
          rule: rule,
        );
        if (preview.conflicts.isNotEmpty) {
          if (mounted) {
            setState(() {
              _saving = false;
              _conflicts = preview.conflicts;
            });
          }
          return;
        }
        await repo.addRecurringSessions(
          start: start,
          time: _time,
          rule: rule,
          clientName: _client,
          type: _type,
          durationMinutes: _duration,
          note: _note.text.trim(),
          clientRequestId: _requestId,
        );
      } else if (e == null) {
        await repo.addSession(
          date: widget.date,
          clientName: _client,
          time: _time,
          type: _type,
          durationMinutes: _duration,
          note: _note.text.trim(),
        );
      } else {
        await repo.updateSession(
          e.id,
          clientName: _client,
          time: _time,
          type: _type,
          durationMinutes: _duration,
          note: _note.text.trim(),
        );
      }
    } on ScheduleSeriesConflictError catch (error) {
      // 서버가 막은 경우(미리보기 뒤에 다른 일정이 생겼을 때)도 같은 자리에
      // 같은 목록을 보여 준다.
      if (mounted) {
        setState(() {
          _saving = false;
          _conflicts = error.conflicts;
        });
      }
      return;
    } catch (_) {
      // Surface the failure and keep the sheet open so the input isn't
      // lost (review PR 218).
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l.schedSaveFailed)));
      return;
    }
    if (mounted) setState(() => _saving = false);
    if (!mounted) return;
    if (widget.inline) {
      widget.onSaved?.call();
    } else {
      navigator.pop();
    }
  }

  Future<void> _pickUntil() async {
    final start = DateTime.parse(widget.date);
    final picked = await showDatePicker(
      context: context,
      initialDate: _repeatUntil ?? start.add(const Duration(days: 56)),
      // 시작일 이전으로는 갈 수 없다 — 그러면 회차가 하나도 없다.
      firstDate: start,
      lastDate: start.add(const Duration(days: 7 * maxSeriesOccurrences)),
    );
    if (picked == null || !mounted) return;
    setState(
      () => _repeatUntil = DateTime(picked.year, picked.month, picked.day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      decoration: widget.inline
          ? BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.all(AppRadius.lg),
              border: Border.all(color: AppColors.borderStrong),
            )
          : null,
      child: Padding(
        // Keep the sheet above the keyboard/safe area.
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        // 반복 옵션이 붙으면서 시트가 낮은 창에서 넘쳤다(#870). 세로로 흐르게
        // 두어, 화면 높이가 얼마든 아래의 저장 버튼까지 닿을 수 있게 한다 —
        // 넘침은 이 저장소에서 실패로 잡는 회귀다(#849).
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.existing == null ? l.schedAddTitle : l.schedEditTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _sheetField(
                label: l.schedFieldClient,
                child: DropdownButton<String>(
                  value: _client,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: <DropdownMenuItem<String>>[
                    for (final name in _clientOptions)
                      DropdownMenuItem<String>(value: name, child: Text(name)),
                  ],
                  onChanged: (v) => setState(() => _client = v ?? _client),
                ),
              ),
              _sheetField(
                label: l.schedFieldType,
                child: DropdownButton<String>(
                  value: _type,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: <DropdownMenuItem<String>>[
                    for (final t in _typeOptions)
                      // 값은 계약값 그대로, 보이는 문구만 로케일에서 가져온다.
                      DropdownMenuItem<String>(
                        value: t,
                        child: Text(sessionTypeLabel(l, t)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
              ),
              _sheetField(
                label: l.schedFieldTime,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButton<int>(
                        value: _hour,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: <DropdownMenuItem<int>>[
                          for (final h in _hourOptions)
                            DropdownMenuItem<int>(
                              value: h,
                              child: Text(
                                l.schedHourLabel(h.toString().padLeft(2, '0')),
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _hour = v ?? _hour),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DropdownButton<int>(
                        value: _minute,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: <DropdownMenuItem<int>>[
                          for (final m in _minuteOptions)
                            DropdownMenuItem<int>(
                              value: m,
                              child: Text(
                                l.schedMinuteLabel(
                                  m.toString().padLeft(2, '0'),
                                ),
                              ),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _minute = v ?? _minute),
                      ),
                    ),
                  ],
                ),
              ),
              _sheetField(
                label: l.schedFieldDuration,
                child: DropdownButton<int>(
                  value: _duration,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: <DropdownMenuItem<int>>[
                    for (final d in _durationOptions)
                      DropdownMenuItem<int>(
                        value: d,
                        child: Text(l.minutesShort(d)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _duration = v ?? _duration),
                ),
              ),
              // 반복은 새 일정에만 있다(#870). 이미 잡힌 회차를 고치는 일은 그
              // 회차 하나의 일이고, 여기서 규칙을 다시 받으면 나머지 회차까지
              // 건드리는 것처럼 읽힌다.
              if (widget.existing == null) ...<Widget>[
                _sheetField(
                  label: l.schedRepeat,
                  stacked: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          ChoiceChip(
                            key: const ValueKey<String>('repeat-none'),
                            label: Text(l.schedRepeatNone),
                            selected: _repeatDays.isEmpty,
                            onSelected: (_) =>
                                setState(() => _repeatDays.clear()),
                          ),
                          ChoiceChip(
                            key: const ValueKey<String>('repeat-weekly'),
                            label: Text(l.schedRepeatWeekly),
                            selected: _repeatDays.isNotEmpty,
                            onSelected: (_) => setState(() {
                              if (_repeatDays.isEmpty) {
                                // 켜는 순간의 기본값은 **시작일의 요일**이다. 빈
                                // 상태로 켜면 "매주" 를 골랐는데 아무 회차도 없는
                                // 화면이 된다.
                                _repeatDays.add(
                                  DateTime.parse(widget.date).weekday,
                                );
                              }
                            }),
                          ),
                        ],
                      ),
                      if (_repeatDays.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l.schedRepeatDays,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.subtleForeground,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: <Widget>[
                            for (var day = 1; day <= 7; day++)
                              FilterChip(
                                key: ValueKey<String>('repeat-day-$day'),
                                label: Text(weekdayNames(l)[day - 1]),
                                selected: _repeatDays.contains(day),
                                onSelected: (on) => setState(() {
                                  if (on) {
                                    _repeatDays.add(day);
                                  } else if (_repeatDays.length > 1) {
                                    // 마지막 요일까지 끄면 `매주` 인데 회차가 없는
                                    // 상태가 된다 — 끄려면 `반복 없음` 을 고른다.
                                    _repeatDays.remove(day);
                                  }
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l.schedRepeatEnd,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.subtleForeground,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: <Widget>[
                            ChoiceChip(
                              key: const ValueKey<String>('repeat-end-count'),
                              label: Text(l.schedRepeatEndByCount),
                              selected: _endsByCount,
                              onSelected: (_) =>
                                  setState(() => _endsByCount = true),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            ChoiceChip(
                              key: const ValueKey<String>('repeat-end-date'),
                              label: Text(l.schedRepeatEndByDate),
                              selected: !_endsByCount,
                              onSelected: (_) => setState(() {
                                _endsByCount = false;
                                _repeatUntil ??= DateTime.parse(
                                  widget.date,
                                ).add(const Duration(days: 56));
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        if (_endsByCount)
                          DropdownButton<int>(
                            key: const ValueKey<String>('repeat-count'),
                            value: _repeatCount,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            items: <DropdownMenuItem<int>>[
                              for (final n in const <int>[4, 8, 12, 16, 24])
                                DropdownMenuItem<int>(
                                  value: n,
                                  child: Text(l.schedRepeatCount(n)),
                                ),
                            ],
                            onChanged: (v) => setState(
                              () => _repeatCount = v ?? _repeatCount,
                            ),
                          )
                        else
                          OutlinedButton.icon(
                            key: const ValueKey<String>('repeat-until'),
                            onPressed: _pickUntil,
                            icon: const Icon(Icons.event_outlined, size: 18),
                            label: Text(
                              _repeatUntil == null ? '-' : ymd(_repeatUntil!),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        // 저장 전에 회차를 보여 준다 — 잘못 고른 요일을 되돌리는
                        // 비용은 한 건씩 지우는 일이다.
                        _RepeatPreview(dates: _occurrences),
                        if (_conflicts.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          _RepeatConflicts(
                            total: _occurrences.length,
                            conflicts: _conflicts,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
              if (widget.existing == null)
                _sheetField(
                  label: l.schedNote,
                  stacked: true,
                  child: TextField(
                    key: const ValueKey<String>('schedule-trainer-note'),
                    controller: _note,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: l.schedNoteHint,
                      hintStyle: const TextStyle(
                        color: AppColors.mutedForeground,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  if (widget.inline) ...<Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : widget.onCancel,
                        child: Text(l.actionCancel),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Material(
                      color: AppColors.primary,
                      borderRadius: const BorderRadius.all(AppRadius.lg),
                      child: InkWell(
                        onTap: _saving ? null : _save,
                        borderRadius: const BorderRadius.all(AppRadius.lg),
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          child: Text(
                            widget.existing == null
                                ? l.schedAddAction
                                : l.schedSaveAction,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryForeground,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetField({
    required String label,
    required Widget child,
    bool stacked = false,
  }) {
    const labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.subtleForeground,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(label, style: labelStyle),
                const SizedBox(height: AppSpacing.xs),
                child,
              ],
            )
          : Row(
              children: <Widget>[
                SizedBox(width: 88, child: Text(label, style: labelStyle)),
                Expanded(child: child),
              ],
            ),
    );
  }
}

class _ProgramEditor extends ConsumerStatefulWidget {
  const _ProgramEditor({
    required this.session,
    required this.onSaved,
    required this.onCancel,
    super.key,
  });

  final ScheduleSession session;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  @override
  ConsumerState<_ProgramEditor> createState() => _ProgramEditorState();
}

class _ProgramEditorState extends ConsumerState<_ProgramEditor> {
  late final TextEditingController _note;
  late final List<_ProgramDraft> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: widget.session.note);
    _items = widget.session.program.map(_ProgramDraft.fromItem).toList();
  }

  @override
  void dispose() {
    _note.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    final AppLocalizations l = AppLocalizations.of(context);
    setState(() => _items.add(_ProgramDraft.empty(l)));
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index).dispose());
  }

  Future<void> _save() async {
    if (_saving) return;
    // await 전에 잡아 둔다 — 실패 경로가 await 뒤에도 있다.
    final AppLocalizations l = AppLocalizations.of(context);
    final program = <ProgramItem>[];
    for (final item in _items) {
      final name = item.name.text.trim();
      final sets = int.tryParse(item.sets.text.trim());
      if (name.isEmpty || sets == null || sets < 1 || sets > 100) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.progInvalid)));
        return;
      }
      program.add(
        ProgramItem(
          name: name,
          sets: sets,
          reps: item.reps.text.trim().isEmpty ? '-' : item.reps.text.trim(),
          weight: item.weight.text.trim().isEmpty
              ? '-'
              : item.weight.text.trim(),
        ),
      );
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .updateProgram(
            widget.session.id,
            program: program,
            note: _note.text.trim(),
          );
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.progSaveFailed)));
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.all(AppRadius.lg),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l.progEditTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < _items.length; index++) ...<Widget>[
            _ProgramDraftFields(
              index: index,
              draft: _items[index],
              onRemove: () => _removeItem(index),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          OutlinedButton.icon(
            onPressed: _saving ? null : _addItem,
            icon: const Icon(Icons.add, size: 16),
            label: Text(l.progAddExercise),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l.schedNote,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            key: const ValueKey<String>('program-trainer-note'),
            controller: _note,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: l.progNoteHint,
              hintStyle: const TextStyle(color: AppColors.mutedForeground),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : widget.onCancel,
                  child: Text(l.actionCancel),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const ValueKey<String>('save-program'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? l.progSaving : l.progSaveAction),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgramDraft {
  _ProgramDraft({
    required String name,
    required String sets,
    required String reps,
    required String weight,
  }) : name = TextEditingController(text: name),
       sets = TextEditingController(text: sets),
       reps = TextEditingController(text: reps),
       weight = TextEditingController(text: weight);

  factory _ProgramDraft.fromItem(ProgramItem item) => _ProgramDraft(
    name: item.name,
    sets: '${item.sets}',
    reps: item.reps,
    weight: item.weight == '-' ? '' : item.weight,
  );

  /// 새 운동 행의 기본값. reps 는 트레이너가 바로 고쳐 쓰는 입력값이라
  /// 트레이너의 로케일을 따른다.
  factory _ProgramDraft.empty(AppLocalizations l) =>
      _ProgramDraft(name: '', sets: '3', reps: l.progDefaultReps, weight: '');

  final TextEditingController name;
  final TextEditingController sets;
  final TextEditingController reps;
  final TextEditingController weight;

  void dispose() {
    name.dispose();
    sets.dispose();
    reps.dispose();
    weight.dispose();
  }
}

class _ProgramDraftFields extends StatelessWidget {
  const _ProgramDraftFields({
    required this.index,
    required this.draft,
    required this.onRemove,
  });

  final int index;
  final _ProgramDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: ValueKey<String>('program-name-$index'),
                  controller: draft.name,
                  decoration: InputDecoration(
                    labelText: l.progExerciseName,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: l.progDeleteExercise,
                onPressed: onRemove,
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.subtleForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: ValueKey<String>('program-sets-$index'),
                  controller: draft.sets,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.progSets,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  key: ValueKey<String>('program-reps-$index'),
                  controller: draft.reps,
                  decoration: InputDecoration(
                    labelText: l.progReps,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  key: ValueKey<String>('program-weight-$index'),
                  controller: draft.weight,
                  decoration: InputDecoration(
                    labelText: l.progWeight,
                    hintText: l.progOptional,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Week range label with the prev/next chevrons, above the week grid.
/// 상담 요청 인박스로 가는 헤더 액션. (#858, #882)
///
/// 처음에는 화면 폭 전체를 쓰는 남색 그라디언트 카드였다. 면적은 제일 큰데
/// 정작 몇 건 밀렸는지가 눈에 꽂히지 않았고 — 알림이 아니라 배너로 읽혔다 —
/// 타임라인에서 세로 공간까지 빼앗았다.
///
/// 지금은 아이콘 위에 **빨간 배지**를 얹은 헤더 액션이다. 알림을 알림으로
/// 읽히게 하는 가장 익숙한 표현이고, 헤더 액션 줄에서 가장 적은 폭을 쓴다.
/// 라벨을 함께 두면 영어 로케일·큰 글자 배율에서 줄 전체가 넘친다 — #849
/// 관문이 폭 1024·en·배율 1.3 에서 그것을 잡았다. 이름은 툴팁과 시맨틱스로
/// 남는다.
///
/// 빨강은 처리할 것이 있을 때만 뜬다: 0건이거나 아직 못 읽었으면([pending] 이
/// null) 배지 없이 조용한 버튼으로 남는다.
class _ConsultationInboxAction extends StatelessWidget {
  const _ConsultationInboxAction({required this.pending, required this.onTap});

  /// 대기 중인 상담 요청 수. 아직 불러오지 못했으면 null.
  final int? pending;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final int count = pending ?? 0;
    final bool waiting = count > 0;

    return Tooltip(
      message: l.consultTitle,
      child: Semantics(
        button: true,
        label: l.consultTitle,
        child: Material(
          color: Colors.transparent,
          borderRadius: const BorderRadius.all(AppRadius.md),
          child: InkWell(
            key: const Key('consult-inbox-entry'),
            onTap: onTap,
            borderRadius: const BorderRadius.all(AppRadius.md),
            child: Container(
              height: 36,
              width: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(AppRadius.md),
                border: Border.all(
                  color: waiting
                      ? AppColors.destructive.withValues(alpha: 0.45)
                      : AppColors.primary.withValues(alpha: 0.45),
                ),
              ),
              child: Badge(
                isLabelVisible: waiting,
                backgroundColor: AppColors.destructive,
                textColor: AppColors.destructiveForeground,
                label: Text('$count'),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 17,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 두 보기가 함께 쓰는 날짜 내비게이션 행 — `◀ 8월 14일 – 8월 20일 ▶` 과
/// 오른쪽 끝의 [trailing](`오늘`·`일|주`). (#882)
///
/// 일 보기와 주 보기가 같은 자리에 같은 것을 두어야 해서 한 곳에 모았다.
/// 오른쪽 끝은 아래 요일 칸 그리드의 오른쪽 끝과 맞는다 — 양쪽이 같은
/// [AppLayout.pagePadding] 안에 있기 때문이다.
class _DateNavBar extends StatelessWidget {
  const _DateNavBar({
    required this.start,
    required this.end,
    required this.onShift,
    required this.trailing,
  });

  /// 보이는 창의 첫날.
  final DateTime start;

  /// 보이는 창의 마지막 날.
  final DateTime end;

  /// -1 = 이전 주, +1 = 다음 주.
  final ValueChanged<int> onShift;

  /// 오른쪽 끝에 붙는 컨트롤.
  final Widget trailing;

  /// 날짜와 컨트롤이 한 줄에 함께 들어가는 최소 폭. 아래로는 컨트롤을 다음
  /// 줄로 내린다 — 한 줄을 고집하면 좁은 화면에서 그대로 넘친다.
  static const double _singleRowMinWidth = 440;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final nav = <Widget>[
      _ChevronButton(icon: Icons.chevron_left, onTap: () => onShift(-1)),
      const SizedBox(width: AppSpacing.sm),
      Text(
        l.dateRange(
          l.dateMonthDay(start.month, start.day),
          l.dateMonthDay(end.month, end.day),
        ),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.foreground,
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      _ChevronButton(icon: Icons.chevron_right, onTap: () => onShift(1)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _singleRowMinWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(children: nav),
              const SizedBox(height: AppSpacing.sm),
              // 줄이 갈려도 오른쪽 끝에 맞춘다는 규칙은 지킨다.
              Align(alignment: Alignment.centerRight, child: trailing),
            ],
          );
        }
        return Row(children: <Widget>[...nav, const Spacer(), trailing]);
      },
    );
  }
}

/// Seven day-columns of the week's sessions.
///
/// Answers the question the day timeline can't: where the free slots
/// are. Each column is a scroller of its own so a heavy Wednesday
/// doesn't stretch the whole grid.
class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    required this.start,
    required this.sessions,
    required this.selectedDay,
    required this.onPickDay,
    required this.onPickSession,
  });

  final DateTime start;
  final List<ScheduleSession> sessions;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onPickDay;
  final ValueChanged<ScheduleSession> onPickSession;

  @override
  Widget build(BuildContext context) {
    final today = ymd(nowKst());
    final byDate = <String, List<ScheduleSession>>{};
    for (final s in sessions) {
      if (s.isGap) continue;
      byDate.putIfAbsent(s.date, () => <ScheduleSession>[]).add(s);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.pagePadding,
        0,
        AppLayout.pagePadding,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < 7; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _DayColumn(
                day: start.add(Duration(days: i)),
                today: today,
                selected: ymd(start.add(Duration(days: i))) == ymd(selectedDay),
                sessions:
                    byDate[ymd(start.add(Duration(days: i)))] ??
                    const <ScheduleSession>[],
                onPickDay: onPickDay,
                onPickSession: onPickSession,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.today,
    required this.selected,
    required this.sessions,
    required this.onPickDay,
    required this.onPickSession,
  });

  final DateTime day;
  final String today;
  final bool selected;
  final List<ScheduleSession> sessions;
  final ValueChanged<DateTime> onPickDay;
  final ValueChanged<ScheduleSession> onPickSession;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final isToday = ymd(day) == today;
    final weekend = day.weekday >= DateTime.saturday;

    return Container(
      decoration: BoxDecoration(
        color: selected ? AppColors.accentSurface : AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.borderStrong,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: () => onPickDay(day),
            borderRadius: const BorderRadius.vertical(top: AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: <Widget>[
                  Text(
                    weekdayNames(l)[day.weekday - 1],
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: weekend
                          ? AppColors.subtleForeground
                          : AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isToday ? AppColors.primary : AppColors.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.borderStrong),
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Text(
                      l.schedEmptySlotShort,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.subtleForeground,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(5),
                    children: <Widget>[
                      for (final s in sessions)
                        _WeekChip(session: s, onTap: () => onPickSession(s)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _WeekChip extends ConsumerWidget {
  const _WeekChip({required this.session, required this.onTap});

  final ScheduleSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = session.isDone ? AppColors.success : AppColors.primary;
    final client = findClientIdentity(
      ref.watch(clientsProvider).valueOrNull ?? const <TrainerClient>[],
      clientId: session.clientId,
      clientName: session.clientName,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: const BorderRadius.all(AppRadius.xs),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(AppRadius.xs),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(AppRadius.xs),
              border: Border(left: BorderSide(color: color, width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  session.time,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (client == null)
                  Text(
                    session.clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  )
                else
                  ClientIdentity(
                    client: client,
                    nameStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                    demographicsStyle: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.subtleForeground,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 7-day picker centred on today, mirroring the user app's Diet tab
/// strip: chevrons shift the window a week at a time, the selected day
/// fills primary, today reads primary. A dot marks days with booked
/// sessions. Cells are flexible so the row never overflows.
/// 일 보기 상단의 날짜 스트립 — 날짜 내비게이션 행 + 7일 셀.
///
/// 주 보기의 [_WeekNav] 와 같은 구성이다: 왼쪽에 `◀ 날짜 범위 ▶`, 오른쪽 끝에
/// [trailing]. 요일 칸은 폭 전체를 나눠 쓴다 — 한때 460px 상한으로 좁혀 둔
/// 적이 있는데(#859), 넓은 콘솔에서 오른쪽이 통째로 비어 날짜를 좁힐 이유가
/// 없다는 것만 확인하고 되돌렸다(#882).
class _ScheduleWeekStrip extends StatelessWidget {
  const _ScheduleWeekStrip({
    required this.weekAnchor,
    required this.selectedDay,
    required this.bookedDates,
    required this.onSelect,
    required this.onShiftWeek,
    required this.trailing,
  });

  /// 날짜 내비게이션 행 오른쪽 끝에 붙는 컨트롤(`오늘`·`일|주`). 오른쪽 끝은
  /// 아래 요일 칸 그리드의 오른쪽 끝과 맞는다. (#882)
  final Widget trailing;

  /// Leftmost visible day (today − 3 by default).
  final DateTime weekAnchor;

  /// The day currently highlighted and shown on the timeline.
  final DateTime selectedDay;

  /// `YYYY-MM-DD` dates that have at least one booked session.
  final Set<String> bookedDates;

  /// Called when the user taps a day cell.
  final ValueChanged<DateTime> onSelect;

  /// `-1` = previous week, `+1` = next week.
  final ValueChanged<int> onShiftWeek;

  /// 요일 라벨은 로케일을 따르므로 const 로 둘 수 없다. (#501)
  static List<String> _weekdayShort(AppLocalizations l) => weekdayNames(l);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final today = nowKst();
    final week = <DateTime>[
      for (var i = 0; i < 7; i++) weekAnchor.add(Duration(days: i)),
    ];
    final end = weekAnchor.add(const Duration(days: 6));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 주 보기와 같은 행을 쓴다 — 두 보기가 날짜와 컨트롤을 같은 자리에
        // 둔다는 규칙이 한 위젯에 모여 있어 갈라질 수 없다.
        _DateNavBar(
          start: weekAnchor,
          end: end,
          onShift: onShiftWeek,
          trailing: trailing,
        ),
        const SizedBox(height: AppSpacing.xs),
        // Flexible cells share the row evenly — no fixed widths that
        // could overflow a narrow column.
        Row(
          children: <Widget>[
            for (final d in week)
              Expanded(
                child: _DayCell(
                  date: d,
                  label: _weekdayShort(l)[d.weekday - 1],
                  selected: _isSameDay(d, selectedDay),
                  isToday: _isSameDay(d, today),
                  hasDot: bookedDates.contains(ymd(d)),
                  onTap: () => onSelect(d),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 44,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Icon(icon, size: 20, color: AppColors.mutedForeground),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.label,
    required this.selected,
    required this.isToday,
    required this.hasDot,
    required this.onTap,
  });

  final DateTime date;
  final String label;
  final bool selected;
  final bool isToday;
  final bool hasDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dayColor = selected
        ? AppColors.primaryForeground
        : (isToday ? AppColors.primary : AppColors.foreground);
    final labelColor = selected
        ? AppColors.primaryForeground.withValues(alpha: 0.85)
        : (isToday ? AppColors.primary : AppColors.subtleForeground);

    return InkWell(
      key: ValueKey<String>('schedule-day-${ymd(date)}'),
      onTap: onTap,
      borderRadius: const BorderRadius.all(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: const BorderRadius.all(AppRadius.lg),
        ),
        child: Column(
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: dayColor,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasDot
                    ? (selected
                          ? AppColors.primaryForeground
                          : AppColors.primary)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One timeline row: the time gutter + a session card or a gap slot.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.session,
    required this.expanded,
    required this.onToggle,
    required this.onEditSchedule,
    required this.onEditProgram,
    required this.onDelete,
    required this.onChat,
    required this.onComplete,
    this.onCancel,
    this.onNoShow,
    required this.programDateLabel,
    required this.sendingProgram,
    required this.onSendProgram,
    required this.inlineEditor,
  });

  final ScheduleSession session;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onEditSchedule;
  final VoidCallback onEditProgram;
  final VoidCallback onDelete;
  final VoidCallback onChat;

  /// 예정 세션의 `취소`·`노쇼` 기록 처리. 대상이 아니면 null 이라 화면에 나오지
  /// 않는다 — 서버가 409 로 막을 동작을 아예 내놓지 않는다(#871).
  final VoidCallback? onCancel;
  final VoidCallback? onNoShow;
  final String programDateLabel;

  /// 이 세션의 프로그램 전송이 진행 중인가. (#822)
  final bool sendingProgram;

  /// 완료한 세션의 프로그램을 회원에게 보낸다.
  final VoidCallback onSendProgram;
  final Widget? inlineEditor;

  /// 예정 sessions only — flips to 완료 and logs the 운동기록.
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 48,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              session.time,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: session.isDone
                    ? AppColors.disabledForeground
                    : AppColors.foreground,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: session.isGap
              ? const _GapSlot()
              : _SessionCard(
                  key: ValueKey<String>('schedule-session-${session.id}'),
                  session: session,
                  expanded: expanded,
                  onToggle: onToggle,
                  onEditSchedule: onEditSchedule,
                  onEditProgram: onEditProgram,
                  onDelete: onDelete,
                  onCancel: onCancel,
                  onNoShow: onNoShow,
                  onChat: onChat,
                  onComplete: onComplete,
                  programDateLabel: programDateLabel,
                  sendingProgram: sendingProgram,
                  onSendProgram: onSendProgram,
                  inlineEditor: inlineEditor,
                ),
        ),
      ],
    );
  }
}

class _GapSlot extends StatelessWidget {
  const _GapSlot();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(AppRadius.lg),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Text(
        l.dashEmptySlot,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.subtleForeground,
        ),
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({
    super.key,
    required this.session,
    required this.expanded,
    required this.onToggle,
    required this.onEditSchedule,
    required this.onEditProgram,
    required this.onDelete,
    required this.onChat,
    required this.onComplete,
    this.onCancel,
    this.onNoShow,
    required this.programDateLabel,
    required this.sendingProgram,
    required this.onSendProgram,
    required this.inlineEditor,
  });

  final ScheduleSession session;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onEditSchedule;
  final VoidCallback onEditProgram;
  final VoidCallback onDelete;
  final VoidCallback onChat;

  /// 예정 세션의 `취소`·`노쇼` 기록 처리. 대상이 아니면 null 이라 화면에 나오지
  /// 않는다 — 서버가 409 로 막을 동작을 아예 내놓지 않는다(#871).
  final VoidCallback? onCancel;
  final VoidCallback? onNoShow;
  final String programDateLabel;
  final Widget? inlineEditor;

  /// 이 세션의 프로그램 전송이 진행 중인가. (#822)
  final bool sendingProgram;

  /// 완료한 세션의 프로그램을 회원에게 보낸다.
  final VoidCallback onSendProgram;

  /// 예정 sessions only — flips to 완료 and logs the 운동기록.
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final s = session;
    final client = findClientIdentity(
      ref.watch(clientsProvider).valueOrNull ?? const <TrainerClient>[],
      clientId: session.clientId,
      clientName: session.clientName,
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
        border: Border.all(
          color: s.isDone
              ? AppColors.border
              : AppColors.accent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: s.expandable ? onToggle : null,
            borderRadius: const BorderRadius.all(AppRadius.card),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  ClientAvatar(
                    // Guard: a non-gap row with an empty name must not
                    // crash `.characters.first`.
                    label: s.clientName.isEmpty
                        ? '?'
                        : s.clientName.characters.first,
                    size: 32,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (client == null)
                          Text(
                            s.clientName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.foreground,
                            ),
                          )
                        else ...<Widget>[
                          ClientIdentity(
                            client: client,
                            nameStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.foreground,
                            ),
                          ),
                          // 오늘 만날 회원이 무엇을 목표로 하는 사람인지는
                          // 세션 종류·소요 시간만큼 자리에서 필요하다(#898).
                          ClientGoalLabel(client: client),
                        ],
                        Text(
                          l.sessionTypeAndDuration(
                            sessionTypeLabel(l, s.type),
                            s.durationMinutes,
                          ),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.subtleForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(status: s.status),
                  if (s.expandable) ...<Widget>[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppColors.disabledForeground,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Divider(height: 1, color: AppColors.borderStrong),
                  const SizedBox(height: AppSpacing.md),
                  if (inlineEditor != null)
                    inlineEditor!
                  else ...<Widget>[
                    if (s.program.isNotEmpty)
                      for (var i = 0; i < s.program.length; i++) ...<Widget>[
                        _ProgramRow(index: i + 1, item: s.program[i]),
                        const SizedBox(height: AppSpacing.sm),
                      ]
                    else if (s.isUpcoming) ...<Widget>[
                      // 예정 session without a plan yet.
                      const _NoPlanBox(),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (s.note.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      _NoteBox(note: s.note),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    // 취소는 삭제와 달리 기록이라, 그 기록을 볼 수 있어야
                    // 만든 의미가 있다(#871).
                    if (s.isCancelled || s.isNoShow) ...<Widget>[
                      _EndedBox(session: s),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    _ManageRow(
                      onEditSchedule: onEditSchedule,
                      onEditProgram: onEditProgram,
                      onDelete: onDelete,
                      onCancel: onCancel,
                      onNoShow: onNoShow,
                      onChat: onChat,
                      onComplete: onComplete,
                    ),
                    if (s.isDone && s.program.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      _SendButton(
                        clientName: s.clientName,
                        dateLabel: programDateLabel,
                        sent: s.programSent,
                        sending: sendingProgram,
                        onSend: (s.programSent || sendingProgram)
                            ? null
                            : onSendProgram,
                      ),
                    ],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 취소·노쇼로 마무리된 세션의 기록 — 언제, 누가, (있으면) 왜. (#871)
///
/// 데모와 실 API 가 같은 값을 저장하므로 두 경로가 같은 줄을 보여 준다(#906).
class _EndedBox extends StatelessWidget {
  const _EndedBox({required this.session});

  final ScheduleSession session;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final DateTime? at = session.isCancelled
        ? session.cancelledAt
        : session.noShowAt;
    final String head = scheduleStatusLabel(l, session.status);
    final String detail =
        session.isCancelled && session.cancellationSource.isNotEmpty
        ? l.schedCancelledBy(
            cancellationSourceLabel(l, session.cancellationSource),
            at == null ? '' : ymd(at.toLocal()),
          )
        : (at == null ? '' : ymd(at.toLocal()));
    return Container(
      key: ValueKey<String>('session-ended-${session.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.all(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            detail.isEmpty ? head : '$head · $detail',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.warning,
            ),
          ),
          if (session.cancellationReason.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              session.cancellationReason,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.subtleForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    // 예정(파랑) · 완료(회색) · 취소/노쇼(빨강)로 갈라 둔다. 진행되지 않은
    // 세션이 완료와 같은 회색이면 "끝난 수업" 으로 읽히고, 예정과 같은 파랑이면
    // 아직 할 일로 읽힌다 — 둘 다 사실이 아니다(#871).
    final Color fg = switch (status) {
      ScheduleStatus.done => AppColors.disabledForeground,
      ScheduleStatus.cancelled || ScheduleStatus.noShow => AppColors.warning,
      _ => AppColors.accent,
    };
    final Color bg = switch (status) {
      ScheduleStatus.done => AppColors.inputBackground,
      ScheduleStatus.cancelled ||
      ScheduleStatus.noShow => AppColors.warning.withValues(alpha: 0.12),
      _ => AppColors.accentSurface,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(AppRadius.pill),
      ),
      child: Text(
        // 색은 계약값(`status`)으로 고르고, 글자는 로케일 문구로 그린다.
        scheduleStatusLabel(AppLocalizations.of(context), status),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _ProgramRow extends StatelessWidget {
  const _ProgramRow({required this.index, required this.item});

  final int index;
  final ProgramItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final detail = StringBuffer(l.progSetsByReps(item.sets, item.reps));
    if (item.weight != '-') detail.write(' · ${item.weight}');
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.all(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(AppRadius.sm),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppColors.secondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  detail.toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.subtleForeground,
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

/// Shown inside an expanded 예정 session that has no program yet.
class _NoPlanBox extends StatelessWidget {
  const _NoPlanBox();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.progEmpty,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l.progEmptyHint,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.subtleForeground,
            ),
          ),
        ],
      ),
    );
  }
}

/// 수정 · 삭제 · 채팅 바로가기 actions for a booked session.
class _ManageRow extends StatelessWidget {
  const _ManageRow({
    required this.onEditSchedule,
    required this.onEditProgram,
    required this.onDelete,
    required this.onChat,
    required this.onComplete,
    this.onCancel,
    this.onNoShow,
  });

  final VoidCallback onEditSchedule;
  final VoidCallback onEditProgram;
  final VoidCallback onDelete;
  final VoidCallback onChat;
  final VoidCallback? onComplete;

  /// 예정 세션만 — 진행되지 않은 약속을 `취소` 기록으로 남긴다(#871).
  final VoidCallback? onCancel;

  /// 예정이면서 지나간 세션만 — 회원이 오지 않았다는 기록.
  final VoidCallback? onNoShow;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        if (onComplete != null)
          _ActionChip(
            // Keyed: l.legendDone is also a status word elsewhere on this row,
            // so text alone no longer identifies the action.
            key: const ValueKey<String>('session-complete-chip'),
            icon: Icons.check,
            label: l.legendDone,
            color: AppColors.success,
            onTap: onComplete!,
          ),
        // 취소·노쇼는 완료 옆이다 — 셋 다 "이 약속이 어떻게 끝났나" 를 적는
        // 동작이고, 수정·삭제는 일정 자체를 손보는 다른 갈래다(#871).
        if (onCancel != null)
          _ActionChip(
            key: const ValueKey<String>('session-cancel-chip'),
            icon: Icons.event_busy_outlined,
            label: l.schedCancel,
            color: AppColors.warning,
            onTap: onCancel!,
          ),
        if (onNoShow != null)
          _ActionChip(
            key: const ValueKey<String>('session-no-show-chip'),
            icon: Icons.person_off_outlined,
            label: l.schedNoShow,
            color: AppColors.warning,
            onTap: onNoShow!,
          ),
        _ActionChip(
          label: l.schedEditTitle,
          color: AppColors.accent,
          onTap: onEditSchedule,
        ),
        _ActionChip(
          label: l.progEditTitle,
          color: AppColors.secondary,
          onTap: onEditProgram,
        ),
        _ActionChip(
          label: l.actionDelete,
          color: AppColors.destructive,
          onTap: onDelete,
        ),
        _ActionChip(
          key: const ValueKey<String>('session-chat-chip'),
          icon: Icons.chat_bubble_outline,
          label: l.clientChat,
          color: AppColors.accent,
          onTap: onChat,
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  /// Drawn ahead of [label]. A real icon rather than a '✓'/'💬' typed into
  /// the label: those depend on whatever fallback font the platform loads
  /// and render as 두부 boxes on Flutter web.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: const BorderRadius.all(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: icon == null
              ? text
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(icon, size: 12, color: color),
                    const SizedBox(width: 3),
                    text,
                  ],
                ),
        ),
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandOrange.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border(
          left: BorderSide(
            color: AppColors.brandOrange.withValues(alpha: 0.4),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.schedNote,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              // 메모지 표시다. 주의가 아니므로 빨강으로 올리지 않는다(#690).
              color: AppColors.brandOrange,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            note,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.clientName,
    required this.dateLabel,
    required this.sent,
    required this.sending,
    required this.onSend,
  });

  final String clientName;
  final String dateLabel;

  /// 이미 보낸 세션인가. 보낸 뒤에는 같은 자리에서 그 사실을 말한다 — 다시
  /// 누를 수 있게 두면 트레이너가 두 번 보냈는지 알 수 없다.
  final bool sent;

  /// 전송이 진행 중인가.
  final bool sending;

  /// 보내기. 이미 보냈거나 진행 중이면 null 이다.
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final Color foreground = sent
        ? AppColors.success
        : (sending ? AppColors.disabledForeground : AppColors.primary);
    return Material(
      color: AppColors.inputBackground,
      borderRadius: const BorderRadius.all(AppRadius.lg),
      child: InkWell(
        key: const ValueKey<String>('schedule-send-program'),
        onTap: onSend,
        borderRadius: const BorderRadius.all(AppRadius.lg),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (sending)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  sent ? Icons.check_circle_outline : Icons.send_outlined,
                  size: 15,
                  color: foreground,
                ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  sent
                      ? l.schedSentTo(clientName)
                      : l.schedSentProgramTo(clientName, dateLabel),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
