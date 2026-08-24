import 'package:flutter/material.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_draft.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';
import 'package:oncare/features/exercise/presentation/utils/preferred_time_format.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// 상담 요청 한 건의 카드 표시. 운동 탭 요약(`gym_tab.dart`)과 "내 상담 요청"
/// 전체 내역 화면이 같은 모양을 쓴다 — 두 화면이 각자 그리면 상태 배지·거절
/// 사유 문구가 조용히 갈라진다(#948).
class ConsultationRequestCard extends StatelessWidget {
  const ConsultationRequestCard({
    required this.request,
    this.onCancel,
    super.key,
  });

  final ConsultationRequest request;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String targetName = request.trainerName ?? '';
    final String targetType =
        request.trainerGymName ?? request.trainerName ?? '';
    final String status = switch (request.status) {
      ConsultationStatus.pending => l.exConsultPendingStatus,
      ConsultationStatus.accepted => l.exConsultAcceptedStatus,
      ConsultationStatus.rejected => l.exConsultRejectedStatus,
      ConsultationStatus.cancelled => l.errorCancelled,
    };
    final String date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(request.preferredDate);
    final Widget? outcome = _outcomeNote(context, l);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FigmaColors.hairline),
        boxShadow: kCardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: FigmaColors.primaryA(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.fitness_center,
              size: 21,
              color: FigmaColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        targetName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: FigmaColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: FigmaColors.primaryA(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  targetType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$date · '
                  '${preferredTimeLabel(context, l, request.preferredTimeSlot)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 10),
                _DetailLine(label: l.exExerciseGoal, value: _goalLabel(l)),
                if ((request.message ?? '').trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  _DetailLine(
                    label: l.exConsultMessage,
                    value: request.message!.trim(),
                  ),
                ],
                if (onCancel != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: ValueKey<String>(
                        'cancel-consultation-${request.id}',
                      ),
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.destructive,
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        l.actionCancel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
                if (outcome != null) ...<Widget>[
                  const SizedBox(height: 10),
                  outcome,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 처리된 요청에 붙는 결과 안내. 대기 중이면 null. (#473)
  Widget? _outcomeNote(BuildContext context, AppLocalizations l) {
    switch (request.status) {
      case ConsultationStatus.pending:
        return null;
      case ConsultationStatus.accepted:
        return _OutcomeNote(
          key: const Key('consult-outcome-accepted'),
          tone: FigmaColors.primary,
          text: l.exConsultAcceptedGuide,
        );
      case ConsultationStatus.rejected:
        final String? note = request.decisionNote;
        return _OutcomeNote(
          key: const Key('consult-outcome-rejected'),
          tone: FigmaColors.textMuted,
          label: note == null ? null : l.exConsultRejectedReasonLabel,
          text: note ?? l.exConsultRejectedNoReason,
        );
      case ConsultationStatus.cancelled:
        return null;
    }
  }

  String _goalLabel(AppLocalizations l) => switch (request.exerciseGoal) {
    ExerciseGoal.weightLoss => l.exGoalWeightLoss,
    ExerciseGoal.strength => l.exGoalStrength,
    ExerciseGoal.fitness => l.exGoalFitness,
    ExerciseGoal.posture => l.exGoalPosture,
    ExerciseGoal.health => l.exGoalHealth,
    ExerciseGoal.other => l.exOptionOther,
  };
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      SizedBox(
        width: 70,
        child: Text(
          label,
          style: const TextStyle(color: AppColors.mutedForeground),
        ),
      ),
      Expanded(
        child: Text(value, style: const TextStyle(color: AppColors.foreground)),
      ),
    ],
  );
}

/// 상태 카드 하단의 결과 안내 한 덩어리 — 승인 안내 또는 거절 사유.
class _OutcomeNote extends StatelessWidget {
  const _OutcomeNote({
    required this.tone,
    required this.text,
    this.label,
    super.key,
  });

  final Color tone;
  final String? label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (label != null) ...<Widget>[
            Text(
              label!,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: tone,
              ),
            ),
            const SizedBox(height: 3),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: FigmaColors.textBody,
            ),
          ),
        ],
      ),
    );
  }
}
