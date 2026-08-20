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
      _ChevronButton(icon: Icons.chevron_left, onTap: () => onShift(-1)),
      const SizedBox(width: AppSpacing.sm),
      Text(
        l.dateRange(
          l.dateMonthDay(start.month, start.day),
          l.dateMonthDay(end.month, end.day),
        ),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.foreground,
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      _ChevronButton(icon: Icons.chevron_right, onTap: () => onShift(1)),
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
  const _ChevronButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 44,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Icon(icon, size: 20, color: AppColors.mutedForeground),
        ),
      ),
    );
  }
}
