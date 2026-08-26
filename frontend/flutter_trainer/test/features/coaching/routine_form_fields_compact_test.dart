import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/features/coaching/presentation/widgets/routine_form_fields.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

// 스테퍼(-/+) 대신 라벨 없는 키보드 입력 칸으로 바뀐 근력 세트·횟수·중량 및
// 시간 입력을 검증한다. (#1489)
void main() {
  Widget buildApp(Widget child) => MaterialApp(
    locale: const Locale('ko'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  testWidgets('compact 세트 입력은 스테퍼 버튼 없이 placeholder 만 보인다', (tester) async {
    int? changed;
    await tester.pumpWidget(
      buildApp(
        RoutineSetsField(sets: 3, compact: true, onChanged: (v) => changed = v),
      ),
    );

    expect(find.byIcon(Icons.remove), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.hintText, '세트 수(세트)');

    await tester.enterText(find.byType(TextField), '5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(changed, 5);
  });

  testWidgets('compact 중량 입력은 placeholder 로 중량(kg) 를 보여준다', (tester) async {
    await tester.pumpWidget(
      buildApp(
        RoutineWeightField(weight: 40, compact: true, onChanged: (_) {}),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.hintText, '중량(kg)');
  });

  testWidgets('compact 시간 입력은 placeholder 로 운동 시간(분) 을 보여준다', (tester) async {
    await tester.pumpWidget(
      buildApp(
        RoutineMinutesField(minutes: 30, compact: true, onChanged: (_) {}),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.hintText, '운동 시간(분)');
  });

  testWidgets('근력 세트·횟수·중량 세 칸이 한 줄 Row 에 나란히 들어간다', (tester) async {
    await tester.pumpWidget(
      buildApp(
        Row(
          children: <Widget>[
            Expanded(
              child: RoutineSetsField(
                sets: 3,
                compact: true,
                onChanged: (_) {},
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RoutineRepsField(
                reps: 10,
                compact: true,
                onChanged: (_) {},
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RoutineWeightField(
                weight: 40,
                compact: true,
                onChanged: (_) {},
              ),
            ),
          ],
        ),
      ),
    );

    // overflow 없이 세 필드가 모두 그려지면 통과 — tester.takeException 이 비어
    // 있어야 RenderFlex overflow 등이 없었다는 뜻이다.
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNWidgets(3));
  });
}
