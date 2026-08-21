import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/core/utils/number_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_diet_entry.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_diet_period_card.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_meal_photo.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_period_section.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/nutrition_summary_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/icon_label.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart' show EmptyHint;

/// The 식단 sub-tab: `오늘 / 이번 주 / 이번 달` over the client's nutrition.
///
/// `오늘` 은 예전 그대로다 — 영양 요약 카드, 끼니 기록, AI 코멘트. 기간을
/// 고르면 그 자리가 일별 영양 추이로 바뀐다(#914). 회원은 자기 앱에서 이미 세
/// 기간을 골라 보는데, 정작 코칭하는 트레이너는 오늘 하루밖에 못 봤다.
class DietView extends ConsumerStatefulWidget {
  /// Creates the diet view for [client].
  const DietView({super.key, required this.client, this.embedded = false});

  /// The client whose diet is shown (carries today's totals).
  final TrainerClient client;

  /// When true, lets the member detail own the single page scroll.
  final bool embedded;

  @override
  ConsumerState<DietView> createState() => _DietViewState();
}

class _DietViewState extends ConsumerState<DietView> {
  /// 기본은 **오늘** — 지금까지 보던 화면이 그대로 첫 화면이다.
  ClientPeriod _period = ClientPeriod.today;

  @override
  Widget build(BuildContext context) {
    final TrainerClient client = widget.client;
    final AppLocalizations l = AppLocalizations.of(context);
    // 이름과 토글은 카드 밖 섹션 헤더가 든다 — 운동 탭과 같은 모양이다(#944).
    Widget section(Widget child) => _wrap(<Widget>[
      ClientPeriodSection(
        icon: Icons.restaurant_outlined,
        title: l.clientNutritionSummary,
        period: _period,
        onChanged: (ClientPeriod p) => setState(() => _period = p),
        child: child,
      ),
    ]);

    if (_period != ClientPeriod.today) {
      final ClientPeriod period = _period;
      return section(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ClientDietPeriodCard(clientId: client.id, period: period),
            // 이번 주만 — 요일별로 그날 기록을 바로 확인할 수 있게 카드를
            // 덧붙인다. 지금까지는 주간 그래프만 있어 "그날 뭘 먹었는지"를
            // 보려면 회원 앱으로 건너가야 했다(#1025). 전체(84일)까지 카드로
            // 늘어놓으면 스크롤이 감당 못 하므로 한 주만이다.
            if (period == ClientPeriod.week) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _WeekDailyCards(clientId: client.id),
            ],
            const SizedBox(height: AppSpacing.md),
            // 이번 주/전체에서도 AI 코멘트 자리가 사라지지 않는다(#1025). 다만
            // 기간별 조언 **문구·집계 정책**은 #1017 이 정할 몫이라, 여기서는
            // 그 정책을 앞질러 짓지 않고 위 카드가 이미 계산해 둔 값만
            // 사실 그대로 요약한다.
            _PeriodDietSummary(clientId: client.id, period: period),
          ],
        ),
      );
    }
    return _TodayDiet(client: client, section: section);
  }

  Widget _wrap(List<Widget> children) {
    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: children,
    );
  }
}

/// 오늘 하루: 영양 요약 + 끼니 기록 + AI 코멘트.
class _TodayDiet extends ConsumerWidget {
  const _TodayDiet({required this.client, required this.section});

  final TrainerClient client;

  /// 섹션 헤더로 감싸 페이지에 얹는 함수. 헤더는 기간·로딩·실패와 무관하게 늘
  /// 같은 자리에 있어야 한다.
  final Widget Function(Widget) section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final diet = ref.watch(clientDietProvider(client.id));

    // 로딩·실패에도 헤더는 같은 자리에 있다. 탭에 처음 들어올 때 조작이
    // 사라졌다가 다시 나타나면, 트레이너가 누르려던 자리를 매번 다시 찾게 된다.
    return diet.when(
      loading: () => section(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => section(
        EmptyHint(
          message: l.dietLoadFailed,
          icon: Icons.error_outline,
          action: ActionButton(
            key: ValueKey<String>('diet-retry-${client.id}'),
            label: l.actionRetry,
            onPressed: diet.isLoading
                ? null
                : () => ref.invalidate(clientDietProvider(client.id)),
          ),
        ),
      ),
      data: (meals) => section(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            NutritionSummaryCard(client: client),
            const SizedBox(height: AppSpacing.md),
            // Nothing logged yet: say so, and withhold the verdict. The
            // summary tiles read 0 either way, and `_AiComment` would call
            // a blank day "균형이 잘 맞아요" — praise for a member who has
            // not recorded a single meal.
            if (meals.isEmpty)
              EmptyHint(message: l.dietEmpty, icon: Icons.restaurant_outlined)
            else ...<Widget>[
              for (final meal in meals) ...<Widget>[
                _MealCard(entry: meal),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.xs),
              _AiComment(client: client),
            ],
          ],
        ),
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.entry});

  final ClientDietEntry entry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 회원이 올린 사진. 없으면 아무것도 그리지 않아 기존 카드 그대로다. (#699)
          if (entry.photoUrl case final String path) ...<Widget>[
            ClientMealPhoto(path: path),
            const SizedBox(width: AppSpacing.md),
          ]
          // 데모에는 사진을 받아 올 백엔드가 없어 시드가 번들 이미지를
          // 가리킨다. 실 API 모드에서는 위의 경로만 쓰인다(#819).
          else if (entry.photoAsset case final String asset) ...<Widget>[
            ClipRRect(
              borderRadius: const BorderRadius.all(AppRadius.card),
              child: Image.asset(
                asset,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                // 자산이 빠져도 끼니 카드는 그대로 읽혀야 한다.
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.accentSurface,
                        borderRadius: BorderRadius.all(AppRadius.pill),
                      ),
                      child: Text(
                        entry.meal,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${entry.calories} kcal',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.items,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.dietSodiumValue(entry.sodiumMg),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.subtleForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    Text('${l.metricCarbs} ${_grams(entry.carbsG)}g'),
                    Text('${l.metricProtein} ${_grams(entry.proteinG)}g'),
                    Text('${l.metricFat} ${_grams(entry.fatG)}g'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _grams(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

/// "✦ AI 분석" comment — flips wording on the sodium target.
class _AiComment extends StatelessWidget {
  const _AiComment({required this.client});

  final TrainerClient client;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final over = client.sodiumOverBudget;
    final sodiumMg = client.sodiumMg;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accentSurface,
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconLabel(
            icon: Icons.auto_awesome,
            label: l.dietAiAnalysis,
            color: AppColors.accent,
            fontSize: 11,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            over
                ? l.dietAiOverSodium(sodiumMg - sodiumTargetMg)
                : l.dietAiBalanced,
            style: const TextStyle(
              fontSize: 13,
              height: 1.55,
              fontWeight: FontWeight.w500,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// 이번 주 날짜별 기록 카드 — 요일마다 그날의 식단을 바로 확인한다(#1025).
///
/// 위 [ClientDietPeriodCard] 가 이미 읽어 둔 같은 기간 데이터를 다시
/// 구독한다. Riverpod 이 같은 키를 캐시하므로 요청이 한 번 더 나가지
/// 않는다 — 카드 하나를 위해 위젯 트리를 다시 짤 필요가 없다.
class _WeekDailyCards extends ConsumerWidget {
  const _WeekDailyCards({required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ClientPeriodKey key = clientPeriodKeyNow(clientId, ClientPeriod.week);
    final AsyncValue<ClientDietPeriod> async = ref.watch(
      clientDietPeriodProvider(key),
    );
    return async.maybeWhen(
      data: (ClientDietPeriod period) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final ClientDietDay day in period.days) ...<Widget>[
            _DietDayCard(day: day),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
      // 로딩·실패는 위 그래프 카드가 이미 말한다 — 같은 상태를 두 번 그리지
      // 않는다.
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// 하루치 기록 한 장. 기록이 없으면 빈 날임을 그대로 말한다 — 0으로 채우면
/// "적지 않은 날"이 "0kcal 먹은 날"이 된다.
class _DietDayCard extends StatelessWidget {
  const _DietDayCard({required this.day});

  final ClientDietDay day;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      key: ValueKey<String>('diet-day-card-${ymd(day.date)}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(
              dateLabel(l, day.date),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ),
          Expanded(
            child: day.logged
                ? Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      Text(
                        '${formatNumber(day.calories)} ${l.unitKcal}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dietChart,
                        ),
                      ),
                      Text(
                        l.dietSodiumValue(day.sodiumMg),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.subtleForeground,
                        ),
                      ),
                      Text(
                        '${l.metricSugar} ${_grams(day.sugarG)}g',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.subtleForeground,
                        ),
                      ),
                      if (day.hasMacros)
                        Text(
                          '${l.metricCarbs} ${_grams(day.carbsG)}g · '
                          '${l.metricProtein} ${_grams(day.proteinG)}g · '
                          '${l.metricFat} ${_grams(day.fatG)}g',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                    ],
                  )
                : Text(
                    l.chartNoRecord,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.disabledForeground,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 이번 주/전체를 골랐을 때의 AI 코멘트 자리 — 사라지지 않고 무언가를
/// 보여준다(#1025).
///
/// **AI 가 지어낸 조언이 아니다.** 위 기간 카드가 이미 계산해 둔 평균·초과
/// 일수를 그대로 요약한다. 기간별 AI 조언의 문구·집계 정책은 #1017 이 정할
/// 몫이라 여기서 앞질러 짓지 않는다 — 이 카드는 그 정책이 정해지기 전까지
/// 자리가 비어 있지 않도록만 잇는다.
class _PeriodDietSummary extends ConsumerWidget {
  const _PeriodDietSummary({required this.clientId, required this.period});

  final String clientId;
  final ClientPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ClientPeriodKey key = clientPeriodKeyNow(clientId, period);
    final AsyncValue<ClientDietPeriod> async = ref.watch(
      clientDietPeriodProvider(key),
    );
    return async.maybeWhen(
      data: (ClientDietPeriod p) {
        // 기록이 없으면 위 그래프 카드가 이미 "이 기간에 기록이 없어요"를
        // 말한다 — 같은 뜻을 여기서 다시 말하지 않는다.
        if (p.isEmpty) return const SizedBox.shrink();
        final int overSodiumDays = p.days
            .where((ClientDietDay d) => d.logged && d.sodiumMg > sodiumTargetMg)
            .length;
        final int overSugarDays = p.days
            .where((ClientDietDay d) => d.logged && d.sugarG > sugarTargetG)
            .length;
        return Container(
          key: const ValueKey<String>('diet-period-summary'),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.accentSurface,
            borderRadius: const BorderRadius.all(AppRadius.card),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconLabel(
                icon: Icons.insights_outlined,
                label: l.dietPeriodSummaryTitle,
                color: AppColors.accent,
                fontSize: 11,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l.dietPeriodSummaryLogged(
                  p.loggedDays,
                  formatNumber(p.avgCalories),
                ),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                  color: AppColors.foreground,
                ),
              ),
              if (overSodiumDays > 0 || overSugarDays > 0) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  l.dietPeriodSummaryOverBudget(overSodiumDays, overSugarDays),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                    color: AppColors.overTarget,
                  ),
                ),
              ],
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
