import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:oncare/design_system/atoms/app_avatar.dart';
import 'package:oncare/design_system/atoms/app_badge.dart';
import 'package:oncare/design_system/atoms/app_button.dart';
import 'package:oncare/design_system/atoms/app_card.dart';
import 'package:oncare/design_system/atoms/app_input.dart';
import 'package:oncare/design_system/charts/app_bar_chart.dart';
import 'package:oncare/design_system/charts/app_donut_chart.dart';
import 'package:oncare/design_system/charts/app_line_chart.dart';
import 'package:oncare/design_system/molecules/chart_card.dart';
import 'package:oncare/design_system/molecules/metric_card.dart';
import 'package:oncare/design_system/molecules/section_header.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/radius.dart';
import 'package:oncare/design_system/tokens/spacing.dart';

/// Internal catalog of design tokens (and, after later phases, atoms /
/// molecules / charts). Registered only outside prod via `app_router.dart`.
class UiCatalogPage extends StatelessWidget {
  const UiCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UI Catalog (dev)')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const <Widget>[
          _SectionTitle('Brand & semantic colors'),
          _ColorGrid(<_Swatch>[
            _Swatch('primary', AppColors.primary),
            _Swatch('primaryContainer', AppColors.primaryContainer),
            _Swatch('secondary', AppColors.secondary),
            _Swatch('accent', AppColors.accent),
            _Swatch('success', AppColors.success),
            _Swatch('achievement', AppColors.achievement),
            _Swatch('warning', AppColors.warning),
            _Swatch('error', AppColors.error),
            _Swatch('info', AppColors.info),
          ]),
          SizedBox(height: AppSpacing.xl),

          _SectionTitle('Domain accents'),
          _ColorGrid(<_Swatch>[
            _Swatch('domainDiet', AppColors.primary),
            _Swatch('domainExercise', AppColors.primary),
            _Swatch('domainHealth', AppColors.primary),
            _Swatch('domainAiCoach', AppColors.primary),
          ]),
          SizedBox(height: AppSpacing.xl),

          _SectionTitle('Typography'),
          _TypographySample(),
          SizedBox(height: AppSpacing.xl),

          _SectionTitle('Spacing scale'),
          _SpacingScale(),
          SizedBox(height: AppSpacing.xl),

          _SectionTitle('Radius scale'),
          _RadiusScale(),
          SizedBox(height: AppSpacing.xl),

          _SectionTitle('Atoms — Buttons'),
          _ButtonGallery(),
          SizedBox(height: AppSpacing.xl),

          _SectionTitle('Atoms — Card / Input'),
          _CardAndInputSample(),
          SizedBox(height: AppSpacing.xl),

          _SectionTitle('Atoms — Badges'),
          _BadgeGallery(),
          SizedBox(height: AppSpacing.xl),

          _SectionTitle('Atoms — Avatars'),
          _AvatarGallery(),
          SizedBox(height: AppSpacing.xl),

          _SectionTitle('Molecules — MetricCard'),
          _MetricGallery(),
          SizedBox(height: AppSpacing.xl),

          _SectionTitle('Molecules — ChartCard + SectionHeader'),
          _ChartCardSample(),
          SizedBox(height: AppSpacing.xl),

          _SectionTitle('Charts — Line / Bar / Donut'),
          _ChartsGallery(),
        ],
      ),
    );
  }
}

class _ChartsGallery extends StatelessWidget {
  const _ChartsGallery();
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ChartCard(
          title: '체중 추이',
          height: 160,
          child: AppLineChart(
            color: AppColors.primary,
            spots: <FlSpot>[
              FlSpot(0, 70.4),
              FlSpot(1, 70.1),
              FlSpot(2, 69.8),
              FlSpot(3, 69.4),
              FlSpot(4, 69.0),
              FlSpot(5, 68.6),
              FlSpot(6, 68.2),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.md),
        ChartCard(
          title: '주간 운동 시간 (분)',
          child: AppBarChart(
            color: AppColors.primary,
            values: <double>[30, 0, 45, 20, 60, 35, 50],
            labels: <String>['월', '화', '수', '목', '금', '토', '일'],
          ),
        ),
        SizedBox(height: AppSpacing.md),
        ChartCard(
          title: '영양소 분포',
          child: AppDonutChart(
            segments: <AppDonutSegment>[
              AppDonutSegment(
                label: '탄수화물',
                value: 50,
                color: AppColors.primary,
              ),
              AppDonutSegment(
                label: '단백질',
                value: 25,
                color: AppColors.primary,
              ),
              AppDonutSegment(label: '지방', value: 25, color: AppColors.primary),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricGallery extends StatelessWidget {
  const _MetricGallery();
  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: <Widget>[
        SizedBox(
          width: 220,
          child: MetricCard(
            title: '오늘 칼로리',
            value: '1,420',
            unit: 'kcal',
            delta: '+12% vs 어제',
            deltaTone: MetricDeltaTone.positive,
            icon: Icons.restaurant,
            accentColor: AppColors.primary,
          ),
        ),
        SizedBox(
          width: 220,
          child: MetricCard(
            title: '운동 시간',
            value: '38',
            unit: '분',
            delta: '-5% vs 어제',
            deltaTone: MetricDeltaTone.negative,
            icon: Icons.fitness_center,
            accentColor: AppColors.primary,
          ),
        ),
        SizedBox(
          width: 220,
          child: MetricCard(
            title: '체중',
            value: '68.2',
            unit: 'kg',
            delta: '-0.3 vs 지난주',
            deltaTone: MetricDeltaTone.positive,
            icon: Icons.favorite_outline,
            accentColor: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _ChartCardSample extends StatelessWidget {
  const _ChartCardSample();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader('주간 요약'),
        ChartCard(
          title: 'Chart goes here',
          height: 160,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.all(AppRadius.md),
            ),
            child: const Center(child: Text('fl_chart widget (Phase 3.5)')),
          ),
        ),
      ],
    );
  }
}

class _ButtonGallery extends StatelessWidget {
  const _ButtonGallery();
  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        AppButton(label: 'Primary', onPressed: _noop),
        AppButton(
          label: 'Secondary',
          variant: AppButtonVariant.secondary,
          onPressed: _noop,
        ),
        AppButton(
          label: 'Ghost',
          variant: AppButtonVariant.ghost,
          onPressed: _noop,
        ),
        AppButton(label: 'With icon', icon: Icons.bolt, onPressed: _noop),
        AppButton(label: 'Disabled', onPressed: null),
      ],
    );
  }
}

void _noop() {}

class _CardAndInputSample extends StatelessWidget {
  const _CardAndInputSample();
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'AppCard surface',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppInput(label: 'Email', hint: 'you@example.com'),
          const SizedBox(height: AppSpacing.sm),
          const AppInput(
            label: 'Password',
            obscure: true,
            suffixIcon: Icons.visibility_off_outlined,
          ),
        ],
      ),
    );
  }
}

class _BadgeGallery extends StatelessWidget {
  const _BadgeGallery();
  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        AppBadge(label: 'Neutral'),
        AppBadge(label: 'Info', tone: AppBadgeTone.info),
        AppBadge(label: 'Success', tone: AppBadgeTone.success),
        AppBadge(label: 'Achievement', tone: AppBadgeTone.achievement),
        AppBadge(label: 'Warning', tone: AppBadgeTone.warning),
        AppBadge(label: 'Error', tone: AppBadgeTone.error),
      ],
    );
  }
}

class _AvatarGallery extends StatelessWidget {
  const _AvatarGallery();
  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: <Widget>[
        AppAvatar(label: 'Subin Lee'),
        AppAvatar(label: 'Demo User', size: 56),
        AppAvatar(label: 'Bot', size: 32),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _Swatch {
  const _Swatch(this.name, this.color);
  final String name;
  final Color color;
}

class _ColorGrid extends StatelessWidget {
  const _ColorGrid(this.swatches);
  final List<_Swatch> swatches;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: swatches.map((s) => _SwatchTile(s)).toList(),
    );
  }
}

class _SwatchTile extends StatelessWidget {
  const _SwatchTile(this.swatch);
  final _Swatch swatch;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: swatch.color,
              borderRadius: const BorderRadius.all(AppRadius.md),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(swatch.name, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _TypographySample extends StatelessWidget {
  const _TypographySample();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final samples = <(String, TextStyle?)>[
      ('displayLarge', t.displayLarge),
      ('displayMedium', t.displayMedium),
      ('titleLarge', t.titleLarge),
      ('titleMedium', t.titleMedium),
      ('bodyLarge', t.bodyLarge),
      ('bodyMedium', t.bodyMedium),
      ('labelLarge', t.labelLarge),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final s in samples)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text('${s.$1} — Oncare 헬스케어', style: s.$2),
          ),
      ],
    );
  }
}

class _SpacingScale extends StatelessWidget {
  const _SpacingScale();
  @override
  Widget build(BuildContext context) {
    const tokens = <(String, double)>[
      ('xxs (2)', AppSpacing.xxs),
      ('xs (4)', AppSpacing.xs),
      ('sm (8)', AppSpacing.sm),
      ('md (12)', AppSpacing.md),
      ('lg (16)', AppSpacing.lg),
      ('xl (24)', AppSpacing.xl),
      ('xxl (32)', AppSpacing.xxl),
      ('xxxl (48)', AppSpacing.xxxl),
    ];
    final color = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final t in tokens)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 100,
                  child: Text(
                    t.$1,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Container(width: t.$2, height: 16, color: color),
              ],
            ),
          ),
      ],
    );
  }
}

class _RadiusScale extends StatelessWidget {
  const _RadiusScale();
  @override
  Widget build(BuildContext context) {
    const tokens = <(String, Radius)>[
      ('xs (4)', AppRadius.xs),
      ('sm (8)', AppRadius.sm),
      ('md (12)', AppRadius.md),
      ('lg (16)', AppRadius.lg),
      ('xl (24)', AppRadius.xl),
      ('pill (999)', AppRadius.pill),
    ];
    final color = Theme.of(context).colorScheme.primary.withValues(alpha: 0.2);
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: <Widget>[
        for (final t in tokens)
          Column(
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.all(t.$2),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(t.$1, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
      ],
    );
  }
}
