import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/dashboard/presentation/widgets/dashboard_content.dart';
import 'package:oncare/shared/widgets/modals/schedule_calendar_sheet.dart';

/// Home tab. The header now scrolls with the content (per the Figma redesign),
/// so the page is just a surface that hosts [DashboardContent]; the floating
/// Oni assistant lives globally in [MainShell].
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: DashboardContent(
          onNotificationTap: () => context.push(AppRoutes.notification),
          onCalendarTap: () => showScheduleCalendarSheet(context),
        ),
      ),
    );
  }
}
