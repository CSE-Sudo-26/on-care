import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/coaching/data/dtos/routine_dtos.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_suggestion_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/routine_suggestion.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/routine_suggestion_edit_dialog.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// The AI personal-exercise review area of the program tab (#790).
///
/// 정규 프로그램 편집기 **위**에 두고 시각적으로 갈라 둔다. 둘의 목적이 다르기
/// 때문이다 — 정규 프로그램은 일정 기간의 전체 계획이고, 개인운동은 PT 와 다음
/// PT 사이에 하는 짧은 보완·회복 운동이다. 그래서 편집기 안에 섞지 않고 여기서
/// `판단`만 한다: 그대로 추천 / 수정 후 추천 / 추천 안 함.
///
/// 승인은 새 배정을 만드는 것이 아니라 **이 제안을 배정으로 바꾸는 것**이다.
/// 회원 알림도 그 시점에 서버가 보낸다. 승인 전 후보는 회원에게 보이지 않는다.
class RoutineSuggestionReviewCard extends ConsumerStatefulWidget {
  /// Creates the review area for [clientId].
  const RoutineSuggestionReviewCard({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  /// Member whose suggestions are reviewed. 회원이 바뀌면 그 회원의 목록으로
  /// 갱신된다 — provider 가 회원별로 갈라져 있다.
  final String clientId;

  /// Member's display name, used in the intro line and the SnackBar.
  final String clientName;

  @override
  ConsumerState<RoutineSuggestionReviewCard> createState() =>
      _RoutineSuggestionReviewCardState();
}

class _RoutineSuggestionReviewCardState
    extends ConsumerState<RoutineSuggestionReviewCard> {
  /// 처리 중인 제안 id.
  ///
  /// 카드별로 담는 이유: 하나를 승인하는 동안 다른 제안은 계속 판단할 수 있어야
  /// 하지만, **같은 제안**의 두 번째 클릭은 막아야 한다. 서버가 409 로 다시
  /// 막아 주긴 하지만, 그 왕복 동안 트레이너는 아무 반응 없는 버튼을 두 번
  /// 누른 상태다.
  final Set<String> _busy = <String>{};

  Future<void> _approve(
    RoutineSuggestion suggestion, {
    RoutineSuggestionEdit? edit,
  }) async {
    final AppLocalizations l = AppLocalizations.of(context);
    await _review(
      suggestion,
      () => ref
          .read(trainerRoutineSuggestionRepositoryProvider)
          .approve(
            suggestion.id,
            name: edit?.name,
            minutes: edit?.minutes,
            type: edit?.type,
            reason: edit?.reason,
          ),
      l.suggestionApproved(
        edit?.name ?? suggestion.name,
        widget.clientName,
      ),
    );
  }

  Future<void> _dismiss(RoutineSuggestion suggestion) async {
    final AppLocalizations l = AppLocalizations.of(context);
    await _review(
      suggestion,
      () => ref
          .read(trainerRoutineSuggestionRepositoryProvider)
          .dismiss(suggestion.id),
      l.suggestionDismissed(suggestion.name),
    );
  }

  Future<void> _editThenApprove(RoutineSuggestion suggestion) async {
    if (_busy.contains(suggestion.id)) return;
    final edit = await showRoutineSuggestionEditDialog(context, suggestion);
    if (edit == null || !mounted) return;
    await _approve(suggestion, edit: edit);
  }

  /// 검토 한 건을 실행하고 목록을 다시 읽는다.
  ///
  /// 성공하면 provider 를 invalidate 한다 — 카드를 화면에서만 지우면, 다른 창의
  /// 판단이나 서버가 이미 처리한 상태와 화면이 어긋난다. 목록을 다시 읽는 쪽이
  /// 언제나 서버의 사실과 같다.
  Future<void> _review(
    RoutineSuggestion suggestion,
    Future<void> Function() action,
    String success,
  ) async {
    if (_busy.contains(suggestion.id)) return;
    final messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final reviewedFor = widget.clientId;
    setState(() => _busy.add(suggestion.id));
    try {
      await action();
      ref.invalidate(routineSuggestionsProvider(reviewedFor));
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } on RoutineSuggestionAlreadyReviewed {
      // 두 번 눌렀거나 다른 창에서 이미 처리했다. 실패로 말하면 트레이너는 자기
      // 판단이 반영되지 않았다고 읽는다 — 실제로는 반영돼 있다.
      ref.invalidate(routineSuggestionsProvider(reviewedFor));
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l.suggestionAlreadyReviewed)),
      );
    } on AppError catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            serverDetailOr(l, error.message, l.suggestionActionFailed),
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l.suggestionActionFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(suggestion.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final pending = ref.watch(routineSuggestionsProvider(widget.clientId));
    final rows = pending.valueOrNull ?? const <RoutineSuggestion>[];

    return SectionCard(
      key: const ValueKey<String>('routine-suggestion-review-card'),
      title: l.suggestionReviewTitle,
      // 정규 프로그램 카드들과 한눈에 갈라지는 표시 — 여기는 AI 가 준비한 것을
      // 판단하는 자리다.
      icon: Icons.auto_awesome,
      dense: true,
      trailing: rows.isEmpty ? null : _ReviewBadge(count: rows.length),
      child: switch (pending) {
        AsyncError() => Text(
          l.suggestionReviewLoadFailed,
          key: const ValueKey<String>('routine-suggestion-error'),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.subtleForeground,
          ),
        ),
        // 목록이 비었을 때 큰 empty card 를 만들지 않는다 — 검토할 것이 없는
        // 날에도 프로그램 탭의 절반을 차지하면 안 된다.
        AsyncData(:final value) when value.isEmpty => Text(
          l.suggestionReviewEmpty,
          key: const ValueKey<String>('routine-suggestion-empty'),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.subtleForeground,
          ),
        ),
        AsyncLoading() when rows.isEmpty => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        _ => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l.suggestionReviewIntro(widget.clientName),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.subtleForeground,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final suggestion in rows) ...<Widget>[
              _SuggestionCard(
                key: ValueKey<String>('routine-suggestion-${suggestion.id}'),
                suggestion: suggestion,
                busy: _busy.contains(suggestion.id),
                onApprove: () => _approve(suggestion),
                onEdit: () => _editThenApprove(suggestion),
                onDismiss: () => _dismiss(suggestion),
              ),
              if (suggestion != rows.last)
                const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      },
    );
  }
}

class _ReviewBadge extends StatelessWidget {
  const _ReviewBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.accentSurface,
        borderRadius: BorderRadius.all(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        child: Text(
          AppLocalizations.of(context).suggestionReviewBadge(count),
          key: const ValueKey<String>('routine-suggestion-badge'),
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }
}

/// One suggestion: what it is, why, and the three judgements.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    super.key,
    required this.suggestion,
    required this.busy,
    required this.onApprove,
    required this.onEdit,
    required this.onDismiss,
  });

  final RoutineSuggestion suggestion;

  /// 이 제안의 검토가 진행 중이다 — 세 버튼 모두 잠긴다.
  final bool busy;

  final VoidCallback onApprove;
  final VoidCallback onEdit;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  suggestion.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l.minutesShort(suggestion.minutes),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            routineTypeLabel(l, suggestion.type),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.subtleForeground,
            ),
          ),
          if (suggestion.reason.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              suggestion.reason,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.foreground,
                height: 1.4,
              ),
            ),
          ],
          if (suggestion.evidence.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            // 근거는 서버가 만든 짧은 표시다 — AI 내부 분석을 길게 노출하지 않고
            // 트레이너가 승인 판단에 쓸 재료만 보여 준다.
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final item in suggestion.evidence)
                  _EvidenceChip(label: item),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              TextButton(
                key: ValueKey<String>(
                  'routine-suggestion-dismiss-${suggestion.id}',
                ),
                onPressed: busy ? null : onDismiss,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.mutedForeground,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                ),
                child: Text(l.suggestionDismiss),
              ),
              const Spacer(),
              if (busy) ...<Widget>[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              OutlinedButton(
                key: ValueKey<String>(
                  'routine-suggestion-edit-${suggestion.id}',
                ),
                onPressed: busy ? null : onEdit,
                child: Text(l.actionEdit),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                key: ValueKey<String>(
                  'routine-suggestion-approve-${suggestion.id}',
                ),
                onPressed: busy ? null : onApprove,
                child: Text(l.suggestionApprove),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EvidenceChip extends StatelessWidget {
  const _EvidenceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.sm),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.subtleForeground,
          ),
        ),
      ),
    );
  }
}
