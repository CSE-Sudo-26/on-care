import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_draft.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

class ConsultationCompletePage extends StatelessWidget {
  const ConsultationCompletePage({required this.request, super.key});

  final ConsultationRequest? request;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ConsultationRequest? consultation = request;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: consultation == null,
        centerTitle: true,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title: Text(
          l.exConsultRequestTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: FigmaColors.ink,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: consultation == null
            ? _MissingRequest(message: l.exConsultTargetNotFound)
            : _CompletionContent(request: consultation),
      ),
    );
  }
}

class _CompletionContent extends StatelessWidget {
  const _CompletionContent({required this.request});

  final ConsultationRequest request;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String targetName =
        request.targetType == ConsultationTargetType.trainer
        ? request.trainerName ?? request.gymName
        : request.gymName;
    final String targetType =
        request.targetType == ConsultationTargetType.trainer
        ? l.exTrainerConsultType
        : l.exGymConsultType;
    final String date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(request.preferredDate);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 42, 20, 32),
          children: <Widget>[
            Center(
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: FigmaColors.primaryA(0.10),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check_rounded,
                  size: 44,
                  color: FigmaColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              l.exConsultReceived,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: FigmaColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l.exConsultCompletionInfo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FigmaColors.hairline),
              ),
              child: Column(
                children: <Widget>[
                  _SummaryRow(label: targetType, value: targetName),
                  const Divider(height: 25, color: FigmaColors.hairline),
                  _SummaryRow(
                    label: l.exPreferredDate,
                    value: '$date · ${_timeLabel(l, request.preferredTimeSlot)}',
                  ),
                  const Divider(height: 25, color: FigmaColors.hairline),
                  _SummaryRow(
                    label: l.exConsultStatus,
                    value: l.exConsultPendingStatus,
                    emphasized: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => context.go(AppRoutes.exerciseGym),
              style: FilledButton.styleFrom(
                backgroundColor: FigmaColors.primary,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                l.exReturnExercise,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: emphasized ? FigmaColors.primary : FigmaColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _MissingRequest extends StatelessWidget {
  const _MissingRequest({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.foreground),
        ),
      ),
    );
  }
}

/// 시간대 enum → 현지화 문구. 엔티티가 라벨 대신 계약 enum 을 들고 있으므로 화면이
/// 렌더 시점에 만든다 — 그래야 서버에서 복원한 신청도 같은 문구로 보인다(#327).
String _timeLabel(AppLocalizations l, PreferredTimeSlot slot) => switch (slot) {
  PreferredTimeSlot.morning => l.exTimeMorning,
  PreferredTimeSlot.afternoon => l.exTimeAfternoon,
  PreferredTimeSlot.evening => l.exTimeEvening,
  PreferredTimeSlot.flexible => l.exTimeFlexible,
};
