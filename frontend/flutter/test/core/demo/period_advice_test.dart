/// 기간별 조언 문장 규칙. (#1574)
///
/// 서버(`diet_service.period_coach_message`·`exercise_service.period_coach_message`)
/// 가 원본이고 데모가 같은 규칙을 재현한다. 여기서 확인하는 것은 두 가지다 —
/// 기간마다 **다른 재료를 보고 다른 말을 하는가**, 그리고 없는 기록으로 조언을
/// 지어내지 않는가.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/core/demo/period_advice.dart';

DietDayTotals _diet(String date, int sodium) =>
    (date: DateTime.parse(date), sodiumMg: sodium);

ExerciseDayTotals _exercise(
  String date, {
  int minutes = 30,
  int calories = 270,
  Map<String, int> byType = const <String, int>{'cardio': 30},
}) => (
  date: DateTime.parse(date),
  minutes: minutes,
  calories: calories,
  byType: Map<String, int>.of(byType),
);

void main() {
  group('식단', () {
    test('기록이 없으면 기간마다 다른 안내를 남긴다', () {
      final Set<String> messages = <String>{
        for (final String period in <String>[kPeriodToday, kPeriodWeek, kPeriodAll])
          dietPeriodAdvice(const <DietDayTotals>[], period),
      };
      // 셋이 같은 문장이면 토글이 아무 일도 하지 않는 것처럼 보인다.
      expect(messages.length, 3);
    });

    test('오늘은 그날 나트륨 합계를 짚는다', () {
      expect(
        dietPeriodAdvice(<DietDayTotals>[_diet('2026-08-27', 3400)], kPeriodToday),
        contains('3400mg'),
      );
      expect(
        dietPeriodAdvice(<DietDayTotals>[_diet('2026-08-27', 1200)], kPeriodToday),
        contains('권장량 안'),
      );
    });

    test('이번 주는 초과한 날 수를 센다 — 오늘 조언과 다른 말이다', () {
      final List<DietDayTotals> days = <DietDayTotals>[
        _diet('2026-08-24', 2600),
        _diet('2026-08-25', 2600),
        _diet('2026-08-26', 2600),
        _diet('2026-08-27', 1200),
      ];
      final String week = dietPeriodAdvice(days, kPeriodWeek);
      expect(week, contains('이번 주 3일'));
      expect(week, isNot(dietPeriodAdvice(days, kPeriodToday)));
    });

    test('전체는 최근 4주와 그 이전을 견준다', () {
      final List<DietDayTotals> days = <DietDayTotals>[
        for (int i = 0; i < 20; i++)
          _diet(
            DateTime(2026, 6, 1 + i).toIso8601String().split('T').first,
            3000,
          ),
        for (int i = 0; i < 20; i++)
          _diet(
            DateTime(2026, 8, 1 + i).toIso8601String().split('T').first,
            1200,
          ),
      ];
      expect(dietPeriodAdvice(days, kPeriodAll), contains('최근 4주'));
    });

    test('조언은 짧다 — 카드 한 줄 반을 넘기지 않는다', () {
      final List<String> messages = <String>[
        dietPeriodAdvice(<DietDayTotals>[_diet('2026-08-27', 3400)], kPeriodToday),
        dietPeriodAdvice(<DietDayTotals>[
          _diet('2026-08-24', 2600),
          _diet('2026-08-25', 2600),
          _diet('2026-08-26', 2600),
        ], kPeriodWeek),
        dietPeriodAdvice(const <DietDayTotals>[], kPeriodAll),
      ];
      for (final String message in messages) {
        expect(message.length, lessThanOrEqualTo(45), reason: message);
      }
    });
  });

  group('운동', () {
    test('기록이 없으면 기간마다 다른 안내를 남긴다', () {
      final Set<String> messages = <String>{
        for (final String period in <String>[kPeriodToday, kPeriodWeek, kPeriodAll])
          exercisePeriodAdvice(const <ExerciseDayTotals>[], period),
      };
      expect(messages.length, 3);
    });

    test('오늘은 그날 한 운동과 소모 칼로리를 말한다', () {
      final String today = exercisePeriodAdvice(<ExerciseDayTotals>[
        _exercise('2026-08-27', minutes: 45, calories: 400),
      ], kPeriodToday);
      expect(today, contains('45분'));
      expect(today, contains('400kcal'));
      expect(today, contains('유산소'));
    });

    test('이번 주는 한 유형에 쏠렸는지를 먼저 짚는다', () {
      final List<ExerciseDayTotals> cardioOnly = <ExerciseDayTotals>[
        _exercise('2026-08-24'),
        _exercise('2026-08-25'),
        _exercise('2026-08-26'),
      ];
      final String week = exercisePeriodAdvice(cardioOnly, kPeriodWeek);
      expect(week, contains('유산소'));
      expect(week, contains('근력'));
      expect(week, isNot(exercisePeriodAdvice(cardioOnly, kPeriodToday)));

      final String mixed = exercisePeriodAdvice(<ExerciseDayTotals>[
        _exercise('2026-08-24'),
        _exercise(
          '2026-08-25',
          byType: <String, int>{'strength': 30},
        ),
        _exercise(
          '2026-08-26',
          byType: <String, int>{'stretching': 30},
        ),
      ], kPeriodWeek);
      expect(mixed, contains('고르게'));
    });

    test('전체는 최근 4주 추세를 본다', () {
      final List<ExerciseDayTotals> days = <ExerciseDayTotals>[
        for (int i = 0; i < 20; i++)
          _exercise(
            DateTime(2026, 6, 1 + i).toIso8601String().split('T').first,
            minutes: 10,
          ),
        for (int i = 0; i < 20; i++)
          _exercise(
            DateTime(2026, 8, 1 + i).toIso8601String().split('T').first,
            minutes: 60,
          ),
      ];
      expect(exercisePeriodAdvice(days, kPeriodAll), contains('최근 4주'));
    });

    test('조언은 짧다 — 카드 한 줄 반을 넘기지 않는다', () {
      final List<String> messages = <String>[
        exercisePeriodAdvice(<ExerciseDayTotals>[
          _exercise('2026-08-27', minutes: 45, calories: 400),
        ], kPeriodToday),
        exercisePeriodAdvice(<ExerciseDayTotals>[
          _exercise('2026-08-24'),
          _exercise('2026-08-25'),
        ], kPeriodWeek),
        exercisePeriodAdvice(const <ExerciseDayTotals>[], kPeriodWeek),
      ];
      for (final String message in messages) {
        expect(message.length, lessThanOrEqualTo(45), reason: message);
      }
    });
  });
}
