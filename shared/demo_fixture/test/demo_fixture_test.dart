import 'dart:io';

import 'package:demo_fixture/demo_fixture.dart';
import 'package:flutter_test/flutter_test.dart';

/// 에셋 번들 없이 파일에서 바로 읽는다 — 이 패키지 테스트는 앱 부팅 경로가 아니라
/// 픽스처 자체를 본다.
DemoFixture _load() =>
    DemoFixture.parse(File('assets/kim_minsu.json').readAsStringSync());

void main() {
  final DemoFixture fixture = _load();

  test('오늘·어제 합계가 시연에서 말하는 값 그대로다', () {
    // 이 두 날은 두 앱을 나란히 놓고 화면에서 직접 읽는 값이다. 픽스처가 바뀌어도
    // 이 합계는 유지되어야 한다 — 바꾸려면 이슈에 적힌 서사부터 다시 정한다.
    final List<FixtureDay> days = fixture.daysFor(DateTime(2026, 8, 16));
    final FixtureDay today = days.last;
    final FixtureDay yesterday = days[days.length - 2];

    expect(today.calories, 1067);
    expect(today.sodiumMg, 3428);
    expect(today.sugarG, 17.8);

    expect(yesterday.calories, 2380);
    expect(yesterday.sodiumMg, 2261);
    expect(yesterday.sugarG, 63.0);
  });

  test('아직 오지 않은 날은 없다', () {
    // 주중에 열어도 이번 주 남은 요일이 채워지면 주 평균이 실제보다 높아진다(#752).
    for (final DateTime now in <DateTime>[
      DateTime(2026, 8, 10), // 월
      DateTime(2026, 8, 13), // 목
      DateTime(2026, 8, 16), // 일
    ]) {
      final List<FixtureDay> days = fixture.daysFor(now);
      final String today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      expect(days.last.date, today, reason: '마지막 날은 항상 오늘이어야 한다');
      expect(
        days.where((FixtureDay d) => d.date.compareTo(today) > 0),
        isEmpty,
      );
    }
  });

  test('12주를 빈틈없이 덮는다', () {
    final List<FixtureDay> days = fixture.daysFor(DateTime(2026, 8, 16));
    expect(fixture.historyWeeks, 12);
    // 일요일에 열면 12주가 꽉 찬다(84일). 날짜가 하루도 겹치지 않아야 한다.
    expect(days.length, 84);
    expect(days.map((FixtureDay d) => d.date).toSet().length, 84);
  });

  test('이행률은 루틴 항목에서 나온다 — 목록과 퍼센트가 갈라지지 않는다', () {
    for (final FixtureDay day in fixture.daysFor(DateTime(2026, 8, 16))) {
      if (day.exercises.isEmpty) {
        expect(day.completion, 0, reason: '${day.date}: 휴식일은 0');
        continue;
      }
      final int done = day.exercises.where((FixtureExercise e) => e.done).length;
      expect(day.completion, (done * 100 / day.exercises.length).round());
      expect(day.doneExercises.length, done);
    }
  });

  test('끼니 합계는 음식 합계와 같다', () {
    for (final FixtureDay day in fixture.daysFor(DateTime(2026, 8, 16))) {
      for (final FixtureMeal meal in day.meals) {
        int calories = 0;
        int sodium = 0;
        for (final FixtureFood food in meal.foods) {
          calories += food.calories;
          sodium += food.sodiumMg;
        }
        expect(meal.calories, calories, reason: '${day.date} ${meal.slug}');
        expect(meal.sodiumMg, sodium, reason: '${day.date} ${meal.slug}');
      }
    }
  });

  test('기록이 없는 날이 남아 있다', () {
    // 빈 화면이 맞게 동작하는지 시연에서 볼 수 있어야 한다.
    final List<FixtureDay> days = fixture.daysFor(DateTime(2026, 8, 16));
    expect(days.where((FixtureDay d) => !d.hasRecord), isNotEmpty);
  });

  test('주가 바뀌어도 하루가 사라지지 않는다', () {
    // 서머타임이 있는 지역에서 `Duration(days:)` 로 날짜를 옮기면 하루가 밀린다.
    // 픽스처는 날짜 연산만 쓰므로 어느 날에 열어도 연속이어야 한다.
    final List<FixtureDay> days = fixture.daysFor(DateTime(2026, 3, 29));
    final List<String> dates = days.map((FixtureDay d) => d.date).toList();
    for (int i = 1; i < dates.length; i++) {
      final DateTime prev = DateTime.parse(dates[i - 1]);
      final DateTime cur = DateTime.parse(dates[i]);
      expect(
        cur.difference(prev).inDays,
        1,
        reason: '${dates[i - 1]} → ${dates[i]} 사이가 비었다',
      );
    }
  });
}
