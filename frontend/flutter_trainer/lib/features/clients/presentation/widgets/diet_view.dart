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
import 'package:oncare_trainer/features/clients/presentation/widgets/client_period_toggle.dart';
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
    // 토글은 카드의 **제목 줄**에 얹는다. 카드 위에 한 줄을 더 두면 고객 데이터
    // 열이 그만큼 길어져 화면 밖으로 밀린다.
    final Widget toggle = ClientPeriodToggle(
      active: _period,
      onChanged: (ClientPeriod p) => setState(() => _period = p),
    );

    if (_period != ClientPeriod.today) {
      return _wrap(<Widget>[
        ClientDietPeriodCard(
          clientId: client.id,
          period: _period,
          trailing: toggle,
        ),
      ]);
    }
    return _TodayDiet(client: client, toggle: toggle, wrap: _wrap);
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
  const _TodayDiet({
    required this.client,
    required this.toggle,
    required this.wrap,
  });

  final TrainerClient client;
  final Widget toggle;
  final Widget Function(List<Widget>) wrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final diet = ref.watch(clientDietProvider(client.id));

    return diet.when(
      // 로딩에도 토글을 같은 자리에 둔다. 탭에 처음 들어올 때 조작이 사라졌다가
      // 다시 나타나면, 트레이너가 누르려던 자리를 매번 다시 찾게 된다.
      loading: () => wrap(<Widget>[
        Align(alignment: Alignment.centerRight, child: toggle),
        const SizedBox(height: AppSpacing.xxl),
        const Center(child: CircularProgressIndicator()),
      ]),
      error: (e, _) => wrap(<Widget>[
        Align(alignment: Alignment.centerRight, child: toggle),
        const SizedBox(height: AppSpacing.sm),
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
      ]),
      data: (meals) => wrap(<Widget>[
        NutritionSummaryCard(client: client, trailing: toggle),
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
      ]),
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
