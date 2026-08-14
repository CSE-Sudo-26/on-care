import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
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
    // 목록(헬스장 찾기)이 제휴 + 카카오를 합쳐 보여주므로 상세도 같은 소스를 봐야
    // 카카오에서 온 헬스장을 눌렀을 때 "찾을 수 없음"이 되지 않는다(#329).
    final AsyncValue<List<Gym>> nearbyAsync = ref.watch(
      gymFinderResultsProvider,
    );
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
    final Widget body;
    if (gym != null) {
      body = _GymDetails(gym: gym, isMyGym: myGym != null);
    } else if (nearbyAsync.isLoading || myGymAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator(strokeWidth: 3));
    } else if (nearbyAsync.hasError || myGymAsync.hasError) {
      body = _StateMessage(
        message: l.exGymsLoadError,
        onRetry: () {
          ref.invalidate(gymFinderResultsProvider);
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
  const _GymDetails({required this.gym, required this.isMyGym});

  final Gym gym;
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
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.foreground,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _AffiliatedTrainers(gymId: gym.id),
            if (!isMyGym) ...<Widget>[
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('gym-consult-start'),
                // 상담은 트레이너 한 사람에게만 간다 — 헬스장에서 시작해도 소속
                // 트레이너 중 누구에게 보낼지 먼저 고른다.
                onPressed: () => _pickTrainerForConsultation(context, gym),
                style: FilledButton.styleFrom(
                  backgroundColor: FigmaColors.primary,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  l.exGymConsultRequest,
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

/// 소속 트레이너 중 상담을 보낼 한 명을 고르는 시트.
///
/// 헬스장 상세의 목록으로 올려보내지 않고 시트로 띄우는 이유: 목록 행을 누르면
/// 트레이너 상세로 가야 하고(정보를 보고 고르는 동선), 여기서는 "상담을 건다"는
/// 의도가 이미 정해져 있어 한 번 더 상세를 거치게 하면 단계만 늘어난다.
Future<void> _pickTrainerForConsultation(BuildContext context, Gym gym) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext sheetContext) =>
        _TrainerPickerSheet(gym: gym),
  );
}

class _TrainerPickerSheet extends ConsumerWidget {
  const _TrainerPickerSheet({required this.gym});

  final Gym gym;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<Trainer> trainers =
        ref.watch(gymTrainersProvider(gym.id)).valueOrNull ?? const <Trainer>[];
    final List<ConsultationRequest> requests = ref.watch(
      consultationRequestControllerProvider,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l.exGymConsultPickTrainer,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: FigmaColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.exGymConsultPickTrainerHint,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            if (trainers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l.exGymConsultNoTrainers,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.mutedForeground,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  key: const Key('gym-consult-trainer-picker'),
                  shrinkWrap: true,
                  itemCount: trainers.length,
                  separatorBuilder: (_, _) => const Padding(
                    padding: EdgeInsets.only(left: 70),
                    child: Divider(height: 1, color: FigmaColors.hairline),
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    final Trainer trainer = trainers[index];
                    // 이미 대기 중인 트레이너를 다시 누르면 서버가 409 를 준다.
                    // 누르기 전에 상태를 보여 주고 막는다.
                    final bool pending = requests.any(
                      (ConsultationRequest request) =>
                          request.trainerId == trainer.id &&
                          request.status == ConsultationStatus.pending,
                    );
                    return _AffiliatedTrainerRow(
                      trainer: trainer,
                      trailingLabel: pending ? l.exConsultPendingCta : null,
                      onTap: pending
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              context.push(
                                AppRoutes.consultationRequestPath(
                                  gymId: gym.id,
                                  trainerId: trainer.id,
                                ),
                              );
                            },
                    );
                  },
                ),
              ),
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
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
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

/// 이 헬스장에 소속된 트레이너 전원. 헬스장당 여러 명일 수 있으므로 목록으로
/// 그리고, 한 명도 없으면 섹션 자체를 숨긴다.
class _AffiliatedTrainers extends ConsumerWidget {
  const _AffiliatedTrainers({required this.gymId});

  final String gymId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<Trainer> trainers =
        ref.watch(gymTrainersProvider(gymId)).valueOrNull ?? const <Trainer>[];
    if (trainers.isEmpty) return const SizedBox.shrink();

    return _DetailSection(
      icon: Icons.person_outline,
      title: l.exAffiliatedTrainer,
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < trainers.length; i++) ...<Widget>[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.only(left: 70),
                child: Divider(height: 1, color: FigmaColors.hairline),
              ),
            _AffiliatedTrainerRow(trainer: trainers[i]),
          ],
        ],
      ),
    );
  }
}

class _AffiliatedTrainerRow extends StatelessWidget {
  const _AffiliatedTrainerRow({
    required this.trainer,
    this.onTap,
    this.trailingLabel,
  });

  final Trainer trainer;

  /// 기본 동작은 트레이너 상세로 가기다. 상담 트레이너 선택 시트는 여기에 자기
  /// 동작을 넣고, 이미 대기 중이면 null 을 줘 행을 잠근다.
  final VoidCallback? onTap;

  /// 오른쪽 화살표 대신 보여 줄 상태 문구(예: "상담 요청 대기 중").
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final bool locked = onTap == null && trailingLabel != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: locked
            ? null
            : (onTap ??
                  () => context.push(AppRoutes.trainerDetailPath(trainer.id))),
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
                      trainer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: FigmaColors.ink,
                      ),
                    ),
                    if (trainer.role != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        trainer.role!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingLabel != null)
                Text(
                  trailingLabel!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedForeground,
                  ),
                )
              else
                const Icon(Icons.chevron_right, color: FigmaColors.textFaint),
            ],
          ),
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
                      fontSize: 14,
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
            fontSize: 14,
            height: 1.4,
            color: AppColors.foreground,
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
          fontSize: 12.5,
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
              style: const TextStyle(fontSize: 14, color: AppColors.foreground),
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
