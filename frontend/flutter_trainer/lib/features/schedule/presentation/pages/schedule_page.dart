import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/shared/models/trainer_profile.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/content_frame.dart';

/// 스케줄 tab — today's PT timeline. Completed sessions expand to show
/// the program + trainer note and can be sent to the client (mock:
/// in-memory sent state with a confirmation flash).
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

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(todayScheduleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ContentFrame(
          child: schedule.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const Center(
              child: Text(
                '스케줄을 불러오지 못했어요',
                style: TextStyle(color: AppColors.mutedForeground),
              ),
            ),
            data: (sessions) => ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              children: <Widget>[
                const _Header(),
                const SizedBox(height: AppSpacing.lg),
                _WeekStrip(hasScheduleToday: sessions.isNotEmpty),
                const SizedBox(height: AppSpacing.lg),
                for (final s in sessions) ...<Widget>[
                  _TimelineRow(
                    session: s,
                    expanded: _expanded.contains(s.id),
                    sent: _sent.contains(s.id),
                    flashing: _flash == s.id,
                    onToggle: () => _toggle(s),
                    onSend: () => _send(s),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ),
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

/// Mon–Sun strip for the current week with today highlighted; a dot
/// marks days that have schedule entries (seed data covers today only).
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.hasScheduleToday});

  final bool hasScheduleToday;

  static const List<String> _days = <String>['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));

    return Row(
      children: <Widget>[
        for (var i = 0; i < 7; i++)
          Expanded(
            child: _DayCell(
              label: _days[i],
              date: monday.add(Duration(days: i)),
              isToday: i == now.weekday - 1,
              hasDot: i == now.weekday - 1 && hasScheduleToday,
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
  });

  final ScheduleSession session;
  final bool expanded;
  final bool sent;
  final bool flashing;
  final VoidCallback onToggle;
  final VoidCallback onSend;

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
  });

  final ScheduleSession session;
  final bool expanded;
  final bool sent;
  final bool flashing;
  final VoidCallback onToggle;
  final VoidCallback onSend;

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
          if (expanded && s.program.isNotEmpty)
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
                  for (var i = 0; i < s.program.length; i++) ...<Widget>[
                    _ProgramRow(index: i + 1, item: s.program[i]),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (s.note.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    _NoteBox(note: s.note),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _SendButton(
                    clientName: s.clientName,
                    sent: sent,
                    flashing: flashing,
                    onSend: onSend,
                  ),
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
