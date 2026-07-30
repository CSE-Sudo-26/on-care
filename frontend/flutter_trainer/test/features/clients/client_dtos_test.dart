import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/features/clients/data/dtos/client_dtos.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

TrainerClient _client(String id, {required int sodiumMg}) => TrainerClient(
      id: id,
      name: id,
      avatar: id.substring(0, 1),
      goal: '',
      lastMessage: '',
      lastTime: '',
      active: true,
      calories: 0,
      sodiumMg: sodiumMg,
      sugarG: 0,
      lastRoutine: '',
      weekCompletion: const <int>[],
      sodiumWeek: const <int>[],
    );

void main() {
  group('trainerClientFromJson', () {
    test('maps a roster element (snake_case) into TrainerClient', () {
      final c = trainerClientFromJson(<String, Object?>{
        'id': 'm1',
        'name': '김민수',
        'avatar': '김',
        'goal': '혈압 관리',
        'last_message': '점심 등록했어요',
        'last_time': '방금',
        'active': true,
        'calories': 1800,
        'sodium_mg': 2100,
        'sugar_g': 40,
        'last_routine': '오늘',
        'week_completion': <Object?>[100, 80, 0, 60, 90, 0, 0],
        'sodium_week': <Object?>[1900, 2200, 2100],
      });

      expect(c.id, 'm1');
      expect(c.name, '김민수');
      expect(c.sodiumMg, 2100);
      expect(c.sodiumOverBudget, isTrue); // 2100 > 2000 target
      expect(c.weekCompletion, <int>[100, 80, 0, 60, 90, 0, 0]);
      expect(c.sodiumWeek, <int>[1900, 2200, 2100]);
    });

    test('tolerates double-encoded numbers and missing lists (web JSON)', () {
      final c = trainerClientFromJson(<String, Object?>{
        'id': 'm2',
        'name': '이지수',
        'calories': 1500.0, // web can decode ints as double
        'sodium_mg': 1800.0,
        'week_completion': <Object?>[100.0, 50.0],
        // sodium_week omitted
      });

      expect(c.calories, 1500);
      expect(c.sodiumMg, 1800);
      expect(c.weekCompletion, <int>[100, 50]);
      expect(c.sodiumWeek, isEmpty);
      expect(c.active, isFalse); // absent → false
    });
  });

  group('clientDietEntryFromJson / routineHistoryEntryFromJson', () {
    test('maps a diet entry', () {
      final d = clientDietEntryFromJson(<String, Object?>{
        'meal': '점심',
        'items': '김치찌개, 공기밥',
        'calories': 720,
        'sodium_mg': 1400,
      });
      expect(d.meal, '점심');
      expect(d.items, '김치찌개, 공기밥');
      expect(d.sodiumMg, 1400);
    });

    test('maps a history entry with exercises list', () {
      final h = routineHistoryEntryFromJson(<String, Object?>{
        'date_label': '7/12 (오늘)',
        'label': 'PT 세션',
        'completion_rate': 80,
        'exercises': <Object?>['스쿼트 3세트', '✗ 런지'],
        'client_feedback': '무릎이 조금 아팠어요',
        'trainer_note': '강도 조절',
      });
      expect(h.dateLabel, '7/12 (오늘)');
      expect(h.completionRate, 80);
      expect(h.exercises, <String>['스쿼트 3세트', '✗ 런지']);
      expect(h.trainerNote, '강도 조절');
    });
  });

  group('prioritizeClients', () {
    test('moves sodium-over-target clients first, keeping server order', () {
      final ordered = prioritizeClients(<TrainerClient>[
        _client('a', sodiumMg: 1500), // ok
        _client('b', sodiumMg: 2500), // over
        _client('c', sodiumMg: 1800), // ok
        _client('d', sodiumMg: 2100), // over
      ]);

      expect(
        ordered.map((c) => c.id).toList(),
        <String>['b', 'd', 'a', 'c'],
      );
    });

    test('is a no-op ordering when nobody is over target', () {
      final ordered = prioritizeClients(<TrainerClient>[
        _client('a', sodiumMg: 100),
        _client('b', sodiumMg: 200),
      ]);
      expect(ordered.map((c) => c.id).toList(), <String>['a', 'b']);
    });
  });
}
