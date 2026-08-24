import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/shared/widgets/goal_line.dart';

/// `전체` 그래프의 선택·보이는 구간 상태. (#1018)
///
/// 회원 앱 `design_system/charts/period_scroll_chart.dart` 와 같은 내용이다. 두
/// 앱은 서로 다른 패키지라 위젯을 공유할 수 없어, 같은 그림을 두 곳에 둔다.
///
/// 머리의 숫자(평균 또는 고른 날의 값)와 막대는 서로 다른 위젯이 그리는데 같은
/// 상태를 봐야 한다. 부모가 들고 있다가 둘에게 건넨다.
class PeriodChartSelection extends ChangeNotifier {
  int? _selected;
  (int, int)? _visible;

  /// 고른 칸. null 이면 머리 숫자가 평균이다.
  int? get selected => _selected;

  /// 화면에 보이는 구간(첫 칸, 끝 칸). null 이면 아직 재지 않았다 = 전 구간.
  (int, int)? get visible => _visible;

  void select(int? index) {
    if (_selected == index) return;
    _selected = index;
    notifyListeners();
  }

  void setVisible(int first, int last) {
    if (_visible != null && _visible!.$1 == first && _visible!.$2 == last) {
      return;
    }
    _visible = (first, last);
    notifyListeners();
  }

  /// 지표나 기간을 바꾸면 고른 날은 뜻을 잃는다 — 같이 푼다.
  void reset() {
    if (_selected == null) return;
    _selected = null;
    notifyListeners();
  }

  /// 보이는 구간의 평균. 기록이 없는 날(0)은 빼고 낸다 — 넣으면 "적게 먹었다"
  /// 와 "기록을 안 했다" 가 같은 숫자가 된다.
  double averageOf(List<double> values) {
    if (values.isEmpty) return 0;
    final (int first, int last) = _visible ?? (0, values.length - 1);
    double sum = 0;
    int count = 0;
    for (int i = first; i <= last && i < values.length; i++) {
      if (values[i] > 0) {
        sum += values[i];
        count += 1;
      }
    }
    return count == 0 ? 0 : sum / count;
  }
}

/// `전체` 기간 그래프의 뼈대 — 가로 스크롤 + 날짜 선택. (#1018)
///
/// 예전에는 한 달치를 한 화면에 욱여넣어 막대가 실처럼 얇았고, 그 앞의 기록은
/// 볼 방법이 아예 없었다. 아이폰 건강 앱의 1개월 그래프처럼 **한 화면에 30일**을
/// 두고 옆으로 밀어 과거를 본다.
///
/// 막대를 그리는 일은 하지 않는다. 식단은 탄단지를, 운동은 유산소·근력·스트레칭을
/// 쌓아 그리는데 그 색이 각 화면이 말하려는 내용이라, 뼈대가 단색으로 통일해
/// 버리면 그림이 뜻을 잃는다. 그래서 칸 하나를 [barBuilder] 가 그리고 여기서는
/// 자리와 선택만 맡는다.
class PeriodScrollChart extends StatefulWidget {
  const PeriodScrollChart({
    super.key,
    required this.count,
    required this.height,
    required this.barBuilder,
    required this.labelBuilder,
    required this.onVisibleRangeChanged,
    required this.calloutBuilder,
    this.selectedIndex,
    this.onSelected,
    this.goalBottom,
    this.goalLabel,
    this.goalLabelStyle = ChartGoalAxis.defaultStyle,
    this.daysPerScreen = 30,
  });

  /// 칸 개수(= 날짜 수). 0 이면 아무것도 그리지 않는다.
  final int count;

  /// 막대가 그려지는 높이(라벨 줄 제외).
  final double height;

  /// [i] 번째 날의 막대. 칸 폭에 맞춰 그려진다.
  final Widget Function(BuildContext context, int i) barBuilder;

  /// [i] 번째 날의 축 라벨. 빈 문자열이면 적지 않는다 — 30칸에 날짜를 모두
  /// 적으면 서로 겹친다.
  final String Function(int i) labelBuilder;

  /// 화면에 보이는 구간이 바뀔 때마다 부른다. 머리의 평균이 이 구간을 따른다 —
  /// 보이지 않는 날까지 섞은 평균은 지금 보고 있는 그림을 설명하지 못한다.
  final void Function(int first, int last) onVisibleRangeChanged;

  /// 고른 날 위에 뜨는 회색 상자의 내용.
  final Widget Function(BuildContext context, int i) calloutBuilder;

  final int? selectedIndex;
  final void Function(int? i)? onSelected;

  /// 목표선. 칸 전체 폭에 걸쳐 그려지도록 스크롤 안쪽에 얹는다.
  final double? goalBottom;

  /// 왼쪽 칸에 앉는 두 줄 라벨(`목표` / 목표치).
  final String? goalLabel;

  /// 목표치 글씨 모양. 자리는 모든 그래프가 같고 색·굵기만 화면을 따른다.
  final TextStyle goalLabelStyle;

  /// 한 화면에 보일 날 수.
  final int daysPerScreen;

  @override
  State<PeriodScrollChart> createState() => _PeriodScrollChartState();
}

class _PeriodScrollChartState extends State<PeriodScrollChart> {
  final ScrollController _controller = ScrollController();
  double _slot = 0;
  double _viewport = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_reportVisible);
  }

  @override
  void dispose() {
    _controller.removeListener(_reportVisible);
    _controller.dispose();
    super.dispose();
  }

  void _reportVisible() {
    if (_slot <= 0 || _viewport <= 0) return;
    final double offset = _controller.hasClients ? _controller.offset : 0;
    final int first = (offset / _slot).floor().clamp(0, widget.count - 1);
    final int last = ((offset + _viewport) / _slot).ceil() - 1;
    widget.onVisibleRangeChanged(first, last.clamp(first, widget.count - 1));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count == 0) return SizedBox(height: widget.height);
    // 목표치 칸은 스크롤 바깥에 둔다 — 안에 두면 옆으로 밀 때 같이 흘러가
    // 화면에서 사라진다. (#1071)
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ChartGoalAxis(
          height: widget.height,
          label: widget.goalLabel,
          lineBottom: widget.goalBottom,
          style: widget.goalLabelStyle,
        ),
        const SizedBox(width: chartGoalAxisGap),
        Expanded(child: _scroller(context)),
      ],
    );
  }

  Widget _scroller(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double viewport = constraints.maxWidth;
        final double slot = viewport / widget.daysPerScreen;
        final bool changed = slot != _slot || viewport != _viewport;
        _slot = slot;
        _viewport = viewport;
        if (changed) {
          // 처음 열면 최근(오른쪽 끝)이다 — 사람이 먼저 궁금해하는 것은 어제와
          // 오늘이지 석 달 전이 아니다.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_controller.hasClients) return;
            _controller.jumpTo(_controller.position.maxScrollExtent);
            _reportVisible();
          });
        }
        return SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          // 칸이 화면보다 적으면 스크롤할 것이 없다.
          physics: widget.count <= widget.daysPerScreen
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          child: SizedBox(
            width: math.max(slot * widget.count, viewport),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  height: widget.height,
                  child: Stack(
                    children: <Widget>[
                      if (widget.selectedIndex != null)
                        _SelectionLine(
                          left: slot * widget.selectedIndex! + slot / 2,
                          height: widget.height,
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          for (int i = 0; i < widget.count; i++)
                            SizedBox(
                              width: slot,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => widget.onSelected?.call(
                                  widget.selectedIndex == i ? null : i,
                                ),
                                child: widget.barBuilder(context, i),
                              ),
                            ),
                        ],
                      ),
                      // 목표선은 막대 **위**에 얹는다. 뒤에 깔면 목표에 가까운
                      // 막대가 `목표 N` 라벨을 덮어, 정작 견줄 기준이 안 보인다.
                      // 점선이라 데이터와 경쟁하지도 않는다.
                      if (widget.goalBottom != null)
                        GoalLineOverlay(bottom: widget.goalBottom!),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 14,
                  child: Row(
                    children: <Widget>[
                      for (int i = 0; i < widget.count; i++)
                        SizedBox(
                          width: slot,
                          child: Center(
                            child: Text(
                              widget.labelBuilder(i),
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 고른 날에 서는 회색 세로선.
class _SelectionLine extends StatelessWidget {
  const _SelectionLine({required this.left, required this.height});

  final double left;
  final double height;

  @override
  Widget build(BuildContext context) => Positioned(
    left: left - 0.5,
    top: 0,
    child: Container(height: height, width: 1, color: AppColors.chartGoalLine),
  );
}

/// 머리에 뜨는 값 — 평소에는 보이는 구간의 평균, 날을 고르면 그날의 값.
///
/// 회색 상자는 **고른 날에만** 씌운다. 평균일 때도 상자를 두면 화면에 늘 회색
/// 덩어리가 있어, 무언가를 고른 상태인지 아닌지가 구분되지 않는다.
class PeriodChartHeadline extends StatelessWidget {
  const PeriodChartHeadline({
    super.key,
    required this.selected,
    required this.child,
  });

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!selected) return child;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}
