import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

import '../helpers/client_factory.dart';

/// 이름과 어긋나게 떨어지던 로스터 회원의 성별을 고정한다. (#960)
///
/// 표시용 성별은 저장된 값이 아니라 회원 id 로 만들어지는데, 데모
/// (`seed-client-8`)와 실 API(`user-sera`)가 서로 다른 id 를 쓴다. 그래서 id 가
/// 아니라 이름으로 고정한다 — 두 모드가, 그리고 모든 탭이 같은 값을 말해야 한다.
void main() {
  const Map<String, String> expected = <String, String>{
    '한지호': 'male',
    '신유나': 'female',
    // 데모에서 보이던 여성 그대로다. id 로 만든 값이 실 API(`user-sera`)
    // 에서는 남성으로 갈려서, 이름으로 고정해 두 모드를 맞춘다.
    '오세라': 'female',
    '문가영': 'female',
  };

  group('로스터 성별', () {
    for (final entry in expected.entries) {
      test('${entry.key} 는 id 와 무관하게 ${entry.value}', () {
        for (final id in <String>['seed-client-8', 'user-sera', 'anything']) {
          final client = makeClient(id: id, name: entry.key);
          expect(client.rosterGender, entry.value, reason: 'id=$id');
        }
      });
    }

    test('API 가 성별을 주면 그 값이 이긴다', () {
      const client = TrainerClient(
        id: 'user-sera',
        name: '오세라',
        avatar: '오',
        gender: 'male',
        goal: '고혈압 관리',
        lastMessage: '',
        lastTime: '',
        active: true,
        calories: 0,
        sodiumMg: 0,
        sugarG: 0,
        lastRoutine: '',
        weekCompletion: <int>[],
        sodiumWeek: <int>[],
      );

      expect(client.rosterGender, 'male');
    });

    test('명단에 없는 회원은 지금까지처럼 id 로 정해진다', () {
      // 코드 포인트 합이 짝수면 여성, 홀수면 남성 — 이름이 아니라 id 가 정한다.
      expect(makeClient(id: 'seed-client-1', name: '김민수').rosterGender, 'male');
      expect(
        makeClient(id: 'seed-client-2', name: '이지수').rosterGender,
        'female',
      );
    });
  });
}
