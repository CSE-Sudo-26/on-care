import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/errors/app_error.dart';
import 'package:oncare/design_system/atoms/app_card.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/radius.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/error_view.dart';

/// Full-height sheet matching the prototype's "헬스장 찾기" flow:
/// a stylised map placeholder up top, then candidate gym cards each
/// with 상세보기 (detail dialog) + 등록하기 buttons.
Future<void> showGymFinderSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext ctx) {
      return const FractionallySizedBox(
        heightFactor: 0.92,
        child: _GymFinderBody(),
      );
    },
  );
}

class _GymFinderBody extends ConsumerWidget {
  const _GymFinderBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(nearbyGymsProvider);
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '헬스장 찾기',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.actionClose,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              data: (gyms) => _FinderList(gyms: gyms),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, _) => ErrorView(
                error: e is AppError ? e : UnknownError(message: e.toString()),
                onRetry: () => ref.invalidate(nearbyGymsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinderList extends StatelessWidget {
  const _FinderList({required this.gyms});
  final List<Gym> gyms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: <Widget>[
        Container(
          height: 160,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(AppRadius.card),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[AppColors.primary, AppColors.secondary],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.place, color: Colors.white, size: 32),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '지도 영역',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              Text(
                '주변 헬스장 ${gyms.length}곳',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final g in gyms) ...<Widget>[
          _GymCandidateCard(gym: g),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _GymCandidateCard extends StatelessWidget {
  const _GymCandidateCard({required this.gym});
  final Gym gym;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AppCard(
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            gym.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Text(
                '${gym.distanceKm.toStringAsFixed(1)}km',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.star, color: Color(0xFFF4A946), size: 14),
              const SizedBox(width: 2),
              Text(
                gym.rating.toStringAsFixed(1),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[for (final t in gym.tags) _TagChip(label: t)],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _PillButton(
                  label: l.exViewDetail,
                  tone: _PillTone.secondary,
                  onTap: () => _showGymDetail(context, gym),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _PillButton(
                  label: l.exRegister,
                  tone: _PillTone.primary,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.exGymRegistered(gym.name))),
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: const BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.all(AppRadius.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13.5,
          color: AppColors.accentForeground,
        ),
      ),
    );
  }
}

enum _PillTone { primary, secondary }

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.tone,
    required this.onTap,
  });
  final String label;
  final _PillTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = tone == _PillTone.primary ? AppColors.primary : AppColors.accent;
    final fg = tone == _PillTone.primary
        ? Colors.white
        : AppColors.accentForeground;
    return Material(
      color: bg,
      borderRadius: const BorderRadius.all(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Center(
            child: Text(
              label,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showGymDetail(BuildContext context, Gym gym) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext ctx) {
      return _GymDetailDialog(gym: gym);
    },
  );
}

class _GymDetailDialog extends StatelessWidget {
  const _GymDetailDialog({required this.gym});
  final Gym gym;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    gym.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.actionClose,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: AppColors.mutedForeground,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(gym.address, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                const Icon(Icons.star, color: Color(0xFFF4A946), size: 14),
                const SizedBox(width: 4),
                Text(
                  '평점: ${gym.rating.toStringAsFixed(1)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (gym.weekdayHours != null ||
                gym.weekendHours != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                '운영 시간',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              if (gym.weekdayHours != null)
                Text(
                  '평일: ${gym.weekdayHours}',
                  style: theme.textTheme.bodySmall,
                ),
              if (gym.weekendHours != null)
                Text(
                  '주말: ${gym.weekendHours}',
                  style: theme.textTheme.bodySmall,
                ),
            ],
            if (gym.phone != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                '연락처',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              Text(gym.phone!, style: theme.textTheme.bodySmall),
            ],
            if (gym.trainerName != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                '전담 트레이너',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              Text(gym.trainerName!, style: theme.textTheme.bodySmall),
            ],
            if (gym.tags.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                '전문 분야',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final t in gym.tags) _TagChip(label: t),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(AppRadius.lg),
                  ),
                ),
                child: Text(l.actionClose),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
