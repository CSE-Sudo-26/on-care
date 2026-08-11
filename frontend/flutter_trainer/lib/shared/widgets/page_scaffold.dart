import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// Standard frame for a console page: a sticky header (title, optional
/// subtitle, an optional centred slot, right-aligned actions) above
/// width-capped content.
///
/// Every top-level page uses this so the header sits at the same height
/// across branches — switching tabs shouldn't make the title jump.
class PageScaffold extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final body = scrollable
        ? SingleChildScrollView(padding: contentPadding, child: _capped(child))
        : Padding(padding: contentPadding, child: _capped(child));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Header(
          title: title,
          subtitle: subtitle,
          actions: actions,
          center: headerCenter,
          maxWidth: maxWidth,
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _capped(Widget content) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
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
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
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
    final centerWidth = (size.width - sideWidth * 2).clamp(0.0, size.width);
    final centerSize = layoutChild(
      _HeaderSlot.center,
      BoxConstraints.tightFor(width: centerWidth, height: size.height),
    );
    positionChild(
      _HeaderSlot.center,
      Offset((size.width - centerSize.width) / 2, 0),
    );
  }

  @override
  bool shouldRelayout(_HeaderLayoutDelegate oldDelegate) =>
      hasCenter != oldDelegate.hasCenter;
}
