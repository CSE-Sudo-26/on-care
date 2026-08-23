import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/shared/widgets/page_scroll_reset.dart';

/// Standard frame for a console page: a sticky header (title, optional
/// subtitle, an optional centred slot, right-aligned actions) above
/// width-capped content.
///
/// Every top-level page uses this so the header sits at the same height
/// across branches — switching tabs shouldn't make the title jump.
class PageScaffold extends StatefulWidget {
  /// Creates a page frame.
  const PageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const <Widget>[],
    this.headerCenter,
    this.maxWidth = AppLayout.wideMaxWidth,
    this.scrollable = true,
    this.contentPadding = const EdgeInsets.all(AppLayout.pagePadding),
  });

  /// Page title (e.g. 대시보드).
  final String title;

  /// Optional second line under the title (date, count, context).
  final String? subtitle;

  /// Right-aligned header actions.
  final List<Widget> actions;

  /// Widget centred between the title and the actions — the console's
  /// 고객 검색 bar.
  ///
  /// Handed in by the page rather than built here: this frame lives in
  /// `shared/`, which must not reach into a feature (STRUCTURE.md §2.4).
  /// It gets whatever width the title and actions leave over, so a
  /// header with many actions squeezes it instead of overflowing.
  final Widget? headerCenter;

  /// Page body.
  final Widget child;

  /// Width cap applied to the body (and the header, so they align).
  final double maxWidth;

  /// Whether the body scrolls. Pages that manage their own scrolling
  /// (chat, split panels, calendars) pass `false` and fill the space.
  final bool scrollable;

  /// Padding around the body.
  final EdgeInsets contentPadding;

  @override
  State<PageScaffold> createState() => _PageScaffoldState();
}

class _PageScaffoldState extends State<PageScaffold> {
  final Set<ScrollPosition> _topLevelPositions = <ScrollPosition>{};
  ValueNotifier<int>? _resetNotifier;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = PageScrollResetScope.maybeOf(context);
    if (identical(next, _resetNotifier)) return;
    _resetNotifier?.removeListener(_resetScroll);
    _resetNotifier = next;
    _resetNotifier?.addListener(_resetScroll);
  }

  @override
  void dispose() {
    _resetNotifier?.removeListener(_resetScroll);
    super.dispose();
  }

  void _resetScroll() {
    if (!TickerMode.valuesOf(context).enabled) return;
    _topLevelPositions.removeWhere(
      (position) => !position.context.storageContext.mounted,
    );
    for (final position in _topLevelPositions) {
      if (position.hasPixels && position.pixels != position.minScrollExtent) {
        position.jumpTo(position.minScrollExtent);
      }
    }
  }

  bool _rememberScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final notificationContext = notification.context;
    if (notificationContext != null) {
      final scrollable = Scrollable.maybeOf(notificationContext);
      if (scrollable != null) _topLevelPositions.add(scrollable.position);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final body = widget.scrollable
        ? SingleChildScrollView(
            child: _capped(
              Padding(padding: widget.contentPadding, child: widget.child),
            ),
          )
        : _capped(Padding(padding: widget.contentPadding, child: widget.child));

    return NotificationListener<ScrollNotification>(
      onNotification: _rememberScroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Header(
            title: widget.title,
            subtitle: widget.subtitle,
            actions: widget.actions,
            center: widget.headerCenter,
            maxWidth: widget.maxWidth,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _capped(Widget content) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: content,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.center,
    required this.maxWidth,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? center;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppLayout.pageHeaderHeight,
      // The header sits ON the content canvas, not on a white bar: the
      // title reads as the page's own heading rather than a second piece
      // of chrome stacked under the sidebar. No rule underneath either —
      // the sidebar's edge is the only structural line on screen.
      color: AppColors.background,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppLayout.pagePadding,
          ),
          child: CustomMultiChildLayout(
            delegate: _HeaderLayoutDelegate(hasCenter: center != null),
            children: <Widget>[
              LayoutId(
                id: _HeaderSlot.start,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 화면 이름은 줄임표로 줄이지 않는다 — `My prof…` 이 되면
                    // 지금 어느 화면인지가 사라진다. 액션이 많은 화면에서 자리가
                    // 모자라면 글씨를 줄인다. (#1004)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        title,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.subtleForeground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (center != null)
                LayoutId(
                  id: _HeaderSlot.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: center,
                  ),
                ),
              LayoutId(
                id: _HeaderSlot.end,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (var i = 0; i < actions.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      actions[i],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _HeaderSlot { start, center, end }

/// Keeps the optional centre control on the header's physical centre.
///
/// The title and actions are measured first. The larger of their widths is
/// reserved on *both* sides, so changing tabs cannot pull the search field
/// towards whichever side happens to be shorter. When space is tight the
/// centre child receives the smaller remaining width and can collapse itself.
class _HeaderLayoutDelegate extends MultiChildLayoutDelegate {
  _HeaderLayoutDelegate({required this.hasCenter});

  final bool hasCenter;

  @override
  void performLayout(Size size) {
    final loose = BoxConstraints.loose(size);
    final endSize = layoutChild(_HeaderSlot.end, loose);
    final startWidth = size.width - endSize.width - AppSpacing.sm;
    final startSize = layoutChild(
      _HeaderSlot.start,
      BoxConstraints(
        maxWidth: startWidth > 0 ? startWidth : 0,
        maxHeight: size.height,
      ),
    );
    positionChild(
      _HeaderSlot.start,
      Offset(0, (size.height - startSize.height) / 2),
    );
    positionChild(
      _HeaderSlot.end,
      Offset(size.width - endSize.width, (size.height - endSize.height) / 2),
    );

    if (!hasCenter) return;
    final sideWidth = startSize.width > endSize.width
        ? startSize.width
        : endSize.width;
    double centerWidth = (size.width - sideWidth * 2).clamp(0.0, size.width);
    double centerLeft = (size.width - centerWidth) / 2;

    // 대칭 예약이 가운데를 굶기면 대칭을 포기한다 (#995).
    //
    // 좌우에 같은 폭을 예약하는 것은 탭을 옮겨도 검색 바가 제자리에 있게 하려는
    // 것인데, 액션이 많은 화면(리포트)에서는 그 예약 때문에 가운데가 인라인
    // 최소 폭 아래로 떨어져 검색 바가 통째로 아이콘으로 접혔다. 글씨를 키우면
    // 액션 폭이 함께 늘어 더 자주 걸린다. 자리를 못 지키는 것보다 가운데가
    // 조금 치우치는 편이 낫다.
    if (centerWidth < AppLayout.headerCenterMinWidth) {
      final double gap =
          size.width - startSize.width - endSize.width - AppSpacing.sm * 2;
      if (gap > centerWidth) {
        centerWidth = gap.clamp(0.0, size.width);
        centerLeft = startSize.width + AppSpacing.sm;
      }
    }

    layoutChild(
      _HeaderSlot.center,
      BoxConstraints.tightFor(width: centerWidth, height: size.height),
    );
    positionChild(_HeaderSlot.center, Offset(centerLeft, 0));
  }

  @override
  bool shouldRelayout(_HeaderLayoutDelegate oldDelegate) =>
      hasCenter != oldDelegate.hasCenter;
}
