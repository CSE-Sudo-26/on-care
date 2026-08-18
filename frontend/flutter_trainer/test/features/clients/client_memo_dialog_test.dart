import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/features/clients/domain/entities/trainer_memo.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_memo_dialog.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/services/trainer_memo_repository.dart';

import '../../helpers/pump_app.dart';

/// An in-memory stand-in for the server. [failWrites] flips it into the
/// failure mode the retry test needs, without touching the stored memos —
/// exactly what a failed request does on the real backend.
class _FakeMemoRepository implements TrainerMemoRepository {
  _FakeMemoRepository();

  final Map<String, List<TrainerMemo>> _byClient = <String, List<TrainerMemo>>{};
  bool failWrites = false;

  @override
  Future<List<TrainerMemo>> fetch(String clientId) async =>
      List<TrainerMemo>.from(
        _byClient[clientId] ?? const <TrainerMemo>[],
      )..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<TrainerMemo> create(
    String clientId, {
    required String body,
    TrainerMemoSource source = TrainerMemoSource.trainer,
    String? insightId,
    String insightKind = '',
  }) async {
    if (failWrites) throw const NetworkError();
    final list = _byClient.putIfAbsent(clientId, () => <TrainerMemo>[]);
    if (insightId != null) {
      final existing = list.where((memo) => memo.insightId == insightId);
      if (existing.isNotEmpty) return existing.first;
    }
    final now = nowKst().add(Duration(milliseconds: list.length));
    final memo = TrainerMemo(
      id: 'memo-${list.length + 1}',
      body: body,
      source: source,
      insightId: insightId,
      insightKind: insightKind,
      createdAt: now,
      updatedAt: now,
    );
    list.add(memo);
    return memo;
  }

  @override
  Future<TrainerMemo> update(
    String clientId,
    String memoId,
    String body,
  ) async {
    if (failWrites) throw const NetworkError();
    final list = _byClient[clientId]!;
    final index = list.indexWhere((memo) => memo.id == memoId);
    final updated = list[index].copyWith(body: body, updatedAt: nowKst());
    list[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(String clientId, String memoId) async {
    if (failWrites) throw const NetworkError();
    _byClient[clientId]!.removeWhere((memo) => memo.id == memoId);
  }
}

Future<void> _pumpDialog(
  WidgetTester tester,
  TrainerMemoRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        trainerMemoRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ClientMemoDialog(clientId: 'm1', clientName: '이지수'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a saved memo shows in the list and survives a reopen', (
    tester,
  ) async {
    final repository = _FakeMemoRepository();
    await _pumpDialog(tester, repository);

    expect(find.text('아직 남긴 메모가 없어요.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('client-memo-input')),
      '무릎 통증 경과 관찰',
    );
    await tester.tap(find.byKey(const ValueKey<String>('client-memo-add')));
    await tester.pumpAndSettle();

    expect(find.text('무릎 통증 경과 관찰'), findsOneWidget);
    expect(find.text('아직 남긴 메모가 없어요.'), findsNothing);

    // A fresh dialog (new provider container) re-reads from the source —
    // the memo is not held in the widget's own state.
    await _pumpDialog(tester, repository);
    expect(find.text('무릎 통증 경과 관찰'), findsOneWidget);
  });

  testWidgets('editing a memo rewrites it in place', (tester) async {
    final repository = _FakeMemoRepository();
    await repository.create('m1', body: '고칠 메모');
    await _pumpDialog(tester, repository);

    await tester.tap(
      find.byKey(const ValueKey<String>('client-memo-edit-open-memo-1')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('client-memo-edit-memo-1')),
      '고친 메모',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('client-memo-save-memo-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('고친 메모'), findsOneWidget);
    expect(find.text('고칠 메모'), findsNothing);
    expect((await repository.fetch('m1')).single.body, '고친 메모');
  });

  testWidgets('a failed save keeps the existing memos and the typed draft', (
    tester,
  ) async {
    final repository = _FakeMemoRepository();
    await repository.create('m1', body: '이미 있던 메모');
    repository.failWrites = true;
    await _pumpDialog(tester, repository);

    await tester.enterText(
      find.byKey(const ValueKey<String>('client-memo-input')),
      '저장 실패할 메모',
    );
    await tester.tap(find.byKey(const ValueKey<String>('client-memo-add')));
    await tester.pumpAndSettle();

    expect(find.textContaining('메모를 저장하지 못했어요'), findsOneWidget);
    expect(find.text('이미 있던 메모'), findsOneWidget);
    // The draft is still in the field, so the retry costs no retyping.
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('client-memo-input')),
          )
          .controller!
          .text,
      '저장 실패할 메모',
    );

    repository.failWrites = false;
    await tester.tap(find.byKey(const ValueKey<String>('client-memo-add')));
    await tester.pumpAndSettle();
    expect(find.text('저장 실패할 메모'), findsOneWidget);
  });

  testWidgets('a memo saved from chat is labelled and listed with the rest', (
    tester,
  ) async {
    final repository = _FakeMemoRepository();
    await repository.create('m1', body: '직접 쓴 메모');
    await repository.create(
      'm1',
      body: '무릎이 아파요',
      source: TrainerMemoSource.chatInsight,
      insightId: 'seed-chat-1-16:discomfort',
      insightKind: 'discomfort',
    );
    await _pumpDialog(tester, repository);

    expect(find.text('직접 쓴 메모'), findsOneWidget);
    expect(find.text('무릎이 아파요'), findsOneWidget);
    expect(find.text('채팅에서 감지'), findsOneWidget);
  });

  testWidgets('the client detail memo action opens the memo dialog', (
    tester,
  ) async {
    final repository = _FakeMemoRepository();
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.clientDetail('seed-client-1'),
      extraOverrides: <Override>[
        trainerMemoRepositoryProvider.overrideWithValue(repository),
      ],
    );

    await tester.tap(find.text('메모'));
    await settle(tester);

    expect(find.byType(ClientMemoDialog), findsOneWidget);
    expect(find.text('아직 남긴 메모가 없어요.'), findsOneWidget);
  });

  testWidgets('a memo saved in chat shows up on the client detail screen', (
    tester,
  ) async {
    final repository = _FakeMemoRepository();
    await withWideSurface(tester, () async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token-existing',
        extraOverrides: <Override>[
          trainerMemoRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await goTo(tester, AppRoutes.messagesFor('seed-client-1'));

      final addButton = find.byKey(
        const ValueKey<String>('chat-insight-add-seed-chat-1-16:discomfort'),
      );
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await settle(tester);

      // Same data source: the client detail memo list shows what chat saved.
      await goTo(tester, AppRoutes.clientDetail('seed-client-1'));
      await tester.tap(find.text('메모'));
      await settle(tester);

      expect(find.text('무릎이 가볍게 당기긴 했는데 괜찮아요'), findsOneWidget);
      expect(find.text('채팅에서 감지'), findsOneWidget);
    });
  });
}
