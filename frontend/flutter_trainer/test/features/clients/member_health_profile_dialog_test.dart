import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/features/clients/domain/entities/member_health_profile.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/member_health_profile_dialog.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

class _DelayedRepository extends DriftClientRepository {
  _DelayedRepository(super.db);

  final profile = Completer<MemberHealthProfile>();

  @override
  Future<MemberHealthProfile> fetchHealthProfile(String clientId) =>
      profile.future;
}

void main() {
  testWidgets('save stays disabled while loading and rejects decimal goals', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = _DelayedRepository(db);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMemberHealthProfileDialog(
              context,
              memberId: 'member-1',
              repository: repository,
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    repository.profile.complete(
      const MemberHealthProfile(memberId: 'member-1', memberName: '회원'),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );

    await tester.enterText(find.widgetWithText(TextFormField, '횟수'), '3.5');
    await tester.tap(find.text('저장'));
    await tester.pump();

    expect(find.text('0.0~14.0 범위로 입력해 주세요.'), findsOneWidget);
    expect(find.text('고객 신체·목표 관리'), findsOneWidget);
  });

  testWidgets('저장된 성별이 없으면 로스터가 말하는 성별로 열린다 (#960)', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = _DelayedRepository(db);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMemberHealthProfileDialog(
              context,
              memberId: 'user-sera',
              repository: repository,
              fallbackGender: 'female',
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pump();
    // 서버가 성별을 저장한 적이 없는 회원 — 실 API 는 빈 문자열을 내려준다.
    repository.profile.complete(
      const MemberHealthProfile(memberId: 'user-sera', memberName: '오세라'),
    );
    await tester.pumpAndSettle();

    // 헤더가 '여성'이라고 적어 둔 회원의 대화상자가 빈 칸으로 열리면 화면 두
    // 곳이 서로 다른 말을 한다.
    expect(
      tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      ).initialValue,
      'female',
    );
  });
}
