import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/core/utils/portrait_date_picker.dart';
import 'package:oncare_trainer/core/utils/request_id.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/entities/follow_up_task.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/follow_up_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/services/follow_up_task_repository.dart';
import 'package:oncare_trainer/shared/widgets/app_toast.dart';

/// [clientId] 의 후속 관리 목록을 연다.
///
/// 대시보드의 후속 관리 카드와 같은 데이터를 읽는다 — 여기서 남긴 할 일은
/// 예정일이 되면 대시보드에 그대로 뜬다.
Future<void> showClientFollowUpDialog(
  BuildContext context, {
  required String clientId,
  required String clientName,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      ClientFollowUpDialog(clientId: clientId, clientName: clientName),
);

/// 한 고객의 후속 관리 할 일을 남기고 닫는 자리. (#869)
class ClientFollowUpDialog extends ConsumerStatefulWidget {
  const ClientFollowUpDialog({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  final String clientId;
  final String clientName;

  @override
  ConsumerState<ClientFollowUpDialog> createState() =>
      _ClientFollowUpDialogState();
}

class _ClientFollowUpDialogState extends ConsumerState<ClientFollowUpDialog> {
  /// 백엔드 `TrainerFollowUpTaskCreateRequest.title` 상한과 같은 값 —
  /// 넘치는 입력이 422 를 받으러 왕복하지 않고 여기서 걸린다.
  static const int _maxLength = 200;

  /// 예정일을 얼마나 앞까지 고를 수 있는가. PT 운영에서 후속 확인은 몇 주 안의
  /// 일이라, 달력을 몇 년씩 열어 두면 잘못 고른 해가 조용히 저장된다.
  static const Duration _maxAhead = Duration(days: 365);

  final TextEditingController _draft = TextEditingController();

  late DateTime _dueDate = todayKst();
  FollowUpContext _context = FollowUpContext.general;

  /// 저장 시도 하나의 멱등키. **재시도에는 같은 값을 다시 보내야** 하므로
  /// 성공한 뒤에만 새로 만든다 — 매 요청 새로 만들면 아무것도 막지 못한다.
  String _requestId = newClientRequestId();

  /// 쓰기가 진행 중. 모든 동작이 이 값을 먼저 보므로 두 번 눌러도 같은 할 일이
  /// 두 번 생기지 않고, 목록이 두 방향에서 동시에 바뀌지 않는다.
  bool _busy = false;

  /// 완료 처리 중인 할 일 id.
  String? _completing;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _toast(String message) {
    showAppToast(context, message, kind: AppToastKind.error);
  }

  void _reload() {
    ref
      ..invalidate(clientFollowUpsProvider(widget.clientId))
      // 오늘 예정으로 남겼거나 오늘 것을 닫았다면 대시보드의 줄 수가 바뀐다.
      ..invalidate(dueFollowUpsProvider);
  }

  Future<void> _add() async {
    final title = _draft.text.trim();
    if (title.isEmpty || _busy) return;
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(followUpTaskRepositoryProvider)
          .create(
            widget.clientId,
            title: title,
            dueDate: _dueDate,
            context: _context,
            clientRequestId: _requestId,
            memberName: widget.clientName,
          );
      _draft.clear();
      // 저장이 끝난 다음 행동은 새 할 일이다 — 여기서 키를 갈아 끼운다.
      _requestId = newClientRequestId();
      _reload();
      if (mounted) setState(() => _busy = false);
    } on AppError catch (error) {
      if (!mounted) return;
      // 입력은 지우지 않는다 — 실패한 저장을 다시 누르는 데 다시 타이핑이
      // 필요하면 안 된다. 멱등키도 그대로 둬 재시도가 중복을 만들지 않는다.
      setState(() => _busy = false);
      _toast(serverDetailOr(l, error.message, l.followUpSaveFailed));
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(l.followUpSaveFailed);
    }
  }

  Future<void> _complete(FollowUpTask task) async {
    if (_completing != null) return;
    final l = AppLocalizations.of(context);
    setState(() => _completing = task.id);
    try {
      await ref.read(followUpTaskRepositoryProvider).complete(task.id);
      _reload();
    } on AppError catch (error) {
      if (mounted) {
        _toast(serverDetailOr(l, error.message, l.followUpCompleteFailed));
      }
    } on Object {
      if (mounted) _toast(l.followUpCompleteFailed);
    } finally {
      if (mounted) setState(() => _completing = null);
    }
  }

  Future<void> _pickDate() async {
    final DateTime today = todayKst();
    final picked = await showPortraitDatePicker(
      context: context,
      initialDate: _dueDate,
      // 지난 날짜로 새 할 일을 만들 이유가 없다 — 만드는 순간 '기한 지남'이다.
      firstDate: today,
      lastDate: today.add(_maxAhead),
    );
    if (picked == null || !mounted) return;
    setState(() => _dueDate = DateTime(picked.year, picked.month, picked.day));
  }

  String _contextLabel(AppLocalizations l, FollowUpContext context) =>
      switch (context) {
        FollowUpContext.general => l.followUpContextGeneral,
        FollowUpContext.diet => l.followUpContextDiet,
        FollowUpContext.exercise => l.followUpContextExercise,
        FollowUpContext.message => l.followUpContextMessage,
        FollowUpContext.program => l.followUpContextProgram,
        FollowUpContext.schedule => l.followUpContextSchedule,
      };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final tasks = ref.watch(clientFollowUpsProvider(widget.clientId));

    return AlertDialog(
      title: Text(l.followUpTitle(widget.clientName)),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('client-follow-up-input'),
              controller: _draft,
              maxLines: 2,
              maxLength: _maxLength,
              enabled: !_busy,
              decoration: InputDecoration(
                hintText: l.followUpHint,
                border: const OutlineInputBorder(),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                OutlinedButton.icon(
                  key: const ValueKey<String>('client-follow-up-due'),
                  onPressed: _busy ? null : _pickDate,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text('${l.followUpDue} ${ymd(_dueDate)}'),
                ),
                DropdownButton<FollowUpContext>(
                  key: const ValueKey<String>('client-follow-up-context'),
                  value: _context,
                  onChanged: _busy
                      ? null
                      : (value) => setState(
                          () => _context = value ?? FollowUpContext.general,
                        ),
                  items: <DropdownMenuItem<FollowUpContext>>[
                    for (final option in FollowUpContext.values)
                      DropdownMenuItem<FollowUpContext>(
                        value: option,
                        child: Text(_contextLabel(l, option)),
                      ),
                  ],
                ),
                FilledButton.icon(
                  key: const ValueKey<String>('client-follow-up-add'),
                  onPressed: _busy ? null : _add,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l.followUpAdd),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // 고정 높이가 아니라 Flexible — 낮은 창에서도 아래 동작 줄이 화면
            // 밖으로 밀리지 않는다(메모 다이얼로그와 같은 이유).
            Flexible(
              child: tasks.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Column(
                    children: <Widget>[
                      Text(
                        error is AppError
                            ? serverDetailOr(
                                l,
                                error.message,
                                l.followUpLoadFailed,
                              )
                            : l.followUpLoadFailed,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: () => ref.invalidate(
                          clientFollowUpsProvider(widget.clientId),
                        ),
                        child: Text(l.actionRetry),
                      ),
                    ],
                  ),
                ),
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xl,
                        ),
                        child: Text(
                          l.followUpEmpty,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: <Widget>[
                          for (final task in list)
                            FollowUpRow(
                              key: ValueKey<String>(
                                'client-follow-up-${task.id}',
                              ),
                              task: task,
                              busy: _completing == task.id,
                              onComplete: () => _complete(task),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l.actionClose),
        ),
      ],
    );
  }
}
