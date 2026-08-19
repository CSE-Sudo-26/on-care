import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/clients/data/repositories/client_invite_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_invite.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_invite_sheet.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 이메일로 찾고, 확인하고, 보낸다. 한 번에 보내지 않는 것이 이 시트의 요지라
/// (오타 한 글자가 다른 사람에게 가는 요청이 된다) 그 순서를 검증한다. (#919)
class _FakeInviteRepository implements ClientInviteRepository {
  _FakeInviteRepository({this.found, this.pending = const <ClientInvite>[]});

  MemberLookup? found;
  List<ClientInvite> pending;
  final List<({String memberId, String? message})> sent =
      <({String memberId, String? message})>[];
  final List<String> cancelled = <String>[];
  AppError? inviteFailure;

  @override
  bool get supportsInvites => true;

  @override
  Future<MemberLookup> lookup(String email) async {
    final result = found;
    if (result == null) throw const NotFoundError();
    return result;
  }

  @override
  Future<ClientInvite> invite(String memberId, {String? message}) async {
    if (inviteFailure case final AppError failure) throw failure;
    sent.add((memberId: memberId, message: message));
    return ClientInvite(
      id: 'tci-new',
      memberId: memberId,
      memberName: found?.name ?? '',
      memberEmail: found?.email ?? '',
      status: ClientInviteStatus.pending,
      createdAt: DateTime(2026, 8, 19),
    );
  }

  @override
  Future<List<ClientInvite>> listSent({String status = 'pending'}) async =>
      pending;

  @override
  Future<void> cancel(String inviteId) async => cancelled.add(inviteId);
}

MemberLookup _lookup({
  bool hasTrainer = false,
  bool coachedByMe = false,
  bool invitePending = false,
}) => MemberLookup(
  memberId: 'm1',
  name: '김민수',
  email: 'minsu@oncare.com',
  hasTrainer: hasTrainer,
  coachedByMe: coachedByMe,
  invitePending: invitePending,
);

Future<void> _pumpSheet(
  WidgetTester tester,
  _FakeInviteRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        clientInviteRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ClientInviteSheet()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('보내기 버튼은 회원을 찾기 전에는 없다', (tester) async {
    await _pumpSheet(tester, _FakeInviteRepository(found: _lookup()));

    expect(find.text('담당 요청 보내기'), findsNothing);
  });

  testWidgets('찾은 회원을 확인한 뒤에야 요청을 보낸다', (tester) async {
    final repository = _FakeInviteRepository(found: _lookup());
    await _pumpSheet(tester, repository);

    await tester.enterText(
      find.byKey(const ValueKey<String>('client-invite-email')),
      'minsu@oncare.com',
    );
    await tester.tap(find.text('찾기'));
    await tester.pumpAndSettle();

    // 이름이 먼저 보인다 — 눈으로 확인하고 누르라는 뜻이다.
    expect(find.text('김민수'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('client-invite-message')),
      '센터에서 뵀어요',
    );
    await tester.tap(find.text('담당 요청 보내기'));
    await tester.pumpAndSettle();

    expect(repository.sent, hasLength(1));
    expect(repository.sent.single.memberId, 'm1');
    expect(repository.sent.single.message, '센터에서 뵀어요');
  });

  testWidgets('없는 이메일에는 사유가 입력창에 붙는다', (tester) async {
    await _pumpSheet(tester, _FakeInviteRepository());

    await tester.enterText(
      find.byKey(const ValueKey<String>('client-invite-email')),
      'nobody@oncare.com',
    );
    await tester.tap(find.text('찾기'));
    await tester.pumpAndSettle();

    expect(find.text('그 이메일을 쓰는 회원을 찾지 못했어요'), findsOneWidget);
    expect(find.text('담당 요청 보내기'), findsNothing);
  });

  testWidgets('이미 다른 트레이너가 담당 중이면 보낼 수 없다고 말한다', (tester) async {
    await _pumpSheet(
      tester,
      _FakeInviteRepository(found: _lookup(hasTrainer: true)),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('client-invite-email')),
      'minsu@oncare.com',
    );
    await tester.tap(find.text('찾기'));
    await tester.pumpAndSettle();

    expect(find.text('이미 다른 트레이너가 담당 중인 회원이에요'), findsOneWidget);
    // 이유만 보여 주고 끝내지 않는다 — 누를 수 없어야 이유가 이유가 된다.
    expect(find.text('담당 요청 보내기'), findsNothing);
  });

  testWidgets('서버가 거절하면 그 사유가 화면에 남고 시트는 닫히지 않는다', (tester) async {
    final repository = _FakeInviteRepository(found: _lookup())
      ..inviteFailure = const ValidationError(message: '이미 보낸 요청이 기다리고 있어요.');
    await _pumpSheet(tester, repository);

    await tester.enterText(
      find.byKey(const ValueKey<String>('client-invite-email')),
      'minsu@oncare.com',
    );
    await tester.tap(find.text('찾기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('담당 요청 보내기'));
    await tester.pumpAndSettle();

    expect(find.text('이미 보낸 요청이 기다리고 있어요.'), findsOneWidget);
    expect(find.byType(ClientInviteSheet), findsOneWidget);
  });

  testWidgets('답을 기다리는 요청은 여기서만 볼 수 있고 거둘 수 있다', (tester) async {
    final repository = _FakeInviteRepository(
      found: _lookup(),
      pending: <ClientInvite>[
        ClientInvite(
          id: 'tci-1',
          memberId: 'm9',
          memberName: '이지수',
          memberEmail: 'jisu@oncare.com',
          status: ClientInviteStatus.pending,
          createdAt: DateTime(2026, 8, 18),
        ),
      ],
    );
    await _pumpSheet(tester, repository);

    expect(find.text('이지수'), findsOneWidget);

    await tester.tap(find.text('요청 거두기'));
    await tester.pumpAndSettle();

    expect(repository.cancelled, <String>['tci-1']);
  });
}
