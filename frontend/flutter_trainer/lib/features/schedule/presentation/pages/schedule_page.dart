import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
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

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Parses a `YYYY-MM-DD` route parameter, falling back to today. A
  /// malformed date in the URL should land the trainer on today rather
  /// than an error page.
  static DateTime _resolveDay(String? raw) {
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    return _dateOnly(parsed ?? DateTime.now());
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
  final Set<String> _sent = <String>{};
  String? _editingScheduleId;
  String? _editingProgramId;
  // 단일 플래시: 연속 전송 시 직전 카드의 확인 플래시는 새 플래시로
  // 대체된다(의도된 단순화 — 전송 결과는 '전송됨' 칩으로 남는다).
  String? _flash;
  Timer? _flashTimer;

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  void _toggle(ScheduleSession s) {
    if (!s.expandable) return;
    setState(() {
      _expanded.contains(s.id) ? _expanded.remove(s.id) : _expanded.add(s.id);
    });
  }

  void _send(ScheduleSession s) {
    if (_sent.contains(s.id)) return;
    setState(() {
      _sent.add(s.id);
      _flash = s.id;
    });
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _flash = null);
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

  Future<void> _confirmDelete(ScheduleSession s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('일정 삭제', style: TextStyle(fontSize: 16)),
        content: Text(
          '${s.time} ${s.clientName}님 세션을 삭제할까요?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '삭제',
              style: TextStyle(color: AppColors.destructive),
            ),
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
      messenger.showSnackBar(
        const SnackBar(content: Text('일정 삭제에 실패했어요. 다시 시도해 주세요')),
      );
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
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .completeSession(s.id, note: note);
    } catch (_) {
      // A DB or programJson-decode failure must not escape to the UI —
      // the session stays 예정 and the trainer is told (review PR 237).
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('완료 처리에 실패했어요. 다시 시도해 주세요')),
      );
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
    context.go(AppRoutes.clientDetail(match.first.id, section: 'chat'));
  }

  String get _selectedYmd => ymd(_selectedDay);

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(scheduleForDateProvider(_selectedYmd));
    // Keep the client stream live so the booking sheet and the chat
    // shortcut have data even when this tab is the first one opened.
    ref.watch(clientsProvider);
    final today = _dateOnly(DateTime.now());
    final defaultAnchor = today.subtract(const Duration(days: 3));
    final showToday = _selectedDay != today || _weekAnchor != defaultAnchor;

    return PageScaffold(
      title: '스케줄',
      subtitle: koreanDateLabel(_selectedDay),
      actions: <Widget>[
        if (showToday)
          ActionButton(
            label: '오늘',
            icon: Icons.today_outlined,
            onPressed: () {
              setState(() => _weekAnchor = defaultAnchor);
              _selectDay(today);
            },
          ),
        SegmentedSwitch(
          labels: const <String>['일', '주'],
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
        ActionButton(
          label: '새 일정',
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
      child: _weekView ? _buildWeekGrid() : _buildDayView(schedule),
    );
  }

  /// 주 — a seven-column grid of the week's sessions. One range query
  /// backs it, so switching weeks doesn't fan out into seven streams.
  Widget _buildWeekGrid() {
    final start = _dateOnly(_weekAnchor);
    final end = start.add(const Duration(days: 6));
    final range = (from: ymd(start), to: ymd(end));
    final week = ref.watch(scheduleRangeProvider(range));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _WeekNav(
          start: start,
          end: end,
          onShift: (dir) => setState(
            () => _weekAnchor = _weekAnchor.add(Duration(days: 7 * dir)),
          ),
        ),
        Expanded(
          child: week.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const Center(
              child: Text(
                '스케줄을 불러오지 못했어요',
                style: TextStyle(color: AppColors.mutedForeground),
              ),
            ),
            data: (sessions) => _WeekGrid(
              start: start,
              sessions: sessions,
              selectedDay: _selectedDay,
              onPickDay: (d) => _selectDay(d, toTimeline: true),
              onPickSession: (s) {
                final day = DateTime.tryParse(s.date);
                if (day != null) _selectDay(day, toTimeline: true);
              },
            ),
          ),
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
            AppSpacing.md,
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
          ),
        ),
        Expanded(child: _buildTimeline(schedule)),
      ],
    );
  }

  /// The scrollable timeline for the selected day.
  Widget _buildTimeline(AsyncValue<List<ScheduleSession>> schedule) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.pagePadding,
        AppSpacing.sm,
        AppLayout.pagePadding,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        ...schedule.when(
          loading: () => const <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (e, _) => const <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(
                child: Text(
                  '스케줄을 불러오지 못했어요',
                  style: TextStyle(color: AppColors.mutedForeground),
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
    // 완료 is offered only for 예정 sessions that aren't dated in the
    // future — you can't complete a class that hasn't happened yet. The
    // repository enforces the same rule (review PR 245).
    final isFuture = _selectedDay.isAfter(_dateOnly(DateTime.now()));
    final clients = ref.read(clientsProvider).valueOrNull ?? const [];
    final today = _dateOnly(DateTime.now());
    final dateLabel = _selectedDay == today
        ? '오늘'
        : '${_selectedDay.month}월 ${_selectedDay.day}일';
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
          child: const Text(
            '이 날짜에는 일정이 없어요.\n아래에서 새 일정을 추가해 보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
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
          sent: _sent.contains(s.id),
          flashing: _flash == s.id,
          onToggle: () => _toggle(s),
          onSend: () => _send(s),
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
          programDateLabel: dateLabel,
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
    final s = widget.session;
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('세션 완료 처리', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${s.time} ${s.clientName}님 세션을 완료로 표시하고 '
              '운동기록에 남길게요.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _memo,
              decoration: const InputDecoration(
                hintText: '트레이너 메모 (선택)',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_memo.text.trim()),
          child: const Text('완료 처리'),
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
  static const List<String> _types = <String>['1:1 PT', '상담'];
  static const List<int> _durations = <int>[30, 45, 60, 90];

  late String _client;
  late String _type;
  late int _hour;
  late int _minute;
  late int _duration;
  bool _saving = false;
  late final TextEditingController _note;

  // Option lists always CONTAIN the edited session's own values. Falling
  // back to a default instead would silently rewrite the session on an
  // otherwise no-op save — e.g. a 상담 booked for '신규 고객' (not a
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

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final repo = ref.read(scheduleRepositoryProvider);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final e = widget.existing;
      if (e == null) {
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
    } catch (_) {
      // Surface the failure and keep the sheet open so the input isn't
      // lost (review PR 218).
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('일정 저장에 실패했어요. 다시 시도해 주세요')),
      );
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

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.existing == null ? '새 일정 추가' : '일정 수정',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _sheetField(
              label: '고객',
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
              label: '유형',
              child: DropdownButton<String>(
                value: _type,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: <DropdownMenuItem<String>>[
                  for (final t in _typeOptions)
                    DropdownMenuItem<String>(value: t, child: Text(t)),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
            ),
            _sheetField(
              label: '시간',
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
                            child: Text('${h.toString().padLeft(2, '0')}시'),
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
                            child: Text('${m.toString().padLeft(2, '0')}분'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _minute = v ?? _minute),
                    ),
                  ),
                ],
              ),
            ),
            _sheetField(
              label: '소요 시간',
              child: DropdownButton<int>(
                value: _duration,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: <DropdownMenuItem<int>>[
                  for (final d in _durationOptions)
                    DropdownMenuItem<int>(value: d, child: Text('$d분')),
                ],
                onChanged: (v) => setState(() => _duration = v ?? _duration),
              ),
            ),
            if (widget.existing == null)
              _sheetField(
                label: '트레이너 메모',
                stacked: true,
                child: TextField(
                  key: const ValueKey<String>('schedule-trainer-note'),
                  controller: _note,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: '수업 준비사항이나 고객 특이사항을 입력하세요',
                    hintStyle: TextStyle(color: AppColors.mutedForeground),
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
                      child: const Text('취소'),
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
                          widget.existing == null ? '추가하기' : '저장하기',
                          style: const TextStyle(
                            fontSize: 13,
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
    );
  }

  Widget _sheetField({
    required String label,
    required Widget child,
    bool stacked = false,
  }) {
    const labelStyle = TextStyle(
      fontSize: 12,
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
    setState(() => _items.add(_ProgramDraft.empty()));
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index).dispose());
  }

  Future<void> _save() async {
    if (_saving) return;
    final program = <ProgramItem>[];
    for (final item in _items) {
      final name = item.name.text.trim();
      final sets = int.tryParse(item.sets.text.trim());
      if (name.isEmpty || sets == null || sets < 1 || sets > 100) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('운동 이름과 세트 수를 확인해 주세요')));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로그램 저장에 실패했어요. 다시 시도해 주세요')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
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
          const Text(
            '프로그램 수정',
            style: TextStyle(
              fontSize: 15,
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
            label: const Text('운동 추가'),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            '트레이너 메모',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            key: const ValueKey<String>('program-trainer-note'),
            controller: _note,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '프로그램 진행 시 참고할 내용을 입력하세요',
              hintStyle: TextStyle(color: AppColors.mutedForeground),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : widget.onCancel,
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const ValueKey<String>('save-program'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '저장 중...' : '프로그램 저장'),
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

  factory _ProgramDraft.empty() =>
      _ProgramDraft(name: '', sets: '3', reps: '10회', weight: '');

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
                  decoration: const InputDecoration(
                    labelText: '운동 이름',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: '운동 삭제',
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
                  decoration: const InputDecoration(
                    labelText: '세트',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  key: ValueKey<String>('program-reps-$index'),
                  controller: draft.reps,
                  decoration: const InputDecoration(
                    labelText: '횟수/시간',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  key: ValueKey<String>('program-weight-$index'),
                  controller: draft.weight,
                  decoration: const InputDecoration(
                    labelText: '중량',
                    hintText: '선택',
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
class _WeekNav extends StatelessWidget {
  const _WeekNav({
    required this.start,
    required this.end,
    required this.onShift,
  });

  final DateTime start;
  final DateTime end;

  /// -1 = previous week, +1 = next.
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.pagePadding,
        AppSpacing.md,
        AppLayout.pagePadding,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          _ChevronButton(icon: Icons.chevron_left, onTap: () => onShift(-1)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${start.month}월 ${start.day}일 – ${end.month}월 ${end.day}일',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _ChevronButton(icon: Icons.chevron_right, onTap: () => onShift(1)),
        ],
      ),
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
    final today = ymd(DateTime.now());
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
                    koreanWeekdays[day.weekday - 1],
                    style: TextStyle(
                      fontSize: 10.5,
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
                      fontSize: 15,
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
                      '비어 있음',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.disabledForeground,
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

class _WeekChip extends StatelessWidget {
  const _WeekChip({required this.session, required this.onTap});

  final ScheduleSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = session.isDone ? AppColors.success : AppColors.primary;
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
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  session.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
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
class _ScheduleWeekStrip extends StatelessWidget {
  const _ScheduleWeekStrip({
    required this.weekAnchor,
    required this.selectedDay,
    required this.bookedDates,
    required this.onSelect,
    required this.onShiftWeek,
  });

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

  static const List<String> _weekdayShort = <String>[
    '월',
    '화',
    '수',
    '목',
    '금',
    '토',
    '일',
  ];

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final week = <DateTime>[
      for (var i = 0; i < 7; i++) weekAnchor.add(Duration(days: i)),
    ];

    return Row(
      children: <Widget>[
        _ChevronButton(icon: Icons.chevron_left, onTap: () => onShiftWeek(-1)),
        // Flexible cells share the middle space evenly — no fixed widths
        // that could overflow a narrow column.
        for (final d in week)
          Expanded(
            child: _DayCell(
              date: d,
              label: _weekdayShort[d.weekday - 1],
              selected: _isSameDay(d, selectedDay),
              isToday: _isSameDay(d, today),
              hasDot: bookedDates.contains(ymd(d)),
              onTap: () => onSelect(d),
            ),
          ),
        _ChevronButton(icon: Icons.chevron_right, onTap: () => onShiftWeek(1)),
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
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 12.5,
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
    required this.sent,
    required this.flashing,
    required this.onToggle,
    required this.onSend,
    required this.onEditSchedule,
    required this.onEditProgram,
    required this.onDelete,
    required this.onChat,
    required this.onComplete,
    required this.programDateLabel,
    required this.inlineEditor,
  });

  final ScheduleSession session;
  final bool expanded;
  final bool sent;
  final bool flashing;
  final VoidCallback onToggle;
  final VoidCallback onSend;
  final VoidCallback onEditSchedule;
  final VoidCallback onEditProgram;
  final VoidCallback onDelete;
  final VoidCallback onChat;
  final String programDateLabel;
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
                fontSize: 11,
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
                  session: session,
                  expanded: expanded,
                  sent: sent,
                  flashing: flashing,
                  onToggle: onToggle,
                  onSend: onSend,
                  onEditSchedule: onEditSchedule,
                  onEditProgram: onEditProgram,
                  onDelete: onDelete,
                  onChat: onChat,
                  onComplete: onComplete,
                  programDateLabel: programDateLabel,
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
    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(AppRadius.lg),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: const Text(
        '빈 시간',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.disabledForeground,
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.expanded,
    required this.sent,
    required this.flashing,
    required this.onToggle,
    required this.onSend,
    required this.onEditSchedule,
    required this.onEditProgram,
    required this.onDelete,
    required this.onChat,
    required this.onComplete,
    required this.programDateLabel,
    required this.inlineEditor,
  });

  final ScheduleSession session;
  final bool expanded;
  final bool sent;
  final bool flashing;
  final VoidCallback onToggle;
  final VoidCallback onSend;
  final VoidCallback onEditSchedule;
  final VoidCallback onEditProgram;
  final VoidCallback onDelete;
  final VoidCallback onChat;
  final String programDateLabel;
  final Widget? inlineEditor;

  /// 예정 sessions only — flips to 완료 and logs the 운동기록.
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
        border: Border.all(
          color: sent
              ? AppColors.success.withValues(alpha: 0.4)
              : s.isDone
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
                        Text(
                          s.clientName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                          ),
                        ),
                        Text(
                          '${s.type} · ${s.durationMinutes}분',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.subtleForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (sent)
                    const Padding(
                      padding: EdgeInsets.only(right: AppSpacing.sm),
                      child: _SentBadge(),
                    ),
                  _StatusChip(status: s.status, sent: sent),
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
                    _ManageRow(
                      onEditSchedule: onEditSchedule,
                      onEditProgram: onEditProgram,
                      onDelete: onDelete,
                      onChat: onChat,
                      onComplete: onComplete,
                    ),
                    if (s.isDone && s.program.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      _SendButton(
                        clientName: s.clientName,
                        sent: sent,
                        flashing: flashing,
                        onSend: onSend,
                        dateLabel: programDateLabel,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.sent});

  final String status;
  final bool sent;

  @override
  Widget build(BuildContext context) {
    final done = status == '완료';
    final Color fg = done
        ? (sent ? AppColors.success : AppColors.disabledForeground)
        : AppColors.accent;
    final Color bg = done
        ? (sent
              ? AppColors.success.withValues(alpha: 0.1)
              : AppColors.inputBackground)
        : AppColors.accentSurface;
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
        status,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: fg),
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
    final detail = StringBuffer('${item.sets}세트 × ${item.reps}');
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
                fontSize: 9.5,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  detail.toString(),
                  style: const TextStyle(
                    fontSize: 10,
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '아직 계획된 프로그램이 없어요',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedForeground,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'AI 루틴 탭에서 프로그램을 만들어 보내거나, 채팅으로 미리 조율해 보세요.',
            style: TextStyle(
              fontSize: 10.5,
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
  });

  final VoidCallback onEditSchedule;
  final VoidCallback onEditProgram;
  final VoidCallback onDelete;
  final VoidCallback onChat;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        if (onComplete != null)
          _ActionChip(
            // Keyed: '완료' is also a status word elsewhere on this row,
            // so text alone no longer identifies the action.
            key: const ValueKey<String>('session-complete-chip'),
            icon: Icons.check,
            label: '완료',
            color: AppColors.success,
            onTap: onComplete!,
          ),
        _ActionChip(
          label: '일정 수정',
          color: AppColors.accent,
          onTap: onEditSchedule,
        ),
        _ActionChip(
          label: '프로그램 수정',
          color: AppColors.secondary,
          onTap: onEditProgram,
        ),
        _ActionChip(label: '삭제', color: AppColors.destructive, onTap: onDelete),
        _ActionChip(
          key: const ValueKey<String>('session-chat-chip'),
          icon: Icons.chat_bubble_outline,
          label: '채팅',
          color: AppColors.accent,
          onTap: onChat,
        ),
      ],
    );
  }
}

/// "전송됨" marker on a session row.
class _SentBadge extends StatelessWidget {
  const _SentBadge();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.check, size: 11, color: AppColors.success),
        SizedBox(width: 2),
        Text(
          '전송됨',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: AppColors.success,
          ),
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
        fontSize: 10.5,
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border(
          left: BorderSide(
            color: AppColors.warning.withValues(alpha: 0.4),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '트레이너 메모',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            note,
            style: const TextStyle(
              fontSize: 11,
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
    required this.sent,
    required this.flashing,
    required this.onSend,
    required this.dateLabel,
  });

  final String clientName;
  final bool sent;
  final bool flashing;
  final VoidCallback onSend;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final String label = flashing
        ? '고객 앱으로 전송 완료!'
        : sent
        ? '$clientName님에게 전송됨'
        : '$clientName님에게 $dateLabel PT 프로그램 전송';
    final fg = sent ? AppColors.success : AppColors.primaryForeground;
    return Material(
      color: sent
          ? AppColors.success.withValues(alpha: 0.1)
          : AppColors.primary,
      borderRadius: const BorderRadius.all(AppRadius.lg),
      child: InkWell(
        onTap: sent ? null : onSend,
        borderRadius: const BorderRadius.all(AppRadius.lg),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                sent || flashing ? Icons.check_circle : Icons.send_outlined,
                size: 15,
                color: fg,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fg,
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
