import 'package:oncare/core/demo/demo_ai_advice.dart';
import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/domain/repositories/diet_repository.dart';

/// 데모 홈 요약. 영양 수치는 **직접 들고 있지 않고** 식단 저장소에서 가져온다.
///
/// 예전에는 세 지표·매크로·끼니 수를 여기에 따로 적어 뒀는데, 식단 탭이 보는
/// 값과 어긋나 홈은 나트륨 2,329mg·4끼, 식단은 3,428mg·3끼를 보여줬다. 식단이
/// 기준이므로 홈이 그쪽을 읽게 한다 — 데모 중 식단을 추가·수정·삭제해도
/// (`MockDietRepository` 는 세션 동안 상태를 유지한다) 홈이 따라온다.
///
/// 운동·일정·주간 점수는 아직 식단과 무관한 데모 값이라 그대로 둔다.
class MockDashboardRepository implements DashboardRepository {
  const MockDashboardRepository(this._diet);

  final DietRepository _diet;

  /// 데모 일일 목표치. 실 백엔드가 사용자별 목표를 주기 전까지의 고정값이다.
  static const int _calorieGoal = 2000;
  static const int _sodiumGoalMg = 2000;
  static const double _sugarGoalG = 50;

  @override
  Future<DashboardSummary> fetchSummary() async {
    final DietDay today = await _diet.fetchToday();

    return DashboardSummary(
      indicators: <HealthIndicator>[
        HealthIndicator(
          label: '칼로리',
          current: today.totalCalories,
          max: _calorieGoal,
          unit: 'kcal',
          overBudget: today.totalCalories > _calorieGoal,
        ),
        HealthIndicator(
          label: '나트륨',
          current: today.totalSodiumMg,
          max: _sodiumGoalMg,
          unit: 'mg',
          overBudget: today.totalSodiumMg > _sodiumGoalMg,
        ),
        HealthIndicator(
          label: '당류',
          current: today.totalSugarG,
          max: _sugarGoalG,
          unit: 'g',
          overBudget: today.totalSugarG > _sugarGoalG,
        ),
      ],
      macros: today.macros,
      dietEntries: today.entries.length,
      exerciseMinutes: 45,
      exerciseCalories: 520,
      exerciseCount: 4,
      // 데모 주간 소모 목표. 화면이 하드코딩하던 값을 목 데이터로 옮겨,
      // 홈·운동 탭이 같은 소스(exerciseBurnGoal)를 읽어도 데모 수치는 그대로.
      exerciseBurnGoal: 1500,
      todaySchedule: const <ScheduleItem>[
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
