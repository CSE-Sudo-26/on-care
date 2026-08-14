import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/shell/nav_destinations.dart';

void main() {
  test('고객 메뉴는 숫자 배지를 표시하지 않는다', () {
    final clients = navDestinations.singleWhere(
      (destination) => destination.label == NavLabel.clients,
    );
    final messages = navDestinations.singleWhere(
      (destination) => destination.label == NavLabel.messages,
    );

    expect(clients.badge, NavBadge.none);
    expect(messages.badge, NavBadge.unreadMessages);
  });
}
