import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/layout.dart';

/// Centers its child and caps its width. The shell used to cap all tab
/// content at [AppLayout.contentMaxWidth]; with the master-detail split
/// the 고객 탭 needs more room, so each page now frames itself.
class ContentFrame extends StatelessWidget {
  /// Creates a centered, width-capped frame.
  const ContentFrame({
    super.key,
    this.maxWidth = AppLayout.contentMaxWidth,
    required this.child,
  });

  /// The width cap (defaults to the single-column content width).
  final double maxWidth;

  /// Framed content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
