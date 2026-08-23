import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 날짜 내비게이션 행 — `◀   8월 17일 – 8월 23일   오늘   ▶` 그리고 오른쪽
/// 끝(일요일 칸 위)의 `+ 새 일정`. (#882, #1009)
///
/// **날짜는 두 화살표 사이의 한가운데에 선다.** `오늘` 이 들어설 자리를 날짜
/// 오른쪽에만 비워 두었더니 날짜가 그만큼 왼쪽으로 치우쳐, 화살표 사이의
/// 가운데가 아니었다. 같은 폭을 왼쪽에도 빈 자리로 두어 균형을 맞춘다.
///
/// `새 일정` 은 이 묶음과 떨어져 행의 맨 오른쪽에 선다 — 시간표의 일요일
/// 칸과 같은 자리라, 일정을 어느 주에 더할지가 시선으로 이어진다.
///
/// **화살표는 자리를 지킨다.** 날짜 글자 수가 달라지거나 `오늘` 이 나타났다
/// 사라져도 두 화살표가 움직이지 않는다. 움직이면 같은 버튼을 누르려고 매번
/// 다른 자리를 겨눠야 하고, 주를 연달아 넘길 때 그 차이가 그대로 손에 걸린다.
///
/// 그래서 날짜와 `오늘` 에 **고정 폭 자리**를 준다. `오늘` 은 보이지 않을 때도
/// 자리를 비워 두므로, 버튼이 생겨도 날짜가 화살표 사이 한가운데에 그대로
/// 남는다.
///
/// 좁은 폭에서는 줄을 가르지 않고 묶음째 작게 그린다 — 줄이 갈리면 화살표가
/// 자리를 지킨다는 규칙이 그 순간 깨진다.
class ScheduleDateNavBar extends StatelessWidget {
  const ScheduleDateNavBar({
    super.key,
    required this.start,
    required this.end,
    required this.onShift,
    required this.trailing,
    this.newSession,
  });

  /// 보이는 창의 첫날.
  final DateTime start;

  /// 보이는 창의 마지막 날.
  final DateTime end;

  /// -1 = 이전 주, +1 = 다음 주.
  final ValueChanged<int> onShift;

  /// 날짜와 오른쪽 화살표 사이에 서는 컨트롤(`오늘`). 비어 있어도 자리는 남는다.
  final Widget trailing;

  /// 화살표·날짜 묶음과 떨어져 이 행의 맨 오른쪽(일요일 칸 위)에 서는 동작
  /// (`+ 새 일정`). 없으면 그 자리를 비운다.
  final Widget? newSession;

  /// 날짜가 앉는 자리의 폭. 한국어 `8월 17일 – 8월 23일`, 영어 `Aug 17 – Aug 23`
  /// 이 글씨 배율 1.1 에서 들어가는 값이다. 넘치면 그 안에서 작게 그린다.
  static const double _dateSlot = 186;

  /// `오늘` 이 앉는 자리의 폭. 버튼이 없을 때도 비워 두어야 날짜가 움직이지
  /// 않는다. 자리가 고정이므로 **버튼이 그 안에서 줄어든다** — 넘치게 두면
  /// 글자 배율이 큰 환경에서 그대로 오버플로가 된다.
  ///
  /// 같은 폭이 **날짜 왼쪽에도 빈 자리로** 선다. 오른쪽에만 두었더니 날짜가
  /// 그만큼 왼쪽으로 밀려, 두 화살표 사이에서 한가운데가 아니었다. 버튼이
  /// 들어설 자리를 양쪽에 똑같이 비워 두면 `오늘` 이 나타나도 날짜는 제자리에
  /// 남는다.
  static const double _todaySlot = 96;

  /// 요소 사이 간격. 화살표·날짜·`오늘` 이 서로 붙어 보이지 않을 만큼 띄운다.
  static const double _gap = AppSpacing.lg;

  /// `새 일정` 을 한 줄에 함께 담는 최소 폭. 아래로는 다음 줄로 내린다.
  static const double _singleRowMinWidth = 480;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final group = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ChevronButton(
          icon: Icons.chevron_left,
          tooltip: l.a11yPrevWeek,
          onTap: () => onShift(-1),
        ),
        const SizedBox(width: _gap),
        // `오늘` 자리의 거울. 아무것도 그리지 않지만 날짜를 두 화살표 사이의
        // 한가운데에 세우는 것은 이 빈 자리다.
        const SizedBox(width: _todaySlot),
        const SizedBox(width: _gap),
        SizedBox(
          width: _dateSlot,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
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
        ),
        const SizedBox(width: _gap),
        SizedBox(
          width: _todaySlot,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(fit: BoxFit.scaleDown, child: trailing),
          ),
        ),
        const SizedBox(width: _gap),
        _ChevronButton(
          icon: Icons.chevron_right,
          tooltip: l.a11yNextWeek,
          onTap: () => onShift(1),
        ),
      ],
    );

    // 화살표·날짜 묶음은 왼쪽 정렬, `새 일정` 은 오른쪽 끝(일요일 칸 위)이다.
    // 폭이 모자라면 묶음은 그 안에서 줄어들고, 새 일정은 다음 줄로 내린다 —
    // 둘을 한 줄에 우겨넣으면 좁은 화면에서 그대로 넘친다.
    final left = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: group,
    );
    if (newSession == null) {
      return Align(alignment: Alignment.centerLeft, child: left);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _singleRowMinWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              left,
              const SizedBox(height: AppSpacing.sm),
              Align(alignment: Alignment.centerRight, child: newSession),
            ],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(child: left),
            newSession!,
          ],
        );
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
