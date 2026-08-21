import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/exercise_burn_goals.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/activity_charts.dart';
import 'package:oncare_trainer/shared/widgets/period_scroll_chart.dart';
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
    return BurnDonut(
      title: l.exBurnTodayTitle,
      calories: period.totalCalories,
      goal: kDailyBurnKcal,
      split: ActivitySplit(
        cardioMinutes: split ? period.totalCardioMinutes : period.totalMinutes,
        strengthSets: split ? period.totalStrengthSets : 0,
        stretchingMinutes: split ? period.totalStretchingMinutes : 0,
        otherMinutes: period.totalOtherMinutes,
      ),
    );
  }
}

class _Range extends StatefulWidget {
  const _Range({required this.period});

  final ClientExercisePeriod period;

  @override
  State<_Range> createState() => _RangeState();
}

class _RangeState extends State<_Range> {
  /// `전체` 그래프의 스크롤 위치와 고른 칸. 위의 요약 숫자가 이걸 따라간다 —
  /// 보이지 않는 구간까지 더한 합계는 지금 화면을 설명하지 못한다. (#1018)
  final PeriodChartSelection _selection = PeriodChartSelection();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final ClientExercisePeriod period = widget.period;
    final List<ClientExerciseDay> days = period.days;
    final bool monthly = days.length > 10;
    // `전체` 는 **한 칸이 한 주**다. 회원 앱 운동 탭과 같은 눈금이라야 둘이
    // 같은 그림을 보고 이야기할 수 있다 — 일별 막대는 여덟 달을 늘어놓으면
    // 실오라기가 되고, 한 주를 잘한 것인지 한 날을 잘한 것인지도 흐려진다.
    // (#1077)
    final List<_WeekBucket> weeks = monthly
        ? _weekBucketsOf(days)
        : const <_WeekBucket>[];
    return Column(
      children: <Widget>[
        ListenableBuilder(
          listenable: _selection,
          builder: (BuildContext context, Widget? _) {
            // 전체가 아니면 지금까지처럼 기간 전체의 합계다.
            final int? picked = monthly ? _selection.selected : null;
            final (int first, int last) = monthly
                ? (_selection.visible ?? (0, weeks.length - 1))
                : (0, days.length - 1);
            final Iterable<_WeekBucket> shownWeeks = monthly
                ? (picked != null
                      ? <_WeekBucket>[weeks[picked]]
                      : weeks.sublist(
                          first.clamp(0, weeks.length),
                          (last + 1).clamp(0, weeks.length),
                        ))
                : const <_WeekBucket>[];
            final int workoutDays = monthly
                ? shownWeeks.fold<int>(
                    0,
                    (int a, _WeekBucket w) => a + w.loggedDays,
                  )
                : days.where((ClientExerciseDay d) => d.logged).length;
            final int minutes = monthly
                ? shownWeeks.fold<int>(
                    0,
                    (int a, _WeekBucket w) => a + w.minutes,
                  )
                : days.fold<int>(
                    0,
                    (int a, ClientExerciseDay d) => a + d.minutes,
                  );
            final int calories = monthly
                ? shownWeeks.fold<int>(
                    0,
                    (int a, _WeekBucket w) => a + w.calories,
                  )
                : days.fold<int>(
                    0,
                    (int a, ClientExerciseDay d) => a + d.calories,
                  );
            return Row(
              children: <Widget>[
                Expanded(
                  child: _SummaryMetric(
                    label: picked == null
                        ? l.clientTrendWorkoutDays
                        : weeks[picked].rangeLabel(locale),
                    value: l.clientTrendWorkoutDaysValue(workoutDays),
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: l.clientTrendWorkoutMinutes,
                    value: '$minutes',
                    unit: l.unitMinutes,
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: l.clientTrendCaloriesBurned,
                    value: '$calories',
                    unit: l.unitKcal,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        // 이번 주는 유형별 주간 목표를 겹친 링으로, 전체는 주별 소모 칼로리
        // 막대로. 회원 앱 `운동 현황` 과 같은 규칙이다. (#1077)
        if (!monthly)
          BurnGoalRings(
            title: l.exBurnWeekTitle,
            calories: period.totalCalories,
            split: ActivitySplit(
              cardioMinutes: period.totalCardioMinutes,
              strengthSets: period.totalStrengthSets,
              stretchingMinutes: period.totalStretchingMinutes,
              otherMinutes: period.totalOtherMinutes,
            ),
          )
        else
          BurnBarChart(
            title: l.clientTrendTitle,
            selection: _selection,
            goalKcal: kWeeklyBurnKcal,
            calories: <int>[for (final _WeekBucket w in weeks) w.calories],
            splits: <ActivitySplit>[for (final _WeekBucket w in weeks) w.split],
            dates: <DateTime>[for (final _WeekBucket w in weeks) w.monday],
          ),
      ],
    );
  }
}

/// `전체` 그래프의 한 칸 — 한 주(월~일)의 합계.
class _WeekBucket {
  _WeekBucket(this.monday);

  final DateTime monday;
  int calories = 0;
  int minutes = 0;

  /// 그 주에 기록이 있는 날 수. 머리의 `운동한 날` 이 이 값을 더한다.
  int loggedDays = 0;

  int _cardioMinutes = 0;
  int _strengthSets = 0;
  int _stretchingMinutes = 0;
  int _otherMinutes = 0;

  ActivitySplit get split => ActivitySplit(
    cardioMinutes: _cardioMinutes.toDouble(),
    strengthSets: _strengthSets.toDouble(),
    stretchingMinutes: _stretchingMinutes.toDouble(),
    otherMinutes: _otherMinutes.toDouble(),
  );

  void add(ClientExerciseDay d) {
    calories += d.calories;
    minutes += d.minutes;
    if (d.logged) loggedDays += 1;
    // 유형 분해가 없는 날은 전부 유산소로 본다 — 임의로 나누면 없는 근력을
    // 지어내는 셈이다.
    _cardioMinutes += d.hasTypeSplit ? d.cardioMinutes : d.minutes;
    _strengthSets += d.strengthSets;
    _stretchingMinutes += d.stretchingMinutes;
    _otherMinutes += d.otherMinutes;
  }

  /// `8/17 ~ 8/23` — 고른 칸이 덮는 기간.
  String rangeLabel(String locale) {
    final DateFormat f = DateFormat.Md(locale);
    final DateTime sunday = DateTime(monday.year, monday.month, monday.day + 6);
    return '${f.format(monday)} ~ ${f.format(sunday)}';
  }
}

/// 날짜별 기록을 주 단위로 묶는다(오래된 → 최근).
///
/// 첫 주는 기간이 주 가운데에서 시작해 잘려 있을 수 있다. 그래도 그 주의
/// 자리는 남긴다 — 없애면 달 경계가 한 칸씩 밀린다.
List<_WeekBucket> _weekBucketsOf(List<ClientExerciseDay> days) {
  final List<_WeekBucket> out = <_WeekBucket>[];
  for (final ClientExerciseDay d in days) {
    final DateTime monday = clientMondayOf(d.date);
    if (out.isEmpty || out.last.monday != monday) out.add(_WeekBucket(monday));
    out.last.add(d);
  }
  return out;
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
