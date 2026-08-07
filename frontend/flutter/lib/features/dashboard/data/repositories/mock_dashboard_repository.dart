import 'package:oncare/core/demo/demo_ai_advice.dart';
import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';

class MockDashboardRepository implements DashboardRepository {
  const MockDashboardRepository();

  @override
  Future<DashboardSummary> fetchSummary() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return const DashboardSummary(
      indicators: <HealthIndicator>[
        HealthIndicator(label: '칼로리', current: 1860, max: 2000, unit: 'kcal'),
        HealthIndicator(
          label: '나트륨',
          current: 2329,
          max: 2000,
          unit: 'mg',
          overBudget: true,
        ),
        HealthIndicator(label: '당류', current: 43, max: 50, unit: 'g'),
      ],
      macros: DietMacros(
        carbsG: 203.6,
        proteinG: 109.3,
        fatG: 66.5,
        carbsPct: 44,
        proteinPct: 24,
        fatPct: 32,
      ),
      dietEntries: 4,
      exerciseMinutes: 45,
      exerciseCalories: 520,
      exerciseCount: 4,
      // 데모 주간 소모 목표. 화면이 하드코딩하던 값을 목 데이터로 옮겨,
      // 홈·운동 탭이 같은 소스(exerciseBurnGoal)를 읽어도 데모 수치는 그대로.
      exerciseBurnGoal: 1500,
      todaySchedule: <ScheduleItem>[
        ScheduleItem(time: '10:00', title: '병원 정기검진', emoji: '🏥'),
        ScheduleItem(time: '18:00', title: '헬스장 운동', emoji: '💪'),
      ],
      weekScore: 85,
      weekScoreDelta: 12,
      // 홈 '오늘의 AI 통합 조언' 자리. 시드 경로와 같은 큐레이션 문구를 쓴다 —
      // 데모에서 홈이 읽는 값이 여기라서, 예전의 나트륨 단문을 두면 시드가
      // 준비한 통합 조언이 화면에 영영 못 올라온다.
      sodiumWarning: kDemoAiAdvice,
      exerciseFeedback: '주간 운동 목표 80%를 달성했어요! 오늘 가볍게 걷기를 더해 100%를 채워봐요!',
    );
  }
}
