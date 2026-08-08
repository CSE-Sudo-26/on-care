import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/session/session_feature_reset.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/ai_coach/presentation/controllers/ai_coach_controller.dart';
import 'package:oncare/features/ai_coach/presentation/controllers/chat_controller.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/exercise/presentation/controllers/consultation_request_controller.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/my_health/presentation/controllers/my_health_controller.dart';
import 'package:oncare/features/notification/presentation/controllers/notification_controller.dart';
import 'package:oncare/features/schedule/presentation/controllers/schedule_controller.dart';

/// Connects session transitions to account-specific feature state.
///
/// Register every feature reset here. Riverpod overrides replace each other,
/// so this must remain the single app-level registry.
Override sessionFeatureResetOverride() {
  return sessionFeatureResetProvider.overrideWith((ref) {
    return () {
      // Stateful demo repositories must be recreated so one demo/account
      // cannot inherit another one's local mutations.
      ref.invalidate(dietRepositoryProvider);
      ref.invalidate(exerciseRepositoryProvider);
      ref.invalidate(gymRepositoryProvider);
      ref.invalidate(memberCoachRepositoryProvider);

      // Explicitly invalidate account data shown by each feature. Depending
      // only on a repository root is unsafe when it rebuilds to the same const
      // instance because Riverpod may keep its dependents unchanged.
      ref.invalidate(profileProvider);
      ref.invalidate(aiCoachStateProvider);
      ref.invalidate(chatControllerProvider);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(dietTodayProvider);
      ref.invalidate(exerciseWeekProvider);
      ref.invalidate(exerciseRoutineDoneProvider);
      ref.invalidate(myGymProvider);
      ref.invalidate(myTrainerProvider);
      ref.invalidate(consultationRequestControllerProvider);
      ref.invalidate(memberCoachProvider);
      ref.invalidate(coachRoutinesProvider);
      ref.invalidate(coachChatProvider);
      ref.invalidate(coachUnreadProvider);
      ref.invalidate(myHealthStateProvider);
      ref.invalidate(notificationControllerProvider);
      ref.invalidate(notificationListProvider);
      ref.invalidate(scheduleEventsProvider);
      ref.invalidate(scheduleMonthProvider);
    };
  });
}
