import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

class TrainerDetailPage extends ConsumerWidget {
  const TrainerDetailPage({required this.gymId, super.key});

  /// Trainers do not have their own ID yet, so this is the owning gym's ID.
  final String gymId;

  Gym? _findGym(List<Gym> gyms) {
    for (final Gym gym in gyms) {
      if (gym.id == gymId) return gym;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<List<Gym>> nearbyAsync = ref.watch(nearbyGymsProvider);
    final AsyncValue<Gym?> myGymAsync = ref.watch(myGymProvider);

    final Gym? nearbyGym = switch (nearbyAsync) {
      AsyncData<List<Gym>>(:final value) => _findGym(value),
      _ => null,
    };
    final Gym? myGym = switch (myGymAsync) {
      AsyncData<Gym?>(:final value) when value?.id == gymId => value,
      _ => null,
    };
    final Gym? gym = nearbyGym ?? myGym;
    final bool hasTrainer = gym?.trainerName?.isNotEmpty ?? false;
    final Widget body;
    if (hasTrainer) {
      body = _TrainerDetails(gym: gym!);
    } else if (gym != null) {
      body = _StateMessage(message: l.exTrainerNotFound);
    } else if (nearbyAsync.isLoading || myGymAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator(strokeWidth: 3));
    } else if (nearbyAsync.hasError || myGymAsync.hasError) {
      body = _StateMessage(
        message: l.exTrainersLoadError,
        onRetry: () {
          ref.invalidate(nearbyGymsProvider);
          ref.invalidate(myGymProvider);
        },
      );
    } else {
      body = _StateMessage(message: l.exTrainerNotFound);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title: Text(
          l.exTrainerDetailTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: FigmaColors.ink,
          ),
        ),
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}

class _TrainerDetails extends StatelessWidget {
  const _TrainerDetails({required this.gym});

  final Gym gym;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: <Widget>[
            Center(
              child: Container(
                width: 86,
                height: 86,
                decoration: const BoxDecoration(
                  color: FigmaColors.iconTint,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.person_outline,
                  size: 40,
                  color: FigmaColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              gym.trainerName!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: FigmaColors.ink,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              gym.trainerRole ?? l.exTrainerDedicated,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: FigmaColors.textMuted,
              ),
            ),
            const SizedBox(height: 22),
            _DetailSection(
              icon: Icons.auto_awesome_outlined,
              title: l.exRecommendationReason,
              child: Text(
                l.exTrainerRecommendationReason,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: FigmaColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _DetailSection(
              icon: Icons.fitness_center,
              title: l.exTrainerAffiliation,
              padding: EdgeInsets.zero,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.push(AppRoutes.gymDetailPath(gym.id)),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: FigmaColors.primaryA(0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.fitness_center,
                            size: 21,
                            color: FigmaColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                gym.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: FigmaColors.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                gym.address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                  color: FigmaColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${gym.distanceKm.toStringAsFixed(1)}km',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: FigmaColors.textBody,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Icon(
                            Icons.chevron_right,
                            color: FigmaColors.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final IconData icon;
  final String title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FigmaColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 17, color: FigmaColors.primary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: FigmaColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: FigmaColors.hairline),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.info_outline,
              size: 34,
              color: FigmaColors.textFaint,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: FigmaColors.textMuted,
              ),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: Text(l.actionRetry)),
            ],
          ],
        ),
      ),
    );
  }
}
