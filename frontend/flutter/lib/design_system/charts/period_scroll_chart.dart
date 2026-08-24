import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oncare/design_system/charts/chart_reveal.dart';
import 'package:oncare/design_system/charts/goal_line.dart';
import 'package:oncare/design_system/tokens/colors.dart';

/// `전체` 그래프의 선택·보이는 구간 상태. (#1018)
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

/// 축 라벨 한 칸의 폭. 가장 긴 날짜(`12/31`)가 글자 배율을 올려도 들어가도록
/// 넉넉히 잡는다 — 넘치면 잘리지는 않지만 옆 라벨과 가까워진다. 라벨끼리는
/// [PeriodScrollChart.labelBuilder] 가 빈 문자열로 띄워 두는 간격만큼 떨어져
/// 있어서(30칸 화면에서 열네 칸), 이 폭이 서로 겹칠 일은 없다.
const double _axisLabelWidth = 52;

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
    this.topGap = 0,
    this.revealKey,
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

  /// 그래프 바닥에서 목표선까지의 거리. null 이면 목표선을 긋지 않는다.
  /// 선은 칸 전체 폭에 걸쳐야 하므로 스크롤 **안쪽**에 얹고, 목표치 라벨은
  /// 밀려도 늘 보이도록 스크롤 **바깥** 왼쪽 칸에 앉힌다. (#1071)
  final double? goalBottom;

  /// 왼쪽 칸에 앉는 두 줄 라벨(`목표` / 목표치).
  final String? goalLabel;

  /// 목표치 글씨 모양. 자리는 모든 그래프가 같고 색·굵기만 화면을 따른다.
  final TextStyle goalLabelStyle;

  /// 한 화면에 보일 날 수.
  final int daysPerScreen;

  /// 막대가 바닥에서 다시 자라는 조건. 기본은 칸 수라, 기간이 바뀔 때만 다시
  /// 자란다. 지표를 바꿔도 다시 자라야 하는 화면(식단 나트륨·당류, #1148)은
  /// 여기에 그 지표를 함께 넣어 준다.
  ///
  /// **막대를 고를 때 바뀌는 값을 넣지 말 것** — 누를 때마다 그래프가 다시
  /// 자라 눌러 읽는 동작을 방해한다(#1058).
  final Object? revealKey;

  /// 그래프 위에 얹을 빈 칸. 고른 날의 세로선이 이 칸까지 올라와 **위의 머리
  /// 카드에 닿는다** — 선이 중간에서 끊기면 그 카드가 어느 막대의 것인지
  /// 말해 주지 못한다. (#1123)
  final double topGap;

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
    // 화면에서 사라진다.
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
        final double contentWidth = math.max(slot * widget.count, viewport);
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
            width: contentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  height: widget.height + widget.topGap,
                  child: Stack(
                    children: <Widget>[
                      if (widget.goalBottom != null)
                        GoalLineOverlay(bottom: widget.goalBottom!),
                      if (widget.selectedIndex != null)
                        _SelectionLine(
                          left: slot * widget.selectedIndex! + slot / 2,
                          height: widget.height + widget.topGap,
                        ),
                      // 막대는 바닥에서 자라 오른다 (#1058). 기간을 바꿔 들어온
                      // 그림이 그냥 나타나면, 다른 기간에서 넘어왔는지 처음부터
                      // 그랬는지 구분되지 않는다.
                      //
                      // 되감기는 칸 수가 바뀔 때만 한다 — 막대를 고를 때마다
                      // 다시 자라면 눌러 읽는 동작을 방해한다.
                      // 막대는 빈 칸 아래에서만 자란다 — 빈 칸은 세로선이
                      // 머리 카드까지 올라갈 자리다.
                      // 자라는 막대 줄은 **바닥에 붙인다** (#1200). `Stack` 은
                      // 자리를 정하지 않은 자식을 위쪽 모서리에 두므로, 높이가
                      // t 를 따라 커지는 이 줄이 위에 매달린 채 아래로
                      // 내려왔다 — 막대가 자라는 것이 아니라 그래프가 통째로
                      // 내려오는 것처럼 보였다.
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: EdgeInsets.only(top: widget.topGap),
                          child: ChartReveal(
                            replayKey: widget.revealKey ?? widget.count,
                            builder: (BuildContext context, double t) => Row(
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
                                      // 자라는 동안 위쪽이 잘려 보이도록 감싼다 —
                                      // 자르지 않으면 막대가 줄어든 상자 밖으로
                                      // 삐져나와 그대로 다 보인다.
                                      child: ClipRect(
                                        key: ValueKey<String>(
                                          'period-bar-reveal-$i',
                                        ),
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          heightFactor: t,
                                          child: widget.barBuilder(context, i),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // 라벨은 칸보다 넓다 — 한 화면에 30칸이면 칸은 10px 남짓인데
                // `12/31` 은 그 두 배가 넘는다. 칸 안에 앉히면 글자가 칸
                // 경계에서 잘려 `666`, `77` 처럼 읽혔다(#1240). 칸 가운데를
                // 기준으로 라벨에 제 폭을 주어 얹는다 — 어느 칸이 몇 일인지
                // 적는 것이 이 줄의 유일한 일이라, 자리를 칸에 맞추는 것보다
                // 글자가 온전한 것이 먼저다.
                SizedBox(
                  height: 14,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      for (int i = 0; i < widget.count; i++)
                        if (widget.labelBuilder(i).isNotEmpty)
                          Positioned(
                            // 양 끝 라벨은 그래프 폭 안으로 당긴다 — 밖으로
                            // 나간 만큼은 스크롤 뷰가 잘라 버린다.
                            left: (slot * i + slot / 2 - _axisLabelWidth / 2)
                                .clamp(
                                  0.0,
                                  math.max(contentWidth - _axisLabelWidth, 0.0),
                                ),
                            width: _axisLabelWidth,
                            child: Text(
                              widget.labelBuilder(i),
                              maxLines: 1,
                              // 줄바꿈도 줄임표도 두지 않는다. 글자가 제 폭을
                              // 넘기면 칸 가운데를 기준으로 좌우로 넘쳐 나가고,
                              // 그래야 날짜가 온전히 읽힌다.
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mutedForeground,
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
