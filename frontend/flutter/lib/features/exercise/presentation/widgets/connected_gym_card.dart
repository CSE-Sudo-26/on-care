import 'package:flutter/material.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/presentation/widgets/gym_trainer_line.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// 운동 탭과 MY가 함께 쓰는 연결 헬스장·담당 트레이너 카드.
class ConnectedGymCard extends StatelessWidget {
  const ConnectedGymCard({
    required this.gym,
    required this.trainer,
    required this.onGymTap,
    this.onTrainerDetail,
    this.onFindTrainer,
    this.footer,
    super.key,
  });

  final Gym gym;
  final Trainer? trainer;
  final VoidCallback onGymTap;
  final VoidCallback? onTrainerDetail;
  final VoidCallback? onFindTrainer;

  /// 운동 탭의 채팅처럼 화면별로만 필요한 동작. MY는 전달하지 않는다.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      key: const Key('my-gym-info-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FigmaColors.hairline),
        boxShadow: kCardShadow,
      ),
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
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: Tooltip(
              message: l.myGymDetailTooltip,
              child: InkWell(
                onTap: onGymTap,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      Container(
                        key: const Key('connectedGymIcon'),
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: FigmaColors.primaryA(0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.fitness_center,
                          size: 19,
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
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: FigmaColors.textBody,
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
          ),
          if (trainer != null) ...<Widget>[
            const SizedBox(height: 12),
            GymTrainerLine(
              key: const Key('gym-trainer-line-mine'),
              trainer: trainer!,
              showReason: false,
              onDetail: onTrainerDetail,
            ),
          ] else if (onFindTrainer != null) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.person_off_outlined,
                  size: 15,
                  color: FigmaColors.textFaint,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(l.myNoTrainer)),
                TextButton(
                  onPressed: onFindTrainer,
                  child: Text(l.exFindTrainer),
                ),
              ],
            ),
          ],
          if (footer != null) ...<Widget>[const SizedBox(height: 14), footer!],
        ],
      ),
    );
  }
}
