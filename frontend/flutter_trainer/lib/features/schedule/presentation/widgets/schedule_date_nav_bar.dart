import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 두 보기가 함께 쓰는 날짜 내비게이션 행 — `◀ 8월 14일 – 8월 20일 ▶` 과
/// 오른쪽 끝의 [trailing](`오늘`·`일|주`). (#882)
///
/// 일 보기와 주 보기가 같은 자리에 같은 것을 두어야 해서 한 곳에 모았다.
/// 오른쪽 끝은 아래 요일 칸 그리드의 오른쪽 끝과 맞는다 — 양쪽이 같은
/// [AppLayout.pagePadding] 안에 있기 때문이다.
class ScheduleDateNavBar extends StatelessWidget {
  const ScheduleDateNavBar({
    super.key,
    required this.start,
    required this.end,
    required this.onShift,
    required this.trailing,
  });

  /// 보이는 창의 첫날.
  final DateTime start;

  /// 보이는 창의 마지막 날.
  final DateTime end;

  /// -1 = 이전 주, +1 = 다음 주.
  final ValueChanged<int> onShift;

  /// 오른쪽 끝에 붙는 컨트롤.
  final Widget trailing;

  /// 날짜와 컨트롤이 한 줄에 함께 들어가는 최소 폭. 아래로는 컨트롤을 다음
  /// 줄로 내린다 — 한 줄을 고집하면 좁은 화면에서 그대로 넘친다.
  static const double _singleRowMinWidth = 440;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final nav = <Widget>[
      _ChevronButton(
        icon: Icons.chevron_left,
        tooltip: l.a11yPrevDay,
        onTap: () => onShift(-1),
      ),
      const SizedBox(width: AppSpacing.sm),
      // 날짜 범위가 줄을 넘기지 않게 이쪽이 먼저 줄어든다. 화살표는 손이 닿는
      // 크기가 있어야 해서 줄일 수 없고, 날짜는 통째로 작게 그려도 읽힌다 —
      // 좁은 폭(360)에 큰 글자 배율(1.3)이 겹치면 그 차이가 69px 이다(#1009).
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            l.dateRange(
              l.dateMonthDay(start.month, start.day),
              l.dateMonthDay(end.month, end.day),
            ),
            maxLines: 1,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      _ChevronButton(
        icon: Icons.chevron_right,
        tooltip: l.a11yNextDay,
        onTap: () => onShift(1),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _singleRowMinWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(children: nav),
              const SizedBox(height: AppSpacing.sm),
              // 줄이 갈려도 오른쪽 끝에 맞춘다는 규칙은 지킨다.
              Align(alignment: Alignment.centerRight, child: trailing),
            ],
          );
        }
        return Row(children: <Widget>[...nav, const Spacer(), trailing]);
      },
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  /// 화살표 하나뿐이라 어느 쪽으로 가는지 말할 데가 툴팁뿐이다(#972).
  final String tooltip;

  final IconData icon;
  final VoidCallback onTap;

  /// 원의 지름. 회원 앱 식단 탭의 날짜 화살표와 같은 값이다 — 두 앱이 같은
  /// 동작에 다른 크기를 쓸 이유가 없다. 손가락이 닿는 최소치(44)보다 작으므로
  /// [_tapPadding] 으로 탭 영역을 넓혀 둔다.
  static const double _diameter = 28;

  /// 원 바깥으로 넓히는 탭 영역. 보이는 원은 30 이지만 실제로 눌리는 범위는
  /// 44 다 — 작은 원을 정확히 겨누게 만들 이유가 없다.
  static const double _tapPadding = 7;

  @override
  Widget build(BuildContext context) {
    // 색을 아이콘이 아니라 **원 영역**에 준다. 배경 없는 회색 아이콘이던 때에는
    // 어디까지가 눌리는 범위인지 형태로 알 수 없었고, 주변 글씨와 같은 계열이라
    // "누르는 것" 으로 읽히지도 않았다(#1009).
    //
    // 표현은 회원 앱 식단 탭의 날짜 화살표를 그대로 따른다 — 연한 남색 원에
    // 남색 화살표다. 채운 남색에 흰 화살표를 쓰면 그 줄에서 가장 무거운 요소가
    // 되어, 정작 읽어야 할 날짜보다 먼저 눈에 들어온다.
    //
    // 주 이동에는 제한이 없다 — 앞뒤 어느 쪽으로든 갈 수 있어야 하므로 비활성
    // 상태를 만들지 않는다.
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: _diameter / 2 + _tapPadding,
          child: Padding(
            padding: const EdgeInsets.all(_tapPadding),
            child: Container(
              key: ValueKey<String>('schedule-week-arrow-${icon.codePoint}'),
              width: _diameter,
              height: _diameter,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentSurface,
              ),
              child: Icon(icon, size: 16, color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}
