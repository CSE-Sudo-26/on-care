import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// `1:1 PT · 60분` — 이 약속이 무엇인가. (#938)
///
/// 상태 칩과 나란히 서지만 뜻이 갈린다. 상태는 "어떻게 됐나"(예정·완료·취소),
/// 이쪽은 "무엇인가" 다. 그래서 색도 갈라 둔다 — 상태 칩이 색으로 결과를
/// 말하는 동안 이쪽은 늘 같은 남색이다. 끝난 세션만 함께 흐려진다.
///
/// 좁아지면 **이 알약이 먼저 줄어든다.** 이름과 상태는 잘리면 안 되는 값이라,
/// 글자를 자르는 대신 `FittedBox` 로 통째로 작게 그린다.
class SessionTypeChip extends StatelessWidget {
  const SessionTypeChip({super.key, required this.label, required this.muted});

  final String label;

  /// 끝난 세션인가. 상태 칩과 같은 기준으로 함께 물러난다.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Container(
        key: const ValueKey<String>('session-type-chip'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: muted
              ? AppColors.inputBackground
              : AppColors.primary.withValues(alpha: 0.10),
          borderRadius: const BorderRadius.all(AppRadius.pill),
          border: Border.all(
            color: muted
                ? AppColors.border
                : AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: muted ? AppColors.disabledForeground : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// 예정·완료·취소·노쇼 — 이 약속이 **어떻게 됐나**. (#871)
///
/// 무엇인가를 말하는 [SessionTypeChip] 과 나란히 서지만 색으로 결과를
/// 구분한다.
class SessionStatusChip extends StatelessWidget {
  const SessionStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    // 예정(파랑) · 완료(초록) · 취소/노쇼(빨강)로 갈라 둔다. 진행되지 않은
    // 세션이 완료와 같은 색이면 "끝난 수업" 으로 읽히고, 예정과 같은 파랑이면
    // 아직 할 일로 읽힌다 — 둘 다 사실이 아니다(#871).
    //
    // 완료를 회색으로 두었더니 시간표 블록의 초록 띠와 어긋났다. 같은 사실을
    // 두 자리가 다른 색으로 말하면 어느 쪽을 믿어야 할지 알 수 없다(#1012).
    final Color fg = switch (status) {
      ScheduleStatus.done => AppColors.success,
      ScheduleStatus.cancelled || ScheduleStatus.noShow => AppColors.warning,
      _ => AppColors.accent,
    };
    final Color bg = switch (status) {
      ScheduleStatus.done => AppColors.success.withValues(alpha: 0.12),
      ScheduleStatus.cancelled ||
      ScheduleStatus.noShow => AppColors.warning.withValues(alpha: 0.12),
      _ => AppColors.accentSurface,
    };
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
        // 색은 계약값(`status`)으로 고르고, 글자는 로케일 문구로 그린다.
        scheduleStatusLabel(AppLocalizations.of(context), status),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
