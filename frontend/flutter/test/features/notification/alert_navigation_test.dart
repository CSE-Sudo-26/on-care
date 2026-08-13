/// 알림을 눌렀을 때 어디로 가고 무엇을 다시 받는지 — #636.
///
/// 이동만 하면 방금 알림이 알려 준 변화가 화면에 없을 수 있다. 트레이너가 배정한
/// 루틴을 보러 갔는데 앱이 들고 있던 옛 목록이 그대로면 알림이 거짓말을 한 것처럼
/// 보인다 — 그래서 대상 화면이 읽는 값을 함께 무효화한다.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/notification/domain/entities/alert_item.dart';

AlertItem _alert({AlertAction? action}) => AlertItem(
  id: 'n1',
  title: '제목',
  body: '본문',
  timeAgo: '방금',
  category: AlertCategory.system,
  action: action,
);

void main() {
  group('AlertAction', () {
    test('앱이 아는 target 은 이동할 수 있다', () {
      const AlertAction action = AlertAction(
        label: '대화 보기',
        target: AlertTarget.coachChat,
      );

      expect(action.isNavigable, isTrue);
    });

    test('모르는 target 은 이동하지 않는다', () {
      // 서버가 새 종류를 추가했는데 앱이 모르는 경우. 목록에서 빼거나 엉뚱한 화면으로
      // 보내는 것보다, 읽음 처리만 하고 제자리에 두는 편이 낫다.
      const AlertAction action = AlertAction(
        label: '어딘가로',
        target: AlertTarget.unknown,
      );

      expect(action.isNavigable, isFalse);
    });

    test('action 이 없는 알림도 정상이다', () {
      expect(_alert().action, isNull);
    });
  });

  group('AlertTarget', () {
    test('서버가 쓰는 목적지를 모두 안다', () {
      // 서버 `_ACTION_BY_CATEGORY` 가 내려주는 target 집합과 맞춘다. 한쪽만 늘어나면
      // 알림은 오는데 갈 곳이 없어진다.
      expect(
        AlertTarget.values.toSet(),
        containsAll(<AlertTarget>[
          AlertTarget.dashboard,
          AlertTarget.schedule,
          AlertTarget.coachChat,
          AlertTarget.exercise,
          AlertTarget.diet,
          AlertTarget.unknown,
        ]),
      );
    });
  });
}
