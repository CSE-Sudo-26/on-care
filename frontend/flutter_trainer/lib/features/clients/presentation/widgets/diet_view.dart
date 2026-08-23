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
import 'package:oncare_trainer/features/clients/presentation/widgets/client_ai_analysis_card.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_day_record_tile.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_diet_period_card.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_meal_photo.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_period_section.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/nutrition_summary_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
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
            // 그래프 아래 날짜별 기록. 그래프는 "얼마나" 를 말하지만 "그날
            // 무엇을" 은 말하지 않았고, 그걸 보려면 회원 앱으로 건너가야
            // 했다(#1025). 접힌 줄만 늘어놓고 누른 날만 펼치므로 전체(12주)
            // 에서도 스크롤이 감당한다.
            const SizedBox(height: AppSpacing.md),
            _DailyDietRecords(clientId: client.id, period: period),
            // 기간을 고르면 그 기간의 조언을 함께 읽는다 — 그래프만 바뀌고
            // 조언이 오늘 이야기로 남으면 화면과 무관한 말이 된다. (#1017)
            const SizedBox(height: AppSpacing.md),
            _AiComment(client: client, period: period),
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
              _AiComment(client: client, period: ClientPeriod.today),
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
                // 나트륨과 당류는 나란히 읽는 값이다 — 여기만 나트륨뿐이라
                // 끼니별 당류는 하루 합계로만 볼 수 있었다(#1025).
                Text(
                  '${l.dietSodiumValue(entry.sodiumMg)} · '
                  '${l.metricSugar} ${_grams(entry.sugarG)}g',
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

/// "✦ AI 분석" — 서버가 기간에 맞춰 만든 문장을 그대로 보여 준다. (#1017)
///
/// 예전에는 이 카드가 나트륨 목표만 보고 문구를 골랐다. 회원 앱은 서버 문장을
/// 쓰는데 여기만 따로 계산하면, 같은 회원의 같은 날을 두 화면이 다르게 말한다.
/// 서버 응답이 오기 전에는 지금까지 쓰던 문구를 그대로 둔다 — 카드가 비었다가
/// 채워지면 화면이 흔들린다.
class _AiComment extends ConsumerWidget {
  const _AiComment({required this.client, required this.period});

  final TrainerClient client;
  final ClientPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final over = client.sodiumOverBudget;
    final sodiumMg = client.sodiumMg;
    final String fallback = over
        ? l.dietAiOverSodium(sodiumMg - sodiumTargetMg)
        : l.dietAiBalanced;
    final String message =
        ref
            .watch(
              clientDietAdviceProvider((clientId: client.id, period: period)),
            )
            .valueOrNull ??
        fallback;
    // 카드 모양과 기간별 제목은 운동과 공유한다 — 같은 성격의 말이 두 화면에서
    // 다른 모양으로 읽히지 않도록(#1025).
    return ClientAiAnalysisCard(
      cardKey: const ValueKey<String>('diet-ai-analysis'),
      period: period,
      message: message,
    );
  }
}

/// 기간의 날짜별 식단 기록 — 눌러서 펼친다. (#1025)
///
/// 위 [ClientDietPeriodCard] 가 이미 읽어 둔 같은 기간 데이터를 다시 구독한다.
/// Riverpod 이 같은 키를 캐시하므로 요청이 한 번 더 나가지 않는다.
class _DailyDietRecords extends ConsumerStatefulWidget {
  const _DailyDietRecords({required this.clientId, required this.period});

  final String clientId;
  final ClientPeriod period;

  @override
  ConsumerState<_DailyDietRecords> createState() => _DailyDietRecordsState();
}

class _DailyDietRecordsState extends ConsumerState<_DailyDietRecords> {
  /// 펼쳐 둔 날. 하나만 연다 — 여럿을 펼치면 그래프가 화면 밖으로 밀린다.
  String? _openDay;

  @override
  void didUpdateWidget(_DailyDietRecords old) {
    super.didUpdateWidget(old);
    // 기간을 바꾸면 날짜 목록 자체가 달라진다. 열어 둔 날을 그대로 들고 가면
    // 새 목록에 없는 날을 가리킨 채 아무것도 펼쳐지지 않는다.
    if (old.period != widget.period || old.clientId != widget.clientId) {
      _openDay = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ClientPeriodKey key = clientPeriodKeyNow(
      widget.clientId,
      widget.period,
    );
    final AsyncValue<ClientDietPeriod> async = ref.watch(
      clientDietPeriodProvider(key),
    );
    return async.maybeWhen(
      data: (ClientDietPeriod period) => ClientDayRecordCard(
        key: const ValueKey<String>('diet-daily-records'),
        children: <Widget>[
          // 최근 날이 위다 — 트레이너가 먼저 궁금해하는 것은 어제와 오늘이다.
          for (final ClientDietDay day in period.days.reversed)
            ClientDayRecordTile(
              date: day.date,
              logged: day.logged,
              expanded: _openDay == ymd(day.date),
              onToggle: () => setState(() {
                _openDay = _openDay == ymd(day.date) ? null : ymd(day.date);
              }),
              emptyLabel: l.dietDayEmpty,
              // 펼친 날에만 그날 끼니를 읽는다 — 12주치를 미리 읽어 두면
              // 아무도 펼치지 않은 날까지 요청이 나간다.
              extra: _openDay == ymd(day.date) && day.logged
                  ? _DayMeals(clientId: widget.clientId, date: day.date)
                  : null,
              summary:
                  '${formatNumber(day.calories)} ${l.unitKcal} · '
                  '${l.dietSodiumValue(day.sodiumMg)}',
              details: <({String label, String value})>[
                (
                  label: l.metricCalories,
                  value: '${formatNumber(day.calories)} ${l.unitKcal}',
                ),
                (label: l.metricSodium, value: l.dietSodiumValue(day.sodiumMg)),
                (label: l.metricSugar, value: '${_grams(day.sugarG)}g'),
                if (day.hasMacros)
                  (
                    label: l.dietMacros,
                    value:
                        '${l.metricCarbs} ${_grams(day.carbsG)}g · '
                        '${l.metricProtein} ${_grams(day.proteinG)}g · '
                        '${l.metricFat} ${_grams(day.fatG)}g',
                  ),
              ],
            ),
        ],
      ),
      // 로딩·실패는 위 그래프 카드가 이미 말한다 — 같은 상태를 두 번 그리지
      // 않는다.
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// 펼친 날의 끼니 — 아침·점심·저녁·간식. (#1025)
///
/// 하루 합계는 위 상세가 이미 말한다. 여기서는 그 합계가 **무엇으로**
/// 이루어졌는지를 끼니 단위로 보여 준다.
class _DayMeals extends ConsumerWidget {
  const _DayMeals({required this.clientId, required this.date});

  final String clientId;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<List<ClientDietEntry>> async = ref.watch(
      clientDietOnProvider((clientId: clientId, date: date)),
    );
    return async.maybeWhen(
      data: (List<ClientDietEntry> meals) {
        // 하루 합계는 있는데 끼니가 안 오는 날이 있다 — 데모 픽스처가 끼니를
        // 들고 있는 날이 며칠뿐이라서다. 그럴 때는 아무 말도 하지 않는다:
        // 위 상세가 이미 그날의 합계를 말했다.
        if (meals.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            for (final ClientDietEntry meal in meals)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 끼니 이름은 알약이다 — 운동 기록 카드의 종류 알약과
                    // 같은 모양이라, 두 탭에서 같은 성격의 값이 같게 읽힌다.
                    _MealChip(label: meal.meal),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            meal.items,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              color: AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${formatNumber(meal.calories)} ${l.unitKcal} · '
                            '${l.dietSodiumValue(meal.sodiumMg)} · '
                            '${l.metricSugar} ${_grams(meal.sugarG)}g',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.subtleForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
      // 읽는 동안·실패했을 때는 위 상세만 남는다 — 펼친 자리가 흔들리지 않는다.
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// 끼니 이름 알약(아침·점심·저녁·간식).
///
/// 운동 기록 카드의 종류 알약과 같은 모양이다. 폭을 고정해 여러 끼니가
/// 세로로 설 때 음식 이름의 시작점이 가지런하다.
class _MealChip extends StatelessWidget {
  const _MealChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    width: 54,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(vertical: 4),
    decoration: const BoxDecoration(
      color: AppColors.accentSurface,
      borderRadius: BorderRadius.all(AppRadius.pill),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
    ),
  );
}
