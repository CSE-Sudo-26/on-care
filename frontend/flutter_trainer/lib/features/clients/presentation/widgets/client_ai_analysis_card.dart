import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/icon_label.dart';

/// 서버가 기간에 맞춰 만든 조언 한 문장. (#1017 식단 · #1025 운동)
///
/// 식단과 운동이 **같은 카드**를 쓴다. 두 화면이 나란히 놓이는데 조언만
/// 생김새가 다르면, 트레이너는 같은 성격의 말을 매번 다른 모양으로 읽게 된다.
///
/// 제목이 기간을 말한다 — `오늘` 은 지금을 짚고, `이번 주`·`전체` 는 되짚는
/// 말이라 카드가 무엇을 두고 한 말인지 제목만 봐도 갈린다.
class ClientAiAnalysisCard extends StatelessWidget {
  /// Creates the card for [period] showing [message].
  const ClientAiAnalysisCard({
    super.key,
    required this.period,
    required this.message,
    this.cardKey,
  });

  /// 조언이 다루는 구간. 제목이 이 값을 따라간다.
  final ClientPeriod period;

  /// 서버 문장. 비어 있으면 카드를 그리지 않는다.
  final String message;

  /// 테스트가 이 카드를 집을 때 쓰는 키.
  final Key? cardKey;

  /// 기간별 제목. 화면의 기간 토글과 같은 말을 쓴다.
  static String titleOf(AppLocalizations l, ClientPeriod period) =>
      switch (period) {
        ClientPeriod.today => l.aiAnalysis,
        ClientPeriod.week => l.aiPeriodAnalysis,
        ClientPeriod.month => l.aiAllAnalysis,
      };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    // 빈 문장으로 카드를 세우지 않는다 — 제목만 있고 내용이 없으면 조언이
    // 사라진 것인지 아직 안 온 것인지 알 수 없다.
    if (message.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      key: cardKey,
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
            label: titleOf(l, period),
            color: AppColors.accent,
            fontSize: 11,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
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
