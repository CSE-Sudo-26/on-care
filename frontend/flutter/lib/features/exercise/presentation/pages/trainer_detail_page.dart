import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/domain/repositories/gym_repository.dart';
import 'package:oncare/features/exercise/presentation/controllers/consultation_request_controller.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/widgets/connection_disconnect.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

class TrainerDetailPage extends ConsumerWidget {
  const TrainerDetailPage({required this.trainerId, super.key});

  final String trainerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<Trainer?> trainerAsync = ref.watch(
      trainerProvider(trainerId),
    );
    // 카카오 헬스장 소속 트레이너의 소속 헬스장 카드도 떠야 한다(#329).
    final AsyncValue<List<Gym>> gymsAsync = ref.watch(gymFinderResultsProvider);
    final List<ConsultationRequest> requests = ref.watch(
      consultationRequestControllerProvider,
    );

    final Widget body = switch (trainerAsync) {
      AsyncData<Trainer?>(value: final Trainer? trainer) when trainer != null =>
        _TrainerDetails(
          trainer: trainer,
          // 소속 헬스장은 목록에서 찾는다. 아직 로딩 중이면 카드만 비고
          // 나머지 정보는 그대로 보인다.
          gym: switch (gymsAsync) {
            AsyncData<List<Gym>>(:final List<Gym> value) =>
              value.where((Gym gym) => gym.id == trainer.gymId).firstOrNull,
            _ => null,
          },
          // 헬스장이 아니라 이 트레이너 앞으로 낸 요청만 대기중으로 본다.
          // 헬스장이 아니라 트레이너 단위로 비교한다 — 같은 헬스장에 다른
          // 트레이너가 있어도 내 담당이 아니면 상담을 걸 수 있어야 한다.
          isMyTrainer:
              ref.watch(myTrainerProvider).valueOrNull?.id == trainer.id,
          hasPending: requests.any(
            (ConsultationRequest request) =>
                request.trainerId == trainer.id &&
                request.status == ConsultationStatus.pending,
          ),
        ),
      AsyncData<Trainer?>() => _StateMessage(message: l.exTrainerNotFound),
      AsyncError<Trainer?>() => _StateMessage(
        message: l.exTrainersLoadError,
        onRetry: () => ref.invalidate(trainerProvider(trainerId)),
      ),
      _ => const Center(child: CircularProgressIndicator(strokeWidth: 3)),
    };

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

class _TrainerDetails extends ConsumerWidget {
  const _TrainerDetails({
    required this.trainer,
    required this.gym,
    required this.isMyTrainer,
    required this.hasPending,
  });

  final Trainer trainer;

  /// 소속 헬스장. 아직 못 읽었으면 null 이고 해당 섹션만 빠진다.
  final Gym? gym;

  /// 이미 내 담당 트레이너면 상담 요청 CTA 를 숨긴다.
  final bool isMyTrainer;
  final bool hasPending;

  /// 담당 트레이너 연결만 끊는다 — 헬스장은 그대로다. 끊었으면 이 화면을
  /// 닫는다. 지운 대상의 상세에 남아 있으면 방금 무엇을 했는지 화면이 말해
  /// 주지 못한다. (#1057)
  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l = AppLocalizations.of(context);
    // 아직 읽는 중이면 `valueOrNull` 은 null 이라 확인 문구에서 헬스장 이름이
    // 빠진다.
    final Gym? myGym = await ref.read(myGymProvider.future);
    if (!context.mounted) return;
    final bool removed = await confirmDisconnect(
      context,
      ref,
      message: l.myTrainerDisconnectConfirm(trainer.name, myGym?.name ?? ''),
      disconnect: (GymRepository repo) => repo.disconnectMyTrainer(),
    );
    // go_router 의 pop 을 쓴다 — 상세는 라우터가 쌓은 화면이라, 그 안의
    // Navigator 로는 돌아갈 곳이 없다고 나온다.
    if (removed && context.mounted && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String intro = trainer.intro?.trim() ?? '';
    final String career = trainer.career?.trim() ?? '';
    final List<String> certifications = trainer.certifications
        .map((String certification) => certification.trim())
        .where((String certification) => certification.isNotEmpty)
        .toList(growable: false);
    // 소개/경력/자격증이 하나라도 있어야 "트레이너 소개" 박스를 그린다 —
    // 이 조건은 바뀌지 않는다. 소속 헬스장은 그 박스가 이미 있을 때만 안에
    // 합치고(#1255), 소개가 아예 없으면 예전처럼 별도로 보여준다.
    final bool hasProfile =
        intro.isNotEmpty || career.isNotEmpty || certifications.isNotEmpty;
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
              trainer.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: FigmaColors.ink,
              ),
            ),
            if (trainer.role?.isNotEmpty ?? false) ...<Widget>[
              const SizedBox(height: 5),
              Text(
                trainer.role!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: 22),
            // 추천 목록에서 골라 들어온 흐름이라, **왜 추천됐는지**가 소개보다
            // 먼저다(#1445). 소개가 없는 트레이너도 이 박스는 늘 있어 소속·
            // 상담 CTA 와의 순서가 흔들리지 않는다.
            _DetailSection(
              key: const Key('trainer-detail-reason'),
              icon: Icons.auto_awesome_outlined,
              title: l.exRecommendationReason,
              child: Text(
                trainer.reason ?? l.exTrainerRecommendationReason,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: FigmaColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 트레이너 앱 프로필(소개·경력·자격증)과 같은 값을 보여준다.
            if (hasProfile) ...<Widget>[
              _DetailSection(
                icon: Icons.badge_outlined,
                title: l.exTrainerIntroSection,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (intro.isNotEmpty)
                      Text(
                        intro,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.foreground,
                        ),
                      ),
                    if (career.isNotEmpty) ...<Widget>[
                      if (intro.isNotEmpty) const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.workspace_premium_outlined,
                            size: 15,
                            color: FigmaColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l.exTrainerCareer(career),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: FigmaColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (certifications.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      Text(
                        l.exTrainerCertifications,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          for (final String cert in certifications)
                            _CertChip(label: cert),
                        ],
                      ),
                    ],
                    // 헬스장 → 트레이너 목록을 거쳐 이미 들어온 흐름이라 소속은
                    // 별도 박스로 한 번 더 강조할 필요가 낮다 — 소개 박스가 이미
                    // 있으면 그 안 한 줄로 합친다(#1255).
                    if (gym != null) ...<Widget>[
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: FigmaColors.hairline),
                      const SizedBox(height: 12),
                      _AffiliatedGymRow(gym: gym!),
                    ],
                  ],
                ),
              ),
            ] else if (gym != null) ...<Widget>[
              // 소개할 내용이 아예 없으면 합칠 박스도 없다 — 소속만은 예전처럼
              // 따로 보여준다.
              _DetailSection(
                icon: Icons.fitness_center,
                title: l.exTrainerAffiliation,
                child: _AffiliatedGymRow(gym: gym!),
              ),
            ],
            if (isMyTrainer) ...<Widget>[
              const SizedBox(height: 24),
              // 목록 카드에서 삭제를 여기로 옮겼다 (#1057).
              DisconnectButton(
                label: l.myTrainerDisconnectTooltip,
                onTap: () => _disconnect(context, ref),
              ),
            ],
            if (!isMyTrainer) ...<Widget>[
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('consult-start'),
                onPressed: hasPending
                    ? null
                    : () => context.push(
                        AppRoutes.consultationRequestPath(
                          gymId: trainer.gymId,
                          trainerId: trainer.id,
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
                  hasPending
                      ? l.exConsultPendingCta
                      : l.exTrainerConsultRequest,
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

/// 자격증 한 건을 나타내는 칩. 헬스장 태그 칩과 같은 톤을 쓴다.
class _CertChip extends StatelessWidget {
  const _CertChip({required this.label});

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
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: FigmaColors.primary,
        ),
      ),
    );
  }
}

/// 소속 헬스장 한 줄 — 이름·주소·거리, 누르면 헬스장 상세로. 예전에는 별도
/// 카테고리 박스였지만 헬스장 → 트레이너 흐름에서는 중복 정보라
/// `트레이너 소개` 박스 안 한 줄로 합쳤다(#1255).
class _AffiliatedGymRow extends StatelessWidget {
  const _AffiliatedGymRow({required this.gym});

  final Gym gym;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(AppRoutes.gymDetailPath(gym.id)),
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.fitness_center,
              size: 15,
              color: FigmaColors.primary,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    gym.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.ink,
                    ),
                  ),
                  Text(
                    gym.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: FigmaColors.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

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
          Padding(padding: const EdgeInsets.all(16), child: child),
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
