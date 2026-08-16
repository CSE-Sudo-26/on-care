import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/tokens/breakpoints.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/radius.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare/features/schedule/domain/entities/schedule_event.dart';
import 'package:oncare/features/schedule/presentation/controllers/schedule_controller.dart';
import 'package:oncare/features/schedule/presentation/schedule_category_color.dart';
import 'package:oncare/shared/widgets/modals/add_event_dialog.dart';

/// 하루치 일정을 펼쳐 수정·삭제할 수 있게 한다.
///
/// 캘린더 칸의 칩을 직접 누르게 하지 않는 이유: 칩은 9px 글씨에 칸 높이를 넘치면
/// 잘리는 자리라, 일정이 여럿인 날은 누를 수 없는 칩이 생긴다. 날짜를 눌러
/// 목록으로 펼치면 그 날의 모든 일정에 손이 닿는다.
///
/// 저장·삭제가 한 건이라도 일어났으면 `true` 로 닫힌다 — 부른 쪽이 달을 다시
/// 읽을지 판단한다.
Future<bool?> showDayEventsSheet(
  BuildContext context, {
  required DateTime date,
  required List<ScheduleEvent> events,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    // 캘린더 시트 위에 겹쳐 뜨므로 같은 규칙으로 루트에 올린다.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    barrierColor: Colors.black54,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppRadius.card),
    ),
    builder: (BuildContext ctx) => ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: AppBreakpoints.contentMaxWidth,
      ),
      child: _DayEventsBody(date: date, events: events),
    ),
  );
}

class _DayEventsBody extends ConsumerStatefulWidget {
  const _DayEventsBody({required this.date, required this.events});

  final DateTime date;
  final List<ScheduleEvent> events;

  @override
  ConsumerState<_DayEventsBody> createState() => _DayEventsBodyState();
}

class _DayEventsBodyState extends ConsumerState<_DayEventsBody> {
  /// 이 시트에서 무언가 바뀌었는지. 닫을 때 부른 쪽에 알려 준다.
  bool _changed = false;

  /// 삭제 요청이 오가는 일정 id. 두 번 눌러 두 번 지우는 것을 막는다.
  String? _deleting;

  /// 화면에 그리는 목록. 삭제·수정을 즉시 반영해야 시트를 닫았다 열지 않고도
  /// 결과가 보인다.
  late final List<ScheduleEvent> _events = <ScheduleEvent>[...widget.events]
    ..sort((ScheduleEvent a, ScheduleEvent b) => a.time.compareTo(b.time));

  void _markChanged() {
    _changed = true;
    // 달 그리드와 홈의 '오늘의 일정'이 같은 사실을 보도록 함께 무효화한다.
    ref
      ..invalidate(scheduleMonthProvider)
      ..invalidate(scheduleEventsProvider)
      ..invalidate(dashboardSummaryProvider);
  }

  Future<void> _edit(ScheduleEvent event) async {
    final bool? saved = await showEditEventDialog(context, event);
    if (saved != true || !mounted) return;
    _markChanged();
    // 고친 값을 서버에서 다시 읽는 대신, 이 시트는 닫히면서 부모가 새로 읽는다.
    // 여기서는 목록에서 빼 두어 옛 값이 남지 않게만 한다.
    setState(() => _events.removeWhere((ScheduleEvent e) => e.id == event.id));
    if (_events.isEmpty && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete(ScheduleEvent event) async {
    if (_deleting != null) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    // 되돌릴 수 없으므로 확인을 한 번 받는다.
    final bool ok =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('일정 삭제'),
            content: Text('‘${event.title}’ 일정을 삭제할까요? 되돌릴 수 없어요.'),
            actions: <Widget>[
              TextButton(
                key: const Key('deleteEventCancel'),
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                key: const Key('deleteEventConfirm'),
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                ),
                child: const Text('삭제'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;

    setState(() => _deleting = event.id);
    try {
      await ref.read(scheduleRepositoryProvider).deleteEvent(event.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = null);
      messenger.showSnackBar(
        const SnackBar(content: Text('일정 삭제에 실패했어요. 잠시 후 다시 시도해 주세요')),
      );
      return;
    }
    if (!mounted) return;
    _markChanged();
    setState(() {
      _deleting = null;
      _events.removeWhere((ScheduleEvent e) => e.id == event.id);
    });
    messenger.showSnackBar(const SnackBar(content: Text('일정을 삭제했어요')));
  }

  Future<void> _add() async {
    final bool? saved = await showAddEventDialog(context, initialDate: widget.date);
    if (saved != true || !mounted) return;
    _markChanged();
    // 새로 만든 일정은 이 목록이 모르므로 부모가 다시 읽게 하고 닫는다.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MaterialLocalizations m = MaterialLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    m.formatMediumDate(widget.date),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Material(
                  color: AppColors.accent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(_changed),
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(Icons.close, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  '이 날에는 일정이 없어요',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _events.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (BuildContext _, int i) => _EventRow(
                    event: _events[i],
                    deleting: _deleting == _events[i].id,
                    // 삭제가 오가는 동안에는 다른 줄도 잠근다.
                    disabled: _deleting != null,
                    onEdit: () => _edit(_events[i]),
                    onDelete: () => _delete(_events[i]),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const Key('dayEventsAdd'),
              onPressed: _deleting != null ? null : _add,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('이 날에 일정 추가'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.deleting,
    required this.disabled,
    required this.onEdit,
    required this.onDelete,
  });

  final ScheduleEvent event;
  final bool deleting;
  final bool disabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: scheduleCategoryColor(event.category),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  // 시간이 없는 일정도 있다 — 그 사실을 그대로 적는다.
                  <String>[
                    scheduleCategoryLabel(event.category),
                    if (event.time.isNotEmpty) event.time else '시간 미정',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (deleting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...<Widget>[
            IconButton(
              key: Key('editEvent-${event.id}'),
              tooltip: '수정',
              onPressed: disabled ? null : onEdit,
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
            IconButton(
              key: Key('deleteEvent-${event.id}'),
              tooltip: '삭제',
              onPressed: disabled ? null : onDelete,
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppColors.destructive,
            ),
          ],
        ],
      ),
    );
  }
}
