import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/activity_charts.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// 고객 운동 현황 — 회원 앱 운동 탭 `운동 현황` 과 **같은 그림**이다. (#943)
///
/// `오늘` 은 도넛 + 유형별 시간, `이번 주`·`이번 달` 은 유형별 3색 누적 막대다.
/// 예전에는 트레이너만 다른 그래프를 봤다 — 회원이 "이번 주 근력이 적었죠" 라고
/// 말해도 트레이너 화면에는 그 근거가 없었다.
///
/// 기간 토글은 이 카드가 아니라 바깥 [ClientPeriodSection] 이 그린다. 카드
/// 안에 두면 기간을 바꿀 때 토글이 함께 움직인다.
class ClientExerciseStatusCard extends ConsumerWidget {
  /// Creates the card for [clientId] over [period].
  const ClientExerciseStatusCard({
    super.key,
    required this.clientId,
    required this.period,
  });

  final String clientId;
  final ClientPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ClientPeriodKey key = clientPeriodKeyNow(clientId, period);
    final AsyncValue<ClientExercisePeriod> async = ref.watch(
      clientExercisePeriodProvider(key),
    );
    return _Card(
      child: async.when(
        loading: () => const SizedBox(
          height: 170,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => EmptyHint(
          message: l.clientTrendLoadFailed,
          action: ActionButton(
            key: const ValueKey<String>('weekly-exercise-retry'),
            label: l.actionRetry,
            onPressed: () => ref.invalidate(clientExercisePeriodProvider(key)),
          ),
        ),
        data: (ClientExercisePeriod data) => period == ClientPeriod.today
            ? _Today(period: data)
            : _Range(period: data),
      ),
    );
  }
}

/// 회원 앱 카드와 같은 흰 판 — `SectionCard` 는 제목 줄을 갖는데, 제목은 이제
/// 바깥 섹션 헤더가 그린다.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey<String>('client-exercise-status-card'),
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: const BorderRadius.all(AppRadius.card),
      boxShadow: kCardShadow,
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

class _Today extends StatelessWidget {
  const _Today({required this.period});

  final ClientExercisePeriod period;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    if (period.isEmpty) {
      return EmptyHint(
        message: l.clientTrendTodayEmpty,
        icon: Icons.fitness_center_outlined,
      );
    }
    // 유형 분해가 없으면 전부 유산소로 본다. 임의로 나누면 없는 근력 시간을
    // 지어내는 셈이다.
    final bool split = period.days.any((ClientExerciseDay d) => d.hasTypeSplit);
    return ActivityDonut(
      title: l.clientTrendTodayTotal,
      segs: <ActivitySeg>[
        ActivitySeg(
          l.routineTypeCardio,
          split ? period.totalCardioMinutes : period.totalMinutes,
          AppColors.chartCardio,
        ),
        ActivitySeg(
          l.routineTypeStrength,
          split ? period.totalStrengthMinutes : 0,
          AppColors.chartStrength,
        ),
        ActivitySeg(
          l.routineTypeStretching,
          split ? period.totalStretchingMinutes : 0,
          AppColors.chartStretching,
        ),
      ],
    );
  }
}

class _Range extends StatelessWidget {
  const _Range({required this.period});

  final ClientExercisePeriod period;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<ClientExerciseDay> days = period.days;
    final bool monthly = days.length > 10;
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _SummaryMetric(
                label: l.clientTrendWorkoutDays,
                value: l.clientTrendWorkoutDaysValue(period.workoutDays),
              ),
            ),
            Expanded(
              child: _SummaryMetric(
                label: l.clientTrendWorkoutMinutes,
                value: '${period.totalMinutes}',
                unit: l.unitMinutes,
              ),
            ),
            Expanded(
              child: _SummaryMetric(
                label: l.clientTrendCaloriesBurned,
                value: '${period.totalCalories}',
                unit: l.unitKcal,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ActivityBarChart(
          bars: <ActivityBar>[
            for (final ClientExerciseDay d in days)
              if (d.hasTypeSplit)
                ActivityBar(
                  d.cardioMinutes.toDouble(),
                  d.strengthMinutes.toDouble(),
                  d.stretchingMinutes.toDouble(),
                )
              else
                ActivityBar(d.minutes.toDouble(), 0, 0),
          ],
          // 한 주는 요일로, 한 달은 날짜로 읽는 편이 자연스럽다. 달은 칸이 좁아
          // 몇 칸에 하나만 적는다.
          dayLabels: <String>[
            for (int i = 0; i < days.length; i++)
              if (!monthly)
                _weekdayLabel(l, days[i].date)
              else if (i == 0 || i % 5 == 0 || i == days.length - 1)
                '${days[i].date.day}'
              else
                '',
          ],
          todayIndex: _todayIndexIn(days),
        ),
      ],
    );
  }

  static String _weekdayLabel(AppLocalizations l, DateTime d) => <String>[
    l.weekdayMon,
    l.weekdayTue,
    l.weekdayWed,
    l.weekdayThu,
    l.weekdayFri,
    l.weekdaySat,
    l.weekdaySun,
  ][d.weekday - 1];

  /// 오늘이 이 범위의 몇 번째 칸인가. 범위 밖이면 -1 — 지난 기간을 볼 때
  /// 엉뚱한 칸이 오늘로 강조되지 않는다.
  static int _todayIndexIn(List<ClientExerciseDay> days) {
    final DateTime today = todayKst();
    for (int i = 0; i < days.length; i++) {
      final DateTime d = days[i].date;
      if (DateTime(d.year, d.month, d.day) == today) return i;
    }
    return -1;
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value, this.unit});

  final String label;

  /// 큰 글씨로 적는 값. 단위가 값과 한 문구로 묶여 오는 경우도 있다.
  final String value;

  /// 값 뒤에 작게 붙일 단위. 값에 이미 단위가 들어 있으면 비운다.
  final String? unit;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.subtleForeground,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 3),
      Text.rich(
        TextSpan(
          text: value,
          style: const TextStyle(
            color: AppColors.foreground,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
          children: <InlineSpan>[
            if (unit case final String suffix)
              TextSpan(
                text: ' $suffix',
                style: const TextStyle(
                  color: AppColors.mutedForeground,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
