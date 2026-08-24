import 'package:flutter/material.dart';

/// Delivers page-navigation events to the active top-level page.
///
/// The indexed navigation shell deliberately keeps every branch alive. That
/// preserves useful page state, but it must not preserve the viewport when a
/// trainer explicitly navigates to a page: the destination should open at its
/// beginning.
class PageScrollResetScope extends InheritedNotifier<ValueNotifier<int>> {
  /// Creates a reset scope around the trainer navigation shell.
  const PageScrollResetScope({
    super.key,
    required ValueNotifier<int> notifier,
    required super.child,
  }) : super(notifier: notifier);

  /// Returns the navigation reset notifier for the surrounding shell.
  static ValueNotifier<int>? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PageScrollResetScope>()
      ?.notifier;
}
