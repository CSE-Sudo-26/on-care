import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_period_toggle.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// 고객 운동 추이 — `오늘 / 이번 주 / 이번 달` 을 고를 수 있다. (#914)
///
/// 예전에는 이번 주 7일 고정이라, 오늘 하루만 보고 싶어도 한 달 흐름을 보고
/// 싶어도 방법이 없었다. 회원 앱 운동 탭이 이미 세 기간을 주는데 정작 코칭하는
/// 트레이너 화면만 한 주에 묶여 있었다.
class WeeklyExerciseTrendCard extends ConsumerStatefulWidget {
  /// Creates the trend card for [clientId].
  const WeeklyExerciseTrendCard({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<WeeklyExerciseTrendCard> createState() =>
      _WeeklyExerciseTrendCardState();
}

class _WeeklyExerciseTrendCardState
    extends ConsumerState<WeeklyExerciseTrendCard> {
  /// 기본은 **오늘**이다 — 식단 카드와 첫 화면의 기준을 맞춘다.
  ClientPeriod _period = ClientPeriod.today;
  bool _showCalories = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ClientPeriodKey key = (clientId: widget.clientId, period: _period);
    final AsyncValue<ClientExercisePeriod> async = ref.watch(
      clientExercisePeriodProvider(key),
    );
    return SectionCard(
      title: l.clientTrendTitle,
      icon: Icons.monitor_heart_outlined,
      dense: true,
      trailing: ClientPeriodToggle(
        active: _period,
        onChanged: (ClientPeriod p) => setState(() => _period = p),
      ),
      child: async.when(
        loading: () => const SizedBox(
          height: 160,
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
        data: (ClientExercisePeriod period) => Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                // `오늘` 에 '운동한 날 1일' 은 아무것도 말해 주지 않는다 —
                // 기간을 볼 때만 센다.
                if (_period != ClientPeriod.today)
                  Expanded(
                    child: _SummaryMetric(
                      label: l.clientTrendWorkoutDays,
                      value: '${period.workoutDays}',
                      unit: l.unitDays,
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
            if (_period == ClientPeriod.today)
              if (period.isEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                EmptyHint(
                  message: l.clientTrendTodayEmpty,
                  icon: Icons.fitness_center_outlined,
                ),
              ] else
                const SizedBox.shrink()
            else ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: SegmentedButton<bool>(
                  segments: <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: false,
                      label: Text(l.clientTrendSegmentTime),
                      icon: const Icon(Icons.schedule, size: 14),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text(l.metricCalories),
                      icon: const Icon(
                        Icons.local_fire_department_outlined,
                        size: 14,
                      ),
                    ),
                  ],
                  selected: <bool>{_showCalories},
                  onSelectionChanged: (Set<bool> selected) =>
                      setState(() => _showCalories = selected.first),
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll<TextStyle>(
                      TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _DailyBars(
                days: period.days,
                values: <int>[
                  for (final ClientExerciseDay d in period.days)
                    _showCalories ? d.calories : d.minutes,
                ],
                unit: _showCalories ? l.unitKcal : l.unitMinutes,
                // 칼로리 계열은 **주황이 아니라 연한 남색**이다(#914). 트레이너
                // 앱은 남색 브랜드에 주황을 작은 강조로만 쓰기로 한 팔레트인데
                // 그래프 전체가 주황으로 칠해져 카드에서 이 계열만 튀었고,
                // 주황은 옆 화면에서 '주의' 로 읽히던 색이라 많이 탄 좋은 날이
                // 경고처럼 보였다. 같은 계열 안에서 명도로 갈라 둔다.
                color: _showCalories
                    ? AppColors.aiCardGradientEnd
                    : AppColors.primary,
                // 달(30칸)은 값 라벨을 다 적으면 서로 겹친다.
                showValues: period.days.length <= 10,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

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
            TextSpan(
              text: ' $unit',
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

class _DailyBars extends StatelessWidget {
  const _DailyBars({
    required this.days,
    required this.values,
    required this.unit,
    required this.color,
    required this.showValues,
  });

  final List<ClientExerciseDay> days;
  final List<int> values;
  final String unit;
  final Color color;

  /// 막대 위에 값을 적을지. 한 달은 칸이 좁아 라벨이 서로 겹친다.
  final bool showValues;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final int count = math.min(days.length, values.length);
    final int maxValue = values.take(count).fold<int>(0, math.max);
    // 달(30칸)에서도 날짜 라벨이 겹치지 않도록 몇 칸에 하나만 적는다.
    final int labelStep = count > 10 ? (count / 6).ceil() : 1;
    return SizedBox(
      height: 128,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int index = 0; index < count; index++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: count > 10 ? 1 : 3),
                child: Tooltip(
                  key: Key('client-exercise-bar-$index'),
                  message: values[index] == 0
                      ? '${days[index].month}/${days[index].day} · '
                            '${l.chartNoRecord}'
                      : '${days[index].month}/${days[index].day} · '
                            '${values[index]}$unit',
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      if (showValues)
                        Text(
                          values[index] == 0 ? '-' : '${values[index]}$unit',
                          maxLines: 1,
                          style: const TextStyle(
                            color: AppColors.subtleForeground,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: values[index] == 0
                            ? 3
                            : 72 * values[index] / math.max(maxValue, 1),
                        decoration: BoxDecoration(
                          color: values[index] == 0
                              ? AppColors.borderStrong
                              : color.withValues(alpha: 0.82),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        index % labelStep == 0
                            ? _dayLabel(l, days[index], count)
                            : '',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: const TextStyle(
                          color: AppColors.mutedForeground,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 한 주는 요일(월…일)로, 한 달은 날짜(1…31)로 읽는 편이 자연스럽다.
  static String _dayLabel(AppLocalizations l, ClientExerciseDay d, int count) {
    if (count > 10) return '${d.date.day}';
    return <String>[
      l.weekdayMon,
      l.weekdayTue,
      l.weekdayWed,
      l.weekdayThu,
      l.weekdayFri,
      l.weekdaySat,
      l.weekdaySun,
    ][d.date.weekday - 1];
  }
}

/// 날짜 접근을 짧게 쓰기 위한 보조.
extension on ClientExerciseDay {
  int get month => date.month;
  int get day => date.day;
}
