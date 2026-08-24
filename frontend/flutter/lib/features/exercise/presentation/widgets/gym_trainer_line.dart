import 'package:flutter/material.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// 헬스장 카드 안에 서는 **트레이너 한 줄** (#1185 · #1187).
///
/// 헬스장을 견주는 자리에서 정작 그곳에 누가 있는지는 상세로 들어가야 알 수
/// 있었다. 이름과 직함을 한 줄로 적고, 왜 추천하는지는 그 아래 배지로 붙인다.
///
/// 같은 줄을 두 곳이 쓴다 — 헬스장 찾기 목록(소속 트레이너 전원)과 연결된 내
/// 헬스장 카드(담당 한 명). 뒤쪽은 [connected] 로 `연결됨` 을 달고 [onDetail]
/// 로 상세로 가는 길을 준다.
class GymTrainerLine extends StatelessWidget {
  const GymTrainerLine({
    required this.trainer,
    this.connected = false,
    this.showReason = true,
    this.onDetail,
    super.key,
  });

  final Trainer trainer;

  /// 내 담당 트레이너인지. 헬스장 카드 머리의 `연결됨` 과 같은 배지를 단다.
  final bool connected;

  /// 추천 이유를 배지로 적을지. 이미 연결된 트레이너에게는 고를 이유를 다시
  /// 말할 자리가 아니라 끈다.
  final bool showReason;

  /// 트레이너 상세로 가는 길. null 이면 읽기만 하는 줄이다 — 목록 카드는
  /// 카드 전체가 헬스장 상세로 가므로 그 안에서 또 다른 길을 열지 않는다.
  final VoidCallback? onDetail;

  /// 오른쪽에 배지나 버튼이 서는가. 그때는 이름·직함을 두 줄로 쌓는다.
  bool get stacked => connected || onDetail != null;

  Widget _name() => Text(
    trainer.name,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w800,
      color: FigmaColors.ink,
    ),
  );

  Widget _role(AppLocalizations l) => Text(
    trainer.role ?? l.exTrainerDedicated,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: AppColors.mutedForeground,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String? reason = trainer.reason;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: FigmaColors.softBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.person_outline,
                  size: 15,
                  color: FigmaColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              // 오른쪽에 배지·버튼이 붙는 줄에서는 이름 아래로 직함을 내린다
              // (#1187) — 한 줄에 넷을 밀어 넣으면 직함부터 `퍼스널 트…` 로
              // 잘려, 이 사람이 무엇을 하는 사람인지가 사라진다.
              Expanded(
                flex: 3,
                child: stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          // `연결됨` 은 **이름 바로 오른쪽**에 붙는다 (#1267).
                          // 오른쪽 끝에 두면 남는 폭만큼 이름에서 멀어져,
                          // 누가 연결됐다는 말인지 이름과 묶여 읽히지 않았다.
                          if (connected)
                            Row(
                              children: <Widget>[
                                Flexible(child: _name()),
                                const SizedBox(width: 6),
                                _ConnectedBadge(
                                  key: const Key('gymTrainerConnectedBadge'),
                                  label: l.exConnected,
                                ),
                              ],
                            )
                          else
                            _name(),
                          const SizedBox(height: 1),
                          _role(l),
                        ],
                      )
                    : Row(
                        children: <Widget>[
                          Flexible(child: _name()),
                          const SizedBox(width: 6),
                          Flexible(child: _role(l)),
                        ],
                      ),
              ),
              // 상세로 가는 길은 줄 **오른쪽 끝**에 선다 — 다른 화면의 동작
              // 버튼과 같은 자리다 (#1267). 오른쪽 칸은 제 몫을 다 차지하고
              // 그 안에서 오른쪽 정렬한다: 내용 크기로만 잡으면 남는 자리가
              // 버튼 오른쪽에 빈 칸으로 남아 버튼이 줄 가운데에서 끝난다.
              // 문구가 긴 로케일에서는 FittedBox 가 버튼부터 줄인다.
              if (onDetail != null)
                Expanded(
                  flex: 2,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('gymTrainerDetailButton'),
                      onPressed: onDetail,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        l.exViewDetail,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (showReason && reason != null) ...<Widget>[
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${l.exRecommendationReason}: $reason',
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.textBody,
                    height: 1.3,
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

/// 헬스장 카드 머리의 `연결됨` 과 같은 배지 — 담당 트레이너 줄에도 같은 표시를
/// 쓴다.
class _ConnectedBadge extends StatelessWidget {
  const _ConnectedBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: FigmaColors.primaryA(0.10),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.check_circle, size: 11, color: FigmaColors.primary),
        const SizedBox(width: 3),
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: FigmaColors.primary,
          ),
        ),
      ],
    ),
  );
}
