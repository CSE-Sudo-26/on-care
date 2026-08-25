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
              // `GestureDetector` 가 아니라 `InkWell` 이다. 트레이너 앱은
              // 웹·데스크톱에서도 쓰이는데, 탭만 받는 위젯은 Tab 포커스와 Enter 를
              // 받지 못해 마우스 없이는 기간을 바꿀 수 없었다. 같은 화면의
              // `_ClientDataTab` 이 이미 쓰는 방식이다.
              child: Semantics(
                button: true,
                selected: active == period,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    color: active == period
                        ? AppColors.primary
                        : const Color(0x00000000),
                    borderRadius: const BorderRadius.all(AppRadius.pill),
                  ),
                  child: Material(
                    color: const Color(0x00000000),
                    child: InkWell(
                      key: Key('client-period-${period.name}'),
                      onTap: () => onChanged(period),
                      customBorder: const StadiumBorder(),
                      child: Padding(
                        // 회원 앱 식단·운동 탭 기간 토글과 **같은 크기**다 —
                        // 같은 자리에 놓인 같은 조작이 화면마다 다르게 보이면
                        // 안 된다. 글자를 키운 화면에서 여백을 좁히는 규칙까지
                        // 같다. (회원 앱 #1126)
                        padding: EdgeInsets.symmetric(
                          horizontal:
                              MediaQuery.textScalerOf(context).scale(1) > 1.3
                              ? 12
                              : 18,
                          vertical: 6,
                        ),
                        child: Text(
                          labelOf(l, period),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
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
              ),
            ),
        ],
      ),
    );
  }
}
