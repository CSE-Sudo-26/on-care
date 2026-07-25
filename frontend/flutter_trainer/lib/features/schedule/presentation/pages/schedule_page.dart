import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/shared/models/trainer_profile.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/content_frame.dart';

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
  final Set<String> _expanded = <String>{};
  final Set<String> _sent = <String>{};
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

  /// Opens the add/edit sheet. Passing [existing] prefills it and turns
  /// the save into an update.
  Future<void> _openSessionSheet({ScheduleSession? existing}) async {
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
        existing: existing,
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
      context.go('${AppRoutes.clients}?c=$id');
    } else {
      context.go(AppRoutes.clients);
      context.push(AppRoutes.clientDetail(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(todayScheduleProvider);
    // Keep the client stream live so the booking sheet and the chat
    // shortcut have data even when this tab is the first one opened.
    ref.watch(clientsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: schedule.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const Center(
            child: Text(
              '스케줄을 불러오지 못했어요',
              style: TextStyle(color: AppColors.mutedForeground),
            ),
          ),
          data: (sessions) => LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= AppLayout.splitBreakpoint;
              return wide
                  ? _buildWide(sessions)
                  : ContentFrame(child: _buildTimeline(sessions, true));
            },
          ),
        ),
      ),
    );
  }

  /// Wide viewports: the date/week overview docks left and the timeline
  /// gets its own scrollable column.
  Widget _buildWide(List<ScheduleSession> sessions) {
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
                children: <Widget>[
                  const _Header(),
                  const SizedBox(height: AppSpacing.lg),
                  _WeekStrip(hasScheduleToday: sessions.isNotEmpty),
                  const SizedBox(height: AppSpacing.lg),
                  _AddSessionButton(onTap: () => _openSessionSheet()),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: AppColors.borderStrong),
          Expanded(child: _buildTimeline(sessions, false)),
        ],
      ),
    );
  }

  /// The scrollable timeline; [withOverview] prepends the header, week
  /// strip, and add button (single-column layout).
  Widget _buildTimeline(List<ScheduleSession> sessions, bool withOverview) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        if (withOverview) ...<Widget>[
          const _Header(),
          const SizedBox(height: AppSpacing.lg),
          _WeekStrip(hasScheduleToday: sessions.isNotEmpty),
          const SizedBox(height: AppSpacing.lg),
          _AddSessionButton(onTap: () => _openSessionSheet()),
          const SizedBox(height: AppSpacing.lg),
        ],
        for (final s in sessions) ...<Widget>[
          _TimelineRow(
            session: s,
            expanded: _expanded.contains(s.id),
            sent: _sent.contains(s.id),
            flashing: _flash == s.id,
            onToggle: () => _toggle(s),
            onSend: () => _send(s),
            onEdit: () => _openSessionSheet(existing: s),
            onDelete: () => _confirmDelete(s),
            onChat: () => _openChat(s),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// "＋ 새 일정 추가" — opens the booking sheet.
class _AddSessionButton extends StatelessWidget {
  const _AddSessionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.card),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(AppRadius.card),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
          ),
          child: const Text(
            '＋ 새 일정 추가',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for booking or editing a session: client, type, time
/// (15-minute steps), and duration.
class _SessionSheet extends ConsumerStatefulWidget {
  const _SessionSheet({required this.clientNames, required this.existing});

  final List<String> clientNames;
  final ScheduleSession? existing;

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
          clientName: _client,
          time: _time,
          type: _type,
          durationMinutes: _duration,
        );
      } else {
        await repo.updateSession(
          e.id,
          clientName: _client,
          time: _time,
          type: _type,
          durationMinutes: _duration,
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
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          const SizedBox(height: AppSpacing.lg),
          Material(
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
        ],
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

/// "스케줄" title + "{오늘 날짜} · {헬스장}" subtitle.
class _Header extends StatelessWidget {
  const _Header();

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
    final subtitle =
        '${now.month}월 ${now.day}일 ${_weekdays[now.weekday - 1]}'
        ' · ${seedTrainerProfile.gym.name}';
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

/// 7-day strip **centered on today** (D-3 … D+3) with today highlighted
/// in the middle; a dot marks days that have schedule entries (seed
/// data covers today only).
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.hasScheduleToday});

  final bool hasScheduleToday;

  static const List<String> _days = <String>['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Row(
      children: <Widget>[
        for (var i = -3; i <= 3; i++)
          Expanded(
            child: Builder(
              builder: (context) {
                final date = today.add(Duration(days: i));
                return _DayCell(
                  label: _days[date.weekday - 1],
                  date: date,
                  isToday: i == 0,
                  hasDot: i == 0 && hasScheduleToday,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.label,
    required this.date,
    required this.isToday,
    required this.hasDot,
  });

  final String label;
  final DateTime date;
  final bool isToday;
  final bool hasDot;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isToday ? AppColors.primary : AppColors.subtleForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isToday ? AppColors.primary : Colors.transparent,
            borderRadius: const BorderRadius.all(AppRadius.md),
          ),
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isToday
                  ? AppColors.primaryForeground
                  : AppColors.mutedForeground,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasDot ? AppColors.primary : Colors.transparent,
          ),
        ),
      ],
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
    required this.onEdit,
    required this.onDelete,
    required this.onChat,
  });

  final ScheduleSession session;
  final bool expanded;
  final bool sent;
  final bool flashing;
  final VoidCallback onToggle;
  final VoidCallback onSend;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onChat;

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
                  onEdit: onEdit,
                  onDelete: onDelete,
                  onChat: onChat,
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
    required this.onEdit,
    required this.onDelete,
    required this.onChat,
  });

  final ScheduleSession session;
  final bool expanded;
  final bool sent;
  final bool flashing;
  final VoidCallback onToggle;
  final VoidCallback onSend;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
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
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onChat: onChat,
                  ),
                  if (s.isDone && s.program.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    _SendButton(
                      clientName: s.clientName,
                      sent: sent,
                      flashing: flashing,
                      onSend: onSend,
                    ),
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
    required this.onEdit,
    required this.onDelete,
    required this.onChat,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _ActionChip(label: '✎ 수정', color: AppColors.accent, onTap: onEdit),
        const SizedBox(width: AppSpacing.xs),
        _ActionChip(label: '삭제', color: AppColors.destructive, onTap: onDelete),
        const Spacer(),
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
  });

  final String clientName;
  final bool sent;
  final bool flashing;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final String label = flashing
        ? '✓ 고객 앱으로 전송 완료!'
        : sent
        ? '✓ $clientName님에게 전송됨'
        : '📤 $clientName님에게 오늘 PT 프로그램 전송';
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
