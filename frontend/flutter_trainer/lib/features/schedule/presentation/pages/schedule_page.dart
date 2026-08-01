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
import 'package:oncare_trainer/shared/models/trainer_profile.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/content_frame.dart';
import 'package:oncare_trainer/shared/widgets/outlined_action_button.dart';

/// 스케줄 tab — today's PT timeline. Every booked session expands:
/// 완료 shows the finished program and can be sent to the client (mock),
/// 예정 shows the plan (or a no-plan hint) with a chat shortcut. The
/// trainer can add, edit (15-minute steps), and delete sessions.
class SchedulePage extends ConsumerStatefulWidget {
  /// Creates the schedule tab.
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  /// The calendar day being browsed (defaults to today).
  DateTime _selectedDay = _dateOnly(DateTime.now());

  /// Leftmost day of the visible 7-day strip. Centred on today (D-3) so
  /// today sits in the middle; chevrons shift it a week at a time.
  DateTime _weekAnchor = _dateOnly(
    DateTime.now(),
  ).subtract(const Duration(days: 3));

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

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

  /// Jumps to the client's 채팅 — the split panel on wide viewports,
  /// the full-screen detail elsewhere. Falls back to the 고객 tab when
  /// the name can't be resolved (e.g. a renamed client).
  void _openChat(ScheduleSession s) {
    final clients = ref.read(clientsProvider).valueOrNull ?? const [];
    final match = clients.where((c) => c.name == s.clientName);
    if (match.isEmpty) {
      context.go(AppRoutes.clients);
      return;
    }
    final id = match.first.id;
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.splitBreakpoint;
    if (wide) {
      context.go(AppRoutes.clientsWithSelection(id));
    } else {
      context.go(AppRoutes.clients);
      context.push(AppRoutes.clientDetail(id));
    }
  }

  String get _selectedYmd => ymd(_selectedDay);

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(scheduleForDateProvider(_selectedYmd));
    // Keep the client stream live so the booking sheet and the chat
    // shortcut have data even when this tab is the first one opened.
    ref.watch(clientsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        // The date header, week strip and add button live OUTSIDE the
        // async `when()`: switching days spins up a new provider that
        // starts in `loading`, and blanking the whole page to a spinner
        // each tap made the strip flicker. Only the timeline reacts to
        // the async state now (review PR 245).
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= AppLayout.splitBreakpoint;
            return wide
                ? _buildWide(schedule)
                : ContentFrame(child: _buildTimeline(schedule, true));
          },
        ),
      ),
    );
  }

  /// Wide viewports: the date/week overview docks left and the timeline
  /// gets its own scrollable column.
  Widget _buildWide(AsyncValue<List<ScheduleSession>> schedule) {
    return ContentFrame(
      maxWidth: AppLayout.wideMaxWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: AppLayout.splitListWidth,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _overviewChildren(),
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: AppColors.borderStrong),
          Expanded(child: _buildTimeline(schedule, false)),
        ],
      ),
    );
  }

  /// Title + optional 오늘로 button, the week strip, and the add button.
  /// Shared by the wide left column and the single-column timeline.
  List<Widget> _overviewChildren() {
    final today = _dateOnly(DateTime.now());
    final defaultAnchor = today.subtract(const Duration(days: 3));
    // Offer 오늘로 whenever the view has drifted from its default
    // (either a non-today selection or a scrubbed window).
    final showToday = _selectedDay != today || _weekAnchor != defaultAnchor;
    return <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: _Header(date: _selectedDay)),
          if (showToday)
            _TodayButton(
              onTap: () => setState(() {
                _selectedDay = today;
                _weekAnchor = defaultAnchor;
              }),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      _ScheduleWeekStrip(
        weekAnchor: _weekAnchor,
        selectedDay: _selectedDay,
        bookedDates:
            ref.watch(bookedDatesProvider).valueOrNull ?? const <String>{},
        onSelect: (d) => setState(() => _selectedDay = d),
        onShiftWeek: (dir) => setState(
          () => _weekAnchor = _weekAnchor.add(Duration(days: 7 * dir)),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      OutlinedActionButton(
        label: '＋ 새 일정 추가',
        color: AppColors.accent,
        onTap: () => _openSessionSheet(),
      ),
    ];
  }

  /// The scrollable timeline; [withOverview] prepends the header, week
  /// strip, and add button (single-column layout). The overview is always
  /// rendered — only the session list swaps on the async [schedule] state,
  /// so switching days never blanks the strip (review PR 245).
  Widget _buildTimeline(
    AsyncValue<List<ScheduleSession>> schedule,
    bool withOverview,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        if (withOverview) ...<Widget>[
          ..._overviewChildren(),
          const SizedBox(height: AppSpacing.lg),
        ],
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
  // otherwise no-op save — e.g. a 상담 booked for '신규 회원' (not a
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

  Widget _sheetField({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.subtleForeground,
              ),
            ),
          ),
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
                  color: AppColors.destructive,
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

/// "스케줄" title + "{선택 날짜} · {헬스장}" subtitle.
class _Header extends StatelessWidget {
  const _Header({required this.date});

  /// The calendar day being browsed.
  final DateTime date;

  static const List<String> _weekdays = <String>[
    '월요일',
    '화요일',
    '수요일',
    '목요일',
    '금요일',
    '토요일',
    '일요일',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final subtitle =
        '${date.month}월 ${date.day}일 ${_weekdays[date.weekday - 1]}'
        '${isToday ? ' (오늘)' : ''} · ${seedTrainerProfile.gym.name}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '스케줄',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: AppColors.subtleForeground,
          ),
        ),
      ],
    );
  }
}

/// "오늘로" pill — jumps the strip and selection back to today. Shown
/// only when browsing another day (mirrors the user app's Diet tab).
class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentSurface,
      borderRadius: const BorderRadius.all(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.pill),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
          child: Text(
            '오늘로',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
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
                      child: Text(
                        '✓ 전송됨',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
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
            label: '✓ 완료',
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
        _ActionChip(label: '💬 채팅', color: AppColors.accent, onTap: onChat),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
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
        ? '✓ 고객 앱으로 전송 완료!'
        : sent
        ? '✓ $clientName님에게 전송됨'
        : '📤 $clientName님에게 $dateLabel PT 프로그램 전송';
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
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: sent ? AppColors.success : AppColors.primaryForeground,
            ),
          ),
        ),
      ),
    );
  }
}
