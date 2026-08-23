import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 리포트 카드의 주 이동 — `‹ 8월 17일 – 8월 23일 ›`.
///
/// 헤더가 아니라 **리포트 카드 제목 줄**에 있다. 옮기는 것은 이 카드의
/// 내용이지 화면 전체가 아니고, 헤더에 두면 날짜 버튼 하나가 가운데 고객
/// 검색 바의 폭을 먹어 다른 탭과 다른 모양으로 접혔다(#1177).
class ReportWeekNav extends StatelessWidget {
  /// Creates the week nav.
  const ReportWeekNav({
    super.key,
    required this.rangeLabel,
    required this.onPrev,
    required this.onNext,
  });

  /// 보고 있는 주(`8월 17일 – 8월 23일`).
  final String rangeLabel;

  final VoidCallback onPrev;

  /// 다음 주로. 가장 최근 주를 보고 있으면 null — 화살표가 회색으로 죽는다.
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Chevron(
          navKey: const ValueKey<String>('report-week-prev'),
          icon: Icons.chevron_left,
          tooltip: l.a11yPrevWeek,
          onTap: onPrev,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          rangeLabel,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        _Chevron(
          navKey: const ValueKey<String>('report-week-next'),
          icon: Icons.chevron_right,
          tooltip: l.a11yNextWeek,
          onTap: onNext,
        ),
      ],
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({
    required this.navKey,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final Key navKey;
  final IconData icon;

  /// 화살표 하나뿐이라 어느 쪽으로 가는지 말할 데가 툴팁뿐이다.
  final String tooltip;

  /// null 이면 더 갈 곳이 없다 — 누를 수 없고, 회색으로 그린다.
  final VoidCallback? onTap;

  /// 스케줄 탭 주 이동 화살표와 같은 지름이다.
  static const double _diameter = 26;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        excludeSemantics: true,
        child: InkResponse(
          key: navKey,
          onTap: onTap,
          radius: _diameter / 2 + 6,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Container(
              width: _diameter,
              height: _diameter,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled
                    ? AppColors.accentSurface
                    : AppColors.inputBackground,
              ),
              child: Icon(
                icon,
                size: 16,
                color: enabled
                    ? AppColors.primary
                    : AppColors.disabledForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
