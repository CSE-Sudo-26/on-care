/// 트레이너 화면의 한 주 운동이 픽스처가 적은 값 그대로인가. (#1265)
///
/// 숫자의 기준은 **고객 앱 운동 계약**이다. 회원 앱 mock 도 같은 픽스처에서 같은
/// 규칙으로 쌓으므로, 두 앱을 나란히 놓았을 때 같은 날의 같은 근력이 같은 세트
/// 수로 읽혀야 한다 — 기대값을 여기 적지 않고 픽스처에서 계산하는 이유다.
library;

import 'dart:io';

import 'package:demo_fixture/demo_fixture.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_exercise_week.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

final DemoFixture _fixture = DemoFixture.parse(
  File('../../shared/demo_fixture/assets/kim_minsu.json').readAsStringSync(),
);

/// 이번 주의 픽스처 하루들.
List<FixtureDay> _thisWeek(DateTime now) {
  final DateTime monday = DateTime(
    now.year,
    now.month,
    now.day - (now.weekday - 1),
  );
  return _fixture
      .daysFor(now)
      .where((FixtureDay d) => d.weekStart == ymd(monday))
      .toList();
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedIfEmpty(db, fixture: _fixture);
  });

  tearDown(() async => db.close());

  test('요일별 근력 세트가 픽스처 합계와 같다', () async {
    final DateTime now = nowKst();
    final DateTime monday = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
    );
    final List<int> expected = List<int>.filled(7, 0);
    for (final FixtureDay day in _thisWeek(now)) {
      final int index = DateTime.parse(day.date).weekday - 1;
      for (final FixtureExercise e in day.doneExercises) {
        if (e.type == 'strength') expected[index] += e.sets ?? 0;
      }
    }
    expect(
      expected.reduce((int a, int b) => a + b),
      greaterThan(0),
      reason: '이번 주에 근력이 하나도 없으면 검증이 빈다',
    );

    final ClientExerciseWeek week = await DriftClientRepository(
      db,
    ).fetchExerciseWeek('seed-client-1', weekStart: monday);

    expect(week.strengthSets, expected);
  });

  test('요일 합계가 유형별 합과 같다', () async {
    final DateTime now = nowKst();
    final DateTime monday = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
    );
    final ClientExerciseWeek week = await DriftClientRepository(
      db,
    ).fetchExerciseWeek('seed-client-1', weekStart: monday);

    for (int i = 0; i < 7; i++) {
      expect(
        week.dailyMinutes[i],
        week.cardioMinutes[i] +
            week.strengthMinutes[i] +
            week.stretchingMinutes[i] +
            week.otherMinutes[i],
        reason: '$i 요일 합이 유형별 합과 다르다',
      );
    }
  });
}
