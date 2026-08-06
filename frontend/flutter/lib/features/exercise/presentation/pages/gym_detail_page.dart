import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/presentation/controllers/consultation_request_controller.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

class GymDetailPage extends ConsumerWidget {
  const GymDetailPage({required this.gymId, super.key});

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
    final List<ConsultationRequest> requests = ref.watch(
      consultationRequestControllerProvider,
    );

    final Gym? nearbyGym = switch (nearbyAsync) {
      AsyncData<List<Gym>>(:final value) => _findGym(value),
      _ => null,
    };
    final Gym? myGym = switch (myGymAsync) {
      AsyncData<Gym?>(:final value) when value?.id == gymId => value,
      _ => null,
    };
    final Gym? gym = nearbyGym ?? myGym;
    final Widget body;
    if (gym != null) {
      final bool hasPending = requests.any(
        (ConsultationRequest request) =>
            request.targetType == ConsultationTargetType.gym &&
            request.gymId == gym.id &&
            request.status == ConsultationStatus.pending,
      );
      body = _GymDetails(
        gym: gym,
        hasPending: hasPending,
        isMyGym: myGym != null,
      );
    } else if (nearbyAsync.isLoading || myGymAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator(strokeWidth: 3));
    } else if (nearbyAsync.hasError || myGymAsync.hasError) {
      body = _StateMessage(
        message: l.exGymsLoadError,
        onRetry: () {
          ref.invalidate(nearbyGymsProvider);
          ref.invalidate(myGymProvider);
        },
      );
    } else {
      body = _StateMessage(message: l.exGymNotFound);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title: Text(
          l.exGymDetailTitle,
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

class _GymDetails extends StatelessWidget {
  const _GymDetails({
    required this.gym,
    required this.hasPending,
    required this.isMyGym,
  });

  final Gym gym;
  final bool hasPending;
  final bool isMyGym;

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
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: FigmaColors.primaryA(0.10),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.fitness_center,
                  size: 36,
                  color: FigmaColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              gym.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: FigmaColors.ink,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricCard(
                    icon: Icons.place_outlined,
                    label: l.exDistance,
                    value: '${gym.distanceKm.toStringAsFixed(1)}km',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.star_rounded,
                    label: l.exRating,
                    value: gym.rating.toStringAsFixed(1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _DetailSection(
              icon: Icons.place_outlined,
              title: l.exAddress,
              child: Text(
                gym.address,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: FigmaColors.textBody,
                ),
              ),
            ),
            if (gym.tags.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _DetailSection(
                icon: Icons.fitness_center,
                title: l.exSpecialty,
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: <Widget>[
                    for (final String tag in gym.tags) _TagChip(label: tag),
                  ],
                ),
              ),
            ],
            if (gym.weekdayHours != null ||
                gym.weekendHours != null) ...<Widget>[
              const SizedBox(height: 12),
              _DetailSection(
                icon: Icons.schedule_outlined,
                title: l.exHours,
                child: Column(
                  children: <Widget>[
                    if (gym.weekdayHours != null)
                      _InfoLine(text: l.exGymWeekdayHours(gym.weekdayHours!)),
                    if (gym.weekendHours != null)
                      _InfoLine(text: l.exGymWeekendHours(gym.weekendHours!)),
                  ],
                ),
              ),
            ],
            if (gym.phone != null) ...<Widget>[
              const SizedBox(height: 12),
              _DetailSection(
                icon: Icons.call_outlined,
                title: l.exPhone,
                child: Text(
                  gym.phone!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.textBody,
                  ),
                ),
              ),
            ],
            if (gym.trainerName?.isNotEmpty ?? false) ...<Widget>[
              const SizedBox(height: 12),
              _DetailSection(
                icon: Icons.person_outline,
                title: l.exAffiliatedTrainer,
                padding: EdgeInsets.zero,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () =>
                        context.push(AppRoutes.trainerDetailPath(gym.id)),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              color: FigmaColors.iconTint,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.person_outline,
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
                                  gym.trainerName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: FigmaColors.ink,
                                  ),
                                ),
                                if (gym.trainerRole != null) ...<Widget>[
                                  const SizedBox(height: 2),
                                  Text(
                                    gym.trainerRole!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: FigmaColors.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: FigmaColors.textFaint,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (!isMyGym) ...<Widget>[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: hasPending
                    ? null
                    : () => context.push(
                        AppRoutes.consultationRequestPath(
                          targetType: ConsultationTargetType.gym.name,
                          gymId: gym.id,
                        ),
                      ),
                style: FilledButton.styleFrom(
                  backgroundColor: FigmaColors.primary,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  hasPending ? l.exConsultPendingCta : l.exGymConsultRequest,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: FigmaColors.softBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FigmaColors.hairline),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 19, color: FigmaColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: FigmaColors.textMuted,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: FigmaColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
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

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: FigmaColors.textBody,
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: FigmaColors.primaryA(0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: FigmaColors.primary,
        ),
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
