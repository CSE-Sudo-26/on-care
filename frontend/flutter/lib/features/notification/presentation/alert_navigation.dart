import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_chat_sheet.dart';
import 'package:oncare/features/notification/domain/entities/alert_item.dart';
import 'package:oncare/features/schedule/presentation/controllers/schedule_controller.dart';

/// 알림을 눌렀을 때 관련 화면으로 보내고, **그 화면이 읽는 값을 다시 받게 한다.**
///
/// 이동만 하면 방금 알림이 알려 준 변화가 화면에 없을 수 있다 — 트레이너가 배정한
/// 루틴을 보러 갔는데 앱이 들고 있던 옛 목록이 그대로면, 알림이 거짓말을 한 것처럼
/// 보인다. 그래서 이동 직전에 그 화면의 provider 를 무효화한다.
///
/// 서버가 준 target 을 앱이 모르면 아무 데도 가지 않는다. 목록에서 빼거나 엉뚱한
/// 화면으로 보내는 것보다, 읽음 처리만 하고 제자리에 두는 편이 낫다.
Future<void> openAlertTarget(
  BuildContext context,
  WidgetRef ref,
  AlertItem item,
) async {
  final AlertAction? action = item.action;
  if (action == null || !action.isNavigable) return;

  switch (action.target) {
    case AlertTarget.coachChat:
      // 대화는 코치 정보를 알아야 열 수 있다. 아직 못 받았으면 이동하지 않는다 —
      // 이름 없는 빈 대화창을 여느니 알림 목록에 남는 편이 낫다.
      ref
        ..invalidate(coachChatProvider)
        ..invalidate(coachUnreadProvider);
      final String? name = ref.read(memberCoachProvider).valueOrNull?.name;
      if (name == null || !context.mounted) return;
      await openTrainerChatPage(context, trainerName: name);
    case AlertTarget.exercise:
      ref
        ..invalidate(exerciseWeekProvider)
        ..invalidate(coachRoutinesProvider);
      if (!context.mounted) return;
      context.go(AppRoutes.exercise);
    case AlertTarget.schedule:
      ref
        ..invalidate(scheduleEventsProvider)
        ..invalidate(scheduleMonthProvider)
        ..invalidate(coachSessionsProvider);
      if (!context.mounted) return;
      context.go(AppRoutes.dashboard);
    case AlertTarget.dashboard:
      if (!context.mounted) return;
      context.go(AppRoutes.dashboard);
    case AlertTarget.diet:
      if (!context.mounted) return;
      context.go(AppRoutes.diet);
    case AlertTarget.unknown:
      return;
  }
}
