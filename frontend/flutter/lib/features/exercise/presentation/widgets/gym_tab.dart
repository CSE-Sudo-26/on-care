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

class GymTab extends ConsumerWidget {
  const GymTab({
    required this.selectedSlot,
    required this.onSlot,
    required this.onFind,
    super.key,
  });

  final String? selectedSlot;
  final ValueChanged<String> onSlot;
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<Gym?> myGymAsync = ref.watch(myGymProvider);
    final AsyncValue<List<Gym>> nearbyAsync = ref.watch(nearbyGymsProvider);
    final List<ConsultationRequest> requests = ref.watch(
      consultationRequestControllerProvider,
    );
    final ConsultationRequest? recentRequest = requests.isEmpty
        ? null
        : requests.first;
    final ConsultationRequest? pendingRequest =
        recentRequest?.status == ConsultationStatus.pending
        ? recentRequest
        : null;
    final GlobalKey recentConsultationKey = GlobalKey();

    void showRecentConsultation() {
      final BuildContext? targetContext = recentConsultationKey.currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionHeader(title: l.exMyGymTrainerSection),
          const SizedBox(height: 10),
          _MyGymTrainerSection(
            gymAsync: myGymAsync,
            selectedSlot: selectedSlot,
            onSlot: onSlot,
            onFind: onFind,
            onRetry: () => ref.invalidate(myGymProvider),
            onPendingConsultationTap: pendingRequest == null
                ? null
                : showRecentConsultation,
          ),
          if (recentRequest != null) ...<Widget>[
            const SizedBox(height: 28),
            _RecentConsultationSection(
              key: recentConsultationKey,
              request: recentRequest,
            ),
          ],
          const SizedBox(height: 28),
          _RecommendedGymSection(
            gymsAsync: nearbyAsync,
            onMore: () => context.push(AppRoutes.gyms),
            onRetry: () => ref.invalidate(nearbyGymsProvider),
          ),
          const SizedBox(height: 28),
          _RecommendedTrainerSection(
            gymsAsync: nearbyAsync,
            onMore: () => context.push(AppRoutes.trainers),
            onRetry: () => ref.invalidate(nearbyGymsProvider),
          ),
        ],
      ),
    );
  }
}

class _RecentConsultationSection extends StatelessWidget {
  const _RecentConsultationSection({required this.request, super.key});

  final ConsultationRequest request;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool trainerTarget =
        request.targetType == ConsultationTargetType.trainer;
    final String targetName = trainerTarget
        ? request.trainerName ?? request.gymName
        : request.gymName;
    final String targetType = trainerTarget
        ? l.exTrainerConsultType
        : l.exGymConsultType;
    final String status = switch (request.status) {
      ConsultationStatus.pending => l.exConsultPendingStatus,
      ConsultationStatus.accepted => l.exConsultAcceptedStatus,
      ConsultationStatus.rejected => l.exConsultRejectedStatus,
    };
    final String date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(request.preferredDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeader(title: l.exConsultStatusSection),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: FigmaColors.primaryA(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  trainerTarget ? Icons.person_outline : Icons.fitness_center,
                  size: 21,
                  color: FigmaColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            targetName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: FigmaColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: FigmaColors.primaryA(0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: FigmaColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trainerTarget
                          ? '$targetType · ${request.gymName}'
                          : targetType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: FigmaColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '$date · ${request.preferredTimeSlot}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: FigmaColors.textBody,
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
  }
}

class _MyGymTrainerSection extends StatelessWidget {
  const _MyGymTrainerSection({
    required this.gymAsync,
    required this.selectedSlot,
    required this.onSlot,
    required this.onFind,
    required this.onRetry,
    required this.onPendingConsultationTap,
  });

  final AsyncValue<Gym?> gymAsync;
  final String? selectedSlot;
  final ValueChanged<String> onSlot;
  final VoidCallback onFind;
  final VoidCallback onRetry;
  final VoidCallback? onPendingConsultationTap;

  @override
  Widget build(BuildContext context) {
    return gymAsync.when(
      loading: () => const _SectionLoading(height: 180),
      error: (Object _, StackTrace _) => _SectionError(onRetry: onRetry),
      data: (Gym? gym) => gym == null
          ? _EmptyMyGym(onFind: onFind)
          : _MyGymTrainerCard(
              gym: gym,
              selectedSlot: selectedSlot,
              onSlot: onSlot,
              onGymTap: () => context.push(AppRoutes.gymDetailPath(gym.id)),
              onTrainerTap: gym.trainerName?.isNotEmpty ?? false
                  ? () => context.push(AppRoutes.trainerDetailPath(gym.id))
                  : null,
              onPendingConsultationTap: onPendingConsultationTap,
            ),
    );
  }
}

class _MyGymTrainerCard extends StatelessWidget {
  const _MyGymTrainerCard({
    required this.gym,
    required this.selectedSlot,
    required this.onSlot,
    required this.onGymTap,
    required this.onTrainerTap,
    required this.onPendingConsultationTap,
  });

  final Gym gym;
  final String? selectedSlot;
  final ValueChanged<String> onSlot;
  final VoidCallback onGymTap;
  final VoidCallback? onTrainerTap;
  final VoidCallback? onPendingConsultationTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool hasTrainerName = gym.trainerName?.isNotEmpty ?? false;
    final String trainer = hasTrainerName ? gym.trainerName! : l.exTrainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: FigmaColors.primaryA(0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.check_circle,
                    size: 13,
                    color: FigmaColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l.exConnected,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _InfoLabel(icon: Icons.place_outlined, label: l.exMyGym),
          const SizedBox(height: 7),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onGymTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            gym.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: FigmaColors.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${gym.address} · ${gym.distanceKm.toStringAsFixed(1)}km',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: FigmaColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      color: FigmaColors.textFaint,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (gym.trainerName?.isNotEmpty ?? false) ...<Widget>[
            const SizedBox(height: 16),
            const Divider(height: 1, color: FigmaColors.hairline),
            const SizedBox(height: 14),
            _InfoLabel(icon: Icons.person_outline, label: l.exMyTrainer),
            const SizedBox(height: 9),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTrainerTap,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: FigmaColors.iconTint,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.person_outline,
                          size: 20,
                          color: FigmaColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              gym.trainerName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: FigmaColors.ink,
                              ),
                            ),
                            Text(
                              gym.trainerRole ?? l.exTrainerDedicated,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: FigmaColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right,
                        color: FigmaColors.textFaint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _ReservationPanel(
            gym: gym,
            trainer: trainer,
            selectedSlot: selectedSlot,
            onSlot: onSlot,
          ),
          if (onPendingConsultationTap != null) ...<Widget>[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPendingConsultationTap,
                style: FilledButton.styleFrom(
                  backgroundColor: FigmaColors.primary,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l.exViewConsultationRequest,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReservationPanel extends StatelessWidget {
  const _ReservationPanel({
    required this.gym,
    required this.trainer,
    required this.selectedSlot,
    required this.onSlot,
  });

  final Gym gym;
  final String trainer;
  final String? selectedSlot;
  final ValueChanged<String> onSlot;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[FigmaColors.bannerStart, FigmaColors.bannerEnd],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.primaryA(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.exAiSlotTitle,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: FigmaColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l.exTrainerAvailability(trainer),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: FigmaColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final List<String> slot in <List<String>>[
                <String>[l.exSlotToday19, l.exSlot1Left],
                <String>[l.exSlotTomorrow0730, l.exSlotAvailable],
                <String>[l.exSlotTomorrow20, l.exSlot2Left],
              ])
                _SlotChip(
                  label: slot[0],
                  sub: slot[1],
                  selected: selectedSlot == slot[0],
                  onTap: () => onSlot(slot[0]),
                ),
            ],
          ),
          if (selectedSlot != null) ...<Widget>[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l.exReserveConfirmedSlotGym(selectedSlot!, gym.name),
                      ),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: FigmaColors.primary,
                  minimumSize: const Size(0, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l.exReserveConfirm(selectedSlot!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendedGymSection extends StatelessWidget {
  const _RecommendedGymSection({
    required this.gymsAsync,
    required this.onMore,
    required this.onRetry,
  });

  final AsyncValue<List<Gym>> gymsAsync;
  final VoidCallback onMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeader(
          title: l.exRecommendedGyms,
          actionLabel: l.exSeeMore,
          onAction: onMore,
        ),
        const SizedBox(height: 10),
        gymsAsync.when(
          loading: () => const _SectionLoading(height: 184),
          error: (Object _, StackTrace _) => _SectionError(onRetry: onRetry),
          data: (List<Gym> gyms) => gyms.isEmpty
              ? _EmptyRecommendation(message: l.exNoRecommendedGyms)
              : SizedBox(
                  height: 184,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: gyms.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (BuildContext context, int index) {
                      return _GymRecommendationCard(
                        gym: gyms[index],
                        onTap: () => context.push(
                          AppRoutes.gymDetailPath(gyms[index].id),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _GymRecommendationCard extends StatelessWidget {
  const _GymRecommendationCard({required this.gym, required this.onTap});

  final Gym gym;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return _RecommendationSurface(
      width: 236,
      onTap: onTap,
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
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              const Icon(
                Icons.place_outlined,
                size: 14,
                color: FigmaColors.textMuted,
              ),
              const SizedBox(width: 3),
              Text(
                '${gym.distanceKm.toStringAsFixed(1)}km',
                style: const TextStyle(
                  fontSize: 11,
                  color: FigmaColors.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.star_rounded,
                size: 15,
                color: FigmaColors.orange,
              ),
              const SizedBox(width: 2),
              Text(
                gym.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: FigmaColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final String tag in gym.tags.take(2)) _TagChip(label: tag),
            ],
          ),
          const Spacer(),
          if (gym.weekdayHours != null)
            Row(
              children: <Widget>[
                const Icon(
                  Icons.schedule_outlined,
                  size: 13,
                  color: FigmaColors.textMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l.exGymWeekdayHours(gym.weekdayHours!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: FigmaColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RecommendedTrainerSection extends StatelessWidget {
  const _RecommendedTrainerSection({
    required this.gymsAsync,
    required this.onMore,
    required this.onRetry,
  });

  final AsyncValue<List<Gym>> gymsAsync;
  final VoidCallback onMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeader(
          title: l.exRecommendedTrainers,
          actionLabel: l.exSeeMore,
          onAction: onMore,
        ),
        const SizedBox(height: 10),
        gymsAsync.when(
          loading: () => const _SectionLoading(height: 156),
          error: (Object _, StackTrace _) => _SectionError(onRetry: onRetry),
          data: (List<Gym> gyms) {
            final List<Gym> trainerGyms = gyms
                .where((Gym gym) => gym.trainerName?.isNotEmpty ?? false)
                .toList(growable: false);
            if (trainerGyms.isEmpty) {
              return _EmptyRecommendation(message: l.exNoRecommendedTrainers);
            }
            return SizedBox(
              height: 156,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: trainerGyms.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (BuildContext context, int index) {
                  return _TrainerRecommendationCard(
                    gym: trainerGyms[index],
                    onTap: () => context.push(
                      AppRoutes.trainerDetailPath(trainerGyms[index].id),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TrainerRecommendationCard extends StatelessWidget {
  const _TrainerRecommendationCard({required this.gym, required this.onTap});

  final Gym gym;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return _RecommendationSurface(
      width: 252,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  gym.trainerName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: FigmaColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  gym.trainerRole ?? l.exTrainerDedicated,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: FigmaColors.textMuted,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${l.exTrainerAffiliation} · ${gym.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.textBody,
                  ),
                ),
                const Spacer(),
                Text(
                  l.exTrainerRecommendationReason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.primary,
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

class _RecommendationSurface extends StatelessWidget {
  const _RecommendationSurface({
    required this.width,
    required this.onTap,
    required this.child,
  });

  final double width;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(16);
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: FigmaColors.hairline),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: FigmaColors.ink,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: FigmaColors.primary,
              minimumSize: const Size(48, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class _InfoLabel extends StatelessWidget {
  const _InfoLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 15, color: FigmaColors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: FigmaColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: FigmaColors.primaryA(0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: FigmaColors.primary,
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? FigmaColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? null
                : Border.all(color: FigmaColors.primaryA(0.25)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : FigmaColors.ink,
                ),
              ),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.8)
                      : FigmaColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMyGym extends StatelessWidget {
  const _EmptyMyGym({required this.onFind});

  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: _cardDecoration(),
      child: Column(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: FigmaColors.primaryA(0.10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.fitness_center,
              size: 23,
              color: FigmaColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.exNoGymTrainer,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: FigmaColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onFind,
            style: FilledButton.styleFrom(
              backgroundColor: FigmaColors.primary,
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.search, size: 17),
            label: Text(
              l.exFindGym,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: _cardDecoration(),
      child: Column(
        children: <Widget>[
          Text(
            l.exGymsLoadError,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: FigmaColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: FigmaColors.primary,
              side: BorderSide(color: FigmaColors.primaryA(0.35)),
              minimumSize: const Size(48, 44),
            ),
            child: Text(l.actionRetry),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecommendation extends StatelessWidget {
  const _EmptyRecommendation({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: _cardDecoration(),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: FigmaColors.textMuted,
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: FigmaColors.hairline),
    boxShadow: kCardShadow,
  );
}
