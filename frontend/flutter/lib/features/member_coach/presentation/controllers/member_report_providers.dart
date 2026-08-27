import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/utils/clock.dart';
import 'package:oncare/features/diet/domain/entities/diet_period.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/domain/entities/member_weekly_report.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';

/// 트레이너가 보낸 리포트가 가리키는 주를, 회원 기록으로 다시 세운다. (#1600)
///
/// 새 엔드포인트를 두지 않는다 — 운동 탭·식단 탭·PT 일정이 이미 읽고 있는 값을
/// 모은다. 그래서 미리보기의 숫자가 회원이 앱에서 보는 숫자와 어긋나지 않는다.
final memberWeeklyReportProvider =
    FutureProvider.family<MemberWeeklyReport, DateTime>((
      ref,
      DateTime weekStart,
    ) async {
      final DateTime monday = mondayOfWeek(weekStart);
      final DateTime today = DateTime(
        nowKst().year,
        nowKst().month,
        nowKst().day,
      );
      final bool isThisWeek = monday == mondayOfWeek(today);

      // watch 는 await 이전에 모두 건다 — 하나라도 바뀌면 문서도 다시 세워진다.
      final Future<ExerciseWeek> exercise = isThisWeek
          ? ref.watch(exerciseWeekProvider.future)
          : ref.watch(exercisePastWeekProvider(monday).future);
      final Future<DietPeriod> diet = ref.watch(
        dietPeriodProvider((
          from: monday,
          to: DateTime(monday.year, monday.month, monday.day + 6),
        )).future,
      );
      final Future<List<CoachSession>> sessions = ref.watch(
        coachSessionsProvider.future,
      );
      // 이번 주는 오늘 체크한 AI 추천 운동을 얹은 값이 화면의 진실이다(#671).
      // 리포트만 얹지 않은 값을 쓰면 같은 주가 문서와 화면에서 달라진다.
      final ExerciseTodayBonus bonus = isThisWeek
          ? ref.watch(exerciseTodayBonusProvider)
          : const ExerciseTodayBonus();

      final ExerciseWeek week = await exercise;
      final DateTime sunday = DateTime(
        monday.year,
        monday.month,
        monday.day + 6,
      );
      final List<CoachSession> inWeek = (await sessions)
          .where((CoachSession s) {
            final DateTime? date = s.date;
            if (date == null) return false;
            final DateTime day = DateTime(date.year, date.month, date.day);
            return !day.isBefore(monday) && !day.isAfter(sunday);
          })
          .toList(growable: false);

      return MemberWeeklyReport(
        weekStart: monday,
        exercise: isThisWeek ? applyTodayBonus(week, bonus) : week,
        diet: await diet,
        // 취소된 PT 는 잡혀 있던 것으로 세지 않는다 — 진행되지 않은 일정을
        // 분모에 두면 출석률이 실제보다 낮게 읽힌다(#871 과 같은 규칙).
        sessionsBooked: inWeek.where((CoachSession s) => !s.isCancelled).length,
        sessionsDone: inWeek.where((CoachSession s) => s.isDone).length,
      );
    }, name: 'memberWeeklyReport');
