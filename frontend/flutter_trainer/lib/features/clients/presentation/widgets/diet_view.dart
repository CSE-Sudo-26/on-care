import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      return section(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ClientDietPeriodCard(clientId: client.id, period: _period),
            // 기간을 고르면 그 기간의 조언을 함께 읽는다 — 그래프만 바뀌고
            // 조언이 오늘 이야기로 남으면 화면과 무관한 말이 된다. (#1017)
            const SizedBox(height: AppSpacing.md),
            _AiComment(client: client, period: _period),
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
            message,
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
