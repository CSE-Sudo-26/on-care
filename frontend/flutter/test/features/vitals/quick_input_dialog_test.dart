import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/vitals/data/repositories/mock_vitals_repository.dart';
import 'package:oncare/features/vitals/presentation/controllers/vitals_controller.dart';
import 'package:oncare/shared/widgets/modals/quick_input_dialog.dart';

// showQuickInputDialog 의 반환 계약 — 저장 성공 시 true(호출부가 지표를
// 새로고침할 수 있도록), 취소/닫기 시 false.
void main() {
  // 다이얼로그를 열고, 반환값을 [results] 에 담는 버튼을 펌프한다.
  Future<List<bool>> pumpOpen(
    WidgetTester tester, {
    required QuickInputKind kind,
  }) async {
    final List<bool> results = <bool>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          vitalsRepositoryProvider.overrideWithValue(MockVitalsRepository()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    results.add(await showQuickInputDialog(context, kind: kind));
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('저장 성공 시 true 를 반환하고 다이얼로그가 닫힌다', (
    WidgetTester tester,
  ) async {
    final List<bool> results = await pumpOpen(
      tester,
      kind: QuickInputKind.weight,
    );
    expect(find.text('체중 입력'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '72.5');
    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();

    expect(find.text('체중 입력'), findsNothing);
    expect(results, <bool>[true]);
  });

  testWidgets('잘못된 값은 저장되지 않고 다이얼로그가 유지된다', (
    WidgetTester tester,
  ) async {
    final List<bool> results = await pumpOpen(
      tester,
      kind: QuickInputKind.weight,
    );
    await tester.tap(find.text('저장하기')); // 빈 입력
    await tester.pumpAndSettle();

    expect(find.text('값을 확인해 주세요.'), findsOneWidget);
    expect(find.text('체중 입력'), findsOneWidget); // 그대로 열려 있음
    expect(results, isEmpty); // 아직 닫히지 않음
  });
}
