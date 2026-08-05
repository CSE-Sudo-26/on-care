import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// Standard frame for a console page: a sticky header (title, optional
/// subtitle, right-aligned actions) above width-capped content.
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
    required this.maxWidth,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
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
          child: Row(
            children: <Widget>[
              Expanded(
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
              for (final action in actions) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
