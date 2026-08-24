import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';

/// 리포트 카드의 주 이동 — `‹ 8월 17일 – 8월 23일 [이번 주] ›`.
///
/// 스케줄 탭의 날짜 줄과 같은 짜임이다(화살표 · 날짜 · 화살표 · 되돌리기 버튼).
/// 두 탭이 같은 동작에 다른 모양을 쓸 이유가 없다.
///
/// 헤더가 아니라 **리포트 카드 제목 줄**에 있다. 옮기는 것은 이 카드의
/// 내용이지 화면 전체가 아니고, 헤더에 두면 날짜 버튼 하나가 가운데 고객
/// 검색 바의 폭을 먹어 다른 탭과 다른 모양으로 접혔다(#1177).
///
/// 이 줄은 카드 제목(`Expanded`) 오른쪽에 자기 폭만큼만 차지하고 붙는다 —
/// 날짜·화살표 묶음 양옆에 `이번 주` 버튼과 같은 폭을 둔다. 버튼 표시 여부와
/// 무관하게 탐색 묶음의 중심이 이 위젯 중심에 고정된다(#1245, #1295).
class ReportWeekNav extends StatelessWidget {
  /// Creates the week nav.
  const ReportWeekNav({
    super.key,
    required this.rangeLabel,
    required this.onPrev,
    required this.onNext,
    required this.onThisWeek,
  });

  /// 보고 있는 주(`8월 17일 – 8월 23일`).
  final String rangeLabel;

  final VoidCallback onPrev;

  /// 다음 주로. 가장 최근 주를 보고 있으면 null — 화살표가 회색으로 죽는다.
  final VoidCallback? onNext;

  /// 이번 주로 돌아간다. 이미 이번 주면 null — 버튼을 아예 그리지 않는다
  /// (스케줄 탭 `오늘` 과 같다). 자리는 [_thisWeekSlot] 이 대신 지킨다.
  final VoidCallback? onThisWeek;

  /// 날짜가 앉는 자리의 폭. 스케줄 탭 날짜 행(`ScheduleDateNavBar._dateSlot`)과
  /// 같은 형식(`8월 17일 – 8월 23일`)을 쓰므로 자리도 그대로 맞춘다.
  static const double _dateSlot = 150;

  /// `이번 주` 가 앉는 자리의 폭. 버튼을 그리지 않을 때도 이 자리는 비워
  /// 두어야 화살표가 밀리지 않는다.
  static const double _thisWeekSlot = 100;

  static const double _gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 오른쪽 `이번 주` 자리와 같은 폭을 먼저 비워 날짜·화살표 묶음이
        // 버튼 유무와 관계없이 전체 헤더의 정중앙에 선다(#1295).
        const SizedBox(
          key: ValueKey<String>('report-week-balance-slot'),
          width: _thisWeekSlot,
        ),
        const SizedBox(width: _gap),
        _Chevron(
          navKey: const ValueKey<String>('report-week-prev'),
          icon: Icons.chevron_left,
          tooltip: l.a11yPrevWeek,
          onTap: onPrev,
        ),
        const SizedBox(width: _gap),
        SizedBox(
          width: _dateSlot,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                rangeLabel,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: _gap),
        _Chevron(
          navKey: const ValueKey<String>('report-week-next'),
          icon: Icons.chevron_right,
          tooltip: l.a11yNextWeek,
          onTap: onNext,
        ),
        const SizedBox(width: _gap),
        // 스케줄 탭의 `오늘` 과 같은 자리다. 헤더에 있던 때에는 옮기는
        // 대상(리포트)과 버튼이 서로 다른 줄에 있어, 무엇을 이번 주로
        // 되돌리는지 자리로 이어지지 않았다(#1177).
        SizedBox(
          width: _thisWeekSlot,
          child: onThisWeek == null
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ActionButton(
                      key: const ValueKey<String>('reports-go-this-week'),
                      label: l.reportsThisWeek,
                      icon: Icons.today_outlined,
                      onPressed: onThisWeek,
                    ),
                  ),
                ),
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
