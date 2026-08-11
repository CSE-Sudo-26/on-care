import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/shared/widgets/stat_card.dart';

void main() {
  testWidgets('확대된 라벨과 도움말을 담을 최소 높이를 유지한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 486,
              child: StatCard(
                label: '오늘 예약',
                value: '4',
                unit: '건',
                hint: '스케줄에서 보기',
                icon: Icons.event_available_outlined,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(StatCard)).height,
      greaterThanOrEqualTo(124),
    );
  });
}
