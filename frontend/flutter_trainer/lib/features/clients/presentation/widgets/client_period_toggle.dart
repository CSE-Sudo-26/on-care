import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// `오늘 / 이번 주 / 이번 달` 토글 — 고객 식단·운동 카드가 함께 쓴다. (#914)
///
/// 회원 앱 식단 탭·운동 탭의 같은 토글과 **문구도 순서도 같다.** 회원이 자기
/// 화면에서 고르던 것을 트레이너가 다른 이름으로 고르면, 둘이 같은 기간을
/// 이야기하고 있는지부터 확인해야 한다.
///
/// 카드 두 장이 각자 토글을 그리므로 위젯 하나로 모아 둔다 — 자리·여백·선택
/// 표시가 카드마다 달라지면 같은 조작이 화면마다 다르게 보인다.
class ClientPeriodToggle extends StatelessWidget {
  /// Creates the toggle.
  const ClientPeriodToggle({
    super.key,
    required this.active,
    required this.onChanged,
  });

  /// 지금 고른 기간.
  final ClientPeriod active;

  /// 기간을 바꿀 때.
  final ValueChanged<ClientPeriod> onChanged;

  /// 기간별 표시 문구.
  static String labelOf(AppLocalizations l, ClientPeriod period) =>
      switch (period) {
        ClientPeriod.today => l.clientPeriodToday,
        ClientPeriod.week => l.clientPeriodWeek,
        ClientPeriod.month => l.clientPeriodMonth,
      };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      key: const ValueKey<String>('client-period-toggle'),
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.all(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final ClientPeriod period in ClientPeriod.values)
            Flexible(
              child: Semantics(
                button: true,
                selected: active == period,
                child: GestureDetector(
                  key: Key('client-period-${period.name}'),
                  onTap: () => onChanged(period),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: active == period
                          ? AppColors.primary
                          : const Color(0x00000000),
                      borderRadius: const BorderRadius.all(AppRadius.pill),
                    ),
                    child: Text(
                      labelOf(l, period),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: active == period
                            ? AppColors.primaryForeground
                            : AppColors.mutedForeground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
