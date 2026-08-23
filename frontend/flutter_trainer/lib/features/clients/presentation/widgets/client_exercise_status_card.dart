import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
import 'package:oncare_trainer/features/clients/domain/entities/routine_history_entry.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/exercise_burn_goals.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/activity_charts.dart';
import 'package:oncare_trainer/shared/widgets/exercise_line.dart';
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
///
/// `clientName` 을 주면 그래프 아래에 **상세 운동 내역**(종목별 완료 여부)이
/// 붙는다(#1027).
class ClientExerciseStatusCard extends ConsumerWidget {
  /// Creates the card for [clientId] over [period].
  const ClientExerciseStatusCard({
    super.key,
    required this.clientId,
    required this.period,
    this.clientName,
  });

  final String clientId;
  final ClientPeriod period;

  /// 값을 주면(빈 문자열이 아니어도 됨 — 실제로는 opt-in 스위치) 그래프 아래에
  /// **상세 운동 내역**이 함께 붙는다. 그래프는 "얼마나 오래" 만 말해서, 다음
  /// 프로그램을 짤 때 정작 필요한 "무엇을 몇 세트" 가 화면 밖에 있었다(#1027).
  ///
  /// 상세 내역은 고객 탭 `운동 기록`(`clientHistoryProvider`)과 같은 자료다.
  /// 고객 탭은 같은 화면에 `운동 기록` 카드가 이미 있으므로 이 파라미터를
  /// 주지 않는다 — 한 화면에서 같은 목록을 두 번 읽게 하지 않는다.
  final String? clientName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ClientPeriodKey key = clientPeriodKeyNow(clientId, period);
    final AsyncValue<ClientExercisePeriod> async = ref.watch(
      clientExercisePeriodProvider(key),
    );
    final String? name = clientName;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          async.when(
            loading: () => const SizedBox(
              height: 170,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => EmptyHint(
              message: l.clientTrendLoadFailed,
              action: ActionButton(
                key: const ValueKey<String>('weekly-exercise-retry'),
                label: l.actionRetry,
                onPressed: () =>
                    ref.invalidate(clientExercisePeriodProvider(key)),
              ),
            ),
            data: (ClientExercisePeriod data) => period == ClientPeriod.today
                ? _Today(clientId: clientId, period: data)
                : _Range(period: data),
          ),
          if (name != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.md),
            _WorkoutDetail(clientId: clientId),
          ],
        ],
      ),
    );
  }
}

/// 고객 탭 `운동 기록`(`WorkoutView`)과 **같은 자료**를 그래프 아래에 붙인다.
/// (#1027 팔로업)
///
/// 처음에는 스케줄에 붙은 PT 세션(`clientSessionsProvider`)을 그래프와 같은
/// 기간으로 걸러 보여줬다. 그런데 그 세션은 트레이너가 예약한 슬롯일 뿐이고,
/// 고객 탭이 "운동 기록"이라 부르는 것은 완료율·피드백까지 포함한 별개의
/// 이력(`clientHistoryProvider`)이다 — 데모에서는 전자가 하루치뿐이라 두 탭이
/// 같은 고객을 보고도 다른 개수를 말했다. 같은 이름을 쓰는 이상 같은 자료를
/// 봐야 하므로 소스를 맞춘다.
///
/// 이 이력에는 믿을 만한 날짜 필드가 없어(`dateLabel` 은 표시용 문자열) 그래프
/// 처럼 기간으로 거를 수 없다 — 고객 탭의 `운동 기록` 도 같은 이유로 기간과
/// 무관하게 전체를 보여준다. 대신 접힌 기본 상태에서는 가장 최근 기록 하나만
/// 보이고, 아래 캐럿을 누르면 전체 이력으로 펼쳐진다.
class _WorkoutDetail extends ConsumerStatefulWidget {
  const _WorkoutDetail({required this.clientId});

  final String clientId;

  @override
  ConsumerState<_WorkoutDetail> createState() => _WorkoutDetailState();
}

class _WorkoutDetailState extends ConsumerState<_WorkoutDetail> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<List<RoutineHistoryEntry>> async = ref.watch(
      clientHistoryProvider(widget.clientId),
    );
    return Column(
      key: const ValueKey<String>('client-exercise-detail'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          l.workoutRecords,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.subtleForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, _) => EmptyHint(message: l.workoutLoadFailed),
          data: (List<RoutineHistoryEntry> entries) {
            if (entries.isEmpty) {
              return EmptyHint(
                message: l.workoutEmpty,
                icon: Icons.fitness_center_outlined,
              );
            }
            final bool canExpand = entries.length > 1;
            // 이력은 이미 최신순이다(`clientHistoryProvider`) — 접힌 상태의
            // 첫 항목이 곧 가장 최근 기록이다.
            final List<RoutineHistoryEntry> shown = _expanded
                ? entries
                : entries.take(1).toList(growable: false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final RoutineHistoryEntry entry in shown)
                  _DetailEntry(entry: entry),
                if (canExpand)
                  _ExpandToggle(
                    expanded: _expanded,
                    onTap: () => setState(() => _expanded = !_expanded),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// 상세 내역을 펼치고 접는 캐럿. 접혔을 땐 늘 아래(더 볼 게 있다)를,
/// 펼치면 위(접을 수 있다)를 가리킨다 — 화살표 방향 자체가 상태를 말해서
/// 옆에 적힌 글자를 안 읽어도 무엇을 누르는지 알 수 있다.
class _ExpandToggle extends StatelessWidget {
  const _ExpandToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String label = expanded
        ? l.workoutRecordsShowLess
        : l.workoutRecordsShowMore;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: InkWell(
        key: const ValueKey<String>('client-exercise-detail-toggle'),
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 이력 한 건 — 날짜·종류, 몇 개 중 몇 개를 했는지, 그리고 `ExerciseLine`
/// 으로 그리는 종목별 수행 여부. 고객 탭 `_HistoryCard` 와 같은 자료를 쓰되,
/// 사이드바 폭에 맞춰 완료율 도넛·피드백·트레이너 메모는 뺀 압축판이다 —
/// 그 편집 동작은 고객 탭에만 있고, 여긴 그래프 옆 참고 자료다.
class _DetailEntry extends StatelessWidget {
  const _DetailEntry({required this.entry});

  final RoutineHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final int done = entry.exercises
        .where((String line) => !line.contains('✗'))
        .length;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${entry.dateLabel} · ${entry.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              if (entry.exercises.isNotEmpty)
                Text(
                  l.workoutDoneOfTotal(entry.exercises.length, done),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.subtleForeground,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          for (final String line in entry.exercises)
            ExerciseLine(line: line, fontSize: 11.5),
        ],
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
    // 좌우를 세로보다 넉넉하게 둔다 — 회원 앱과 같은 여백이라 도넛과 상세
    // 묶음이 카드 양 끝에 붙지 않는다. (#1151)
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.xl,
      vertical: AppSpacing.md,
    ),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: const BorderRadius.all(AppRadius.card),
      boxShadow: kCardShadow,
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

/// 세 기간이 함께 쓰는 그래프 자리. 높이를 같게 두어야 토글을 눌러도 카드가
/// 커졌다 작아지지 않는다 — 그 아래 기록 목록이 그때마다 뛴다.
///
/// 글자 배율을 따라간다. 배율만 커지면 고정 높이 안에서 내용이 넘친다.
class _ChartSlot extends StatelessWidget {
  const _ChartSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    height:
        kActivityCardHeight *
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
    child: child,
  );
}

class _Today extends ConsumerWidget {
  const _Today({required this.clientId, required this.period});

  final String clientId;
  final ClientExercisePeriod period;

  /// 이번 주 안에서 **활동한 날의 최장 연속 구간**. 회원 앱 `week.streakDays`
  /// 와 같은 규칙이다(#1168) — 오늘 하루만 읽어서는 알 수 없어 같은 주를 함께
  /// 본다. 이번 주는 기간 토글이 어차피 읽는 값이라 Riverpod 캐시를 나눠 쓴다.
  int _streakOf(WidgetRef ref) {
    final ClientExercisePeriod? week = ref
        .watch(
          clientExercisePeriodProvider(
            clientPeriodKeyNow(clientId, ClientPeriod.week),
          ),
        )
        .valueOrNull;
    if (week == null) return 0;
    int best = 0;
    int run = 0;
    for (final ClientExerciseDay d in week.days) {
      if (d.logged) {
        run += 1;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    if (period.isEmpty) {
      return _ChartSlot(
        child: Center(
          child: EmptyHint(
            message: l.clientTrendTodayEmpty,
            icon: Icons.fitness_center_outlined,
          ),
        ),
      );
    }
    // 유형 분해가 없으면 전부 유산소로 본다. 임의로 나누면 없는 근력 시간을
    // 지어내는 셈이다.
    final bool split = period.days.any((ClientExerciseDay d) => d.hasTypeSplit);
    return _ChartSlot(
      child: BurnDonut(
        title: l.exBurnTodayTitle,
        calories: period.totalCalories,
        goal: kDailyBurnKcal,
        streakDays: _streakOf(ref),
        split: ActivitySplit(
          cardioMinutes: split
              ? period.totalCardioMinutes
              : period.totalMinutes,
          strengthSets: split ? period.totalStrengthSets : 0,
          stretchingMinutes: split ? period.totalStretchingMinutes : 0,
          otherMinutes: period.totalOtherMinutes,
        ),
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
  /// `전체` 그래프의 스크롤 위치와 고른 칸. 머리의 숫자가 이걸 따라간다 —
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
    final bool all = days.length > 10;

    // `이번 주` 는 유형별 주간 목표를 채우는 3중 링이다 — 회원 앱과 같다.
    if (!all) {
      final bool split = days.any((ClientExerciseDay d) => d.hasTypeSplit);
      return _ChartSlot(
        child: BurnGoalRings(
          title: l.exBurnWeekTitle,
          calories: period.totalCalories,
          split: ActivitySplit(
            cardioMinutes: split
                ? period.totalCardioMinutes
                : period.totalMinutes,
            strengthSets: split ? period.totalStrengthSets : 0,
            stretchingMinutes: split ? period.totalStretchingMinutes : 0,
            otherMinutes: period.totalOtherMinutes,
          ),
        ),
      );
    }

    // `전체` 는 **한 칸이 한 주**다. 회원 앱 운동 탭과 같은 눈금이라야 둘이
    // 같은 그림을 보고 이야기할 수 있다 — 일별 막대는 여덟 달을 늘어놓으면
    // 실오라기가 되고, 한 주를 잘한 것인지 한 날을 잘한 것인지도 흐려진다.
    // (#1077)
    final List<_WeekBucket> weeks = _weekBucketsOf(days);
    return _ChartSlot(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ListenableBuilder(
            listenable: _selection,
            builder: (BuildContext context, Widget? _) {
              final int? picked = _selection.selected;
              final _WeekBucket? week = picked == null ? null : weeks[picked];
              final (int first, int last) =
                  _selection.visible ?? (0, weeks.length - 1);
              final List<_WeekBucket> visible = weeks.sublist(
                first.clamp(0, weeks.length - 1),
                (last + 1).clamp(1, weeks.length),
              );
              // 고른 주가 없으면 **지금 보이는 구간의 주 평균**이다. 여덟 달을
              // 통째로 평균 내면 어느 달을 보고 있든 같은 숫자라, 그래프를 미는
              // 의미가 없다. (#1018)
              final double value =
                  week?.calories.toDouble() ??
                  (visible.isEmpty
                      ? 0
                      : visible.fold<int>(
                              0,
                              (int a, _WeekBucket w) => a + w.calories,
                            ) /
                            visible.length);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 6,
                    child: ActivityHeadlineLine(
                      caption: week == null
                          ? l.exBurnAllTitle
                          : l.exWeekOfMonthLabel(
                              week.monday.month,
                              _weekOfMonth(week.monday),
                            ),
                      value: activityValueOfGoal(locale, value, kWeeklyBurnKcal),
                      unit: l.unitKcal,
                    ),
                  ),
                  // 고른 주의 내역은 kcal **오른쪽**에 붙는다 (#1129) — 그래프
                  // 아래에 따로 두면 구분선까지 필요해져 카드가 셋으로 갈린다.
                  if (week != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          for (final ExerciseKind kind in ExerciseKind.values)
                            _DetailLine(
                              text:
                                  '${kindLabel(l, kind)} '
                                  '${kindValueText(l, kind, week.split.valueOf(kind))}',
                            ),
                          if (week.split.otherMinutes > 0)
                            _DetailLine(
                              text:
                                  '${l.exTypeOther} '
                                  '${l.minutesShort(week.split.otherMinutes.round())}',
                            ),
                        ],
                      ),
                    ),
                  ] else if (visible.isNotEmpty) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    // 평균이 어느 구간의 것인지 숫자만으로는 알 수 없다 — 밀
                    // 때마다 바뀌는 값이라 기간을 옆에 붙여 둔다.
                    Expanded(
                      flex: 4,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${DateFormat.Md(locale).format(visible.first.monday)}'
                          ' ~ '
                          '${DateFormat.Md(locale).format(_sundayOf(visible.last.monday))}',
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) => BurnBarChart(
                title: l.clientTrendTitle,
                selection: _selection,
                goalKcal: kWeeklyBurnKcal,
                // 막대 영역만의 높이다 — 아래 날짜 라벨 줄은 따로 자리를
                // 차지한다.
                height: math.max(
                  c.maxHeight - kBurnBarChartExtraHeight,
                  40,
                ),
                calories: <int>[for (final _WeekBucket w in weeks) w.calories],
                splits: <ActivitySplit>[
                  for (final _WeekBucket w in weeks) w.split,
                ],
                dates: <DateTime>[for (final _WeekBucket w in weeks) w.monday],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 고른 주의 유형별 내역 한 줄 — `유산소 195분`. 색 네모 없이 글자만 쓴다
/// (#1129) — 색은 바로 옆 막대가 이미 말하고 있다.
class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 1),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(
        text,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.mutedForeground,
        ),
      ),
    ),
  );
}

/// 그 달의 몇 번째 주인지 — `8월 1주차` 의 1.
int _weekOfMonth(DateTime monday) => ((monday.day - 1) ~/ 7) + 1;

DateTime _sundayOf(DateTime monday) =>
    DateTime(monday.year, monday.month, monday.day + 6);

/// `전체` 그래프의 한 칸 — 한 주(월~일)의 합계.
class _WeekBucket {
  _WeekBucket(this.monday);

  final DateTime monday;
  int calories = 0;

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
    // 유형 분해가 없는 날은 전부 유산소로 본다 — 임의로 나누면 없는 근력을
    // 지어내는 셈이다.
    _cardioMinutes += d.hasTypeSplit ? d.cardioMinutes : d.minutes;
    _strengthSets += d.strengthSets;
    _stretchingMinutes += d.stretchingMinutes;
    _otherMinutes += d.otherMinutes;
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
