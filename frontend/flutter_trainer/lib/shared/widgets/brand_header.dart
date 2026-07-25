import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// Slim global app bar shown on every signed-in screen (mock: the
/// "On-Care 트레이너" strip at the top of each trainer screen). The
/// "트레이너" word keeps the orange identity accent; everything else
/// follows the blue-primary service palette.
class BrandHeader extends StatelessWidget implements PreferredSizeWidget {
  /// Creates the brand header.
  const BrandHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 44,
      titleSpacing: AppSpacing.lg,
      automaticallyImplyLeading: false,
      shape: const Border(bottom: BorderSide(color: AppColors.borderStrong)),
      title: Row(
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentSurface,
            ),
            child: const Text('🧑', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: 'On-Care ',
                  style: TextStyle(color: AppColors.foreground),
                ),
                TextSpan(
                  text: '트레이너',
                  style: TextStyle(color: AppColors.brandOrange),
                ),
              ],
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
