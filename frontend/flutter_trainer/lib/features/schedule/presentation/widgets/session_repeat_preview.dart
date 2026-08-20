import 'package:flutter/material.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 저장하면 만들어질 회차 요약 — "총 8회 · 8/24 ~ 10/12". (#870)
///
/// 반복은 한 번에 여러 건을 만든다. 요일이나 종료일을 잘못 골랐을 때 되돌리는
/// 비용이 한 건씩 지우는 일이라, 만들기 전에 몇 회차인지 말해 준다.
class SessionRepeatPreview extends StatelessWidget {
  const SessionRepeatPreview({super.key, required this.dates});

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
class SessionRepeatConflicts extends StatelessWidget {
  const SessionRepeatConflicts({
    super.key,
    required this.total,
    required this.conflicts,
  });

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
