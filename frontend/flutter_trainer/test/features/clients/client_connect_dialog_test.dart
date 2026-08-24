import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/clients/data/repositories/client_invite_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_invite.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_connect_dialog.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 회원 ID로 찾고, 확인하고, 연결한다. 한 번에 연결하지 않는 것이 이 창의
/// 요지라(오타 한 글자가 다른 사람에게 가는 요청이 된다) 그 순서를 검증한다.
/// (#919)
class _FakeInviteRepository implements ClientInviteRepository {
  _FakeInviteRepository({
    this.found,
    this.pending = const <ClientInvite>[],
    this.connectsImmediately = false,
  });

  MemberLookup? found;
  List<ClientInvite> pending;

  @override
  final bool connectsImmediately;
  final List<({String memberId, String? message})> sent =
      <({String memberId, String? message})>[];
  final List<String> cancelled = <String>[];
  AppError? inviteFailure;

  @override
  bool get supportsInvites => true;

  @override
  Future<MemberLookup> lookup(String memberId) async {
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
      status: connectsImmediately
          ? ClientInviteStatus.accepted
          : ClientInviteStatus.pending,
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
  memberId: 'user-a3f9c81e4b2d',
  name: '김민수',
  email: 'minsu@oncare.com',
  hasTrainer: hasTrainer,
  coachedByMe: coachedByMe,
  invitePending: invitePending,
);

Future<void> _pumpDialog(
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
        home: Scaffold(body: ClientConnectDialog()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('보내기 버튼은 회원을 찾기 전에는 없다', (tester) async {
    await _pumpDialog(tester, _FakeInviteRepository(found: _lookup()));

    expect(find.text('담당 요청 보내기'), findsNothing);
  });

  testWidgets('찾은 회원을 확인한 뒤에야 요청을 보낸다', (tester) async {
    final repository = _FakeInviteRepository(found: _lookup());
    await _pumpDialog(tester, repository);

    await tester.enterText(
      find.byKey(const ValueKey<String>('client-connect-member-id')),
      'user-a3f9c81e4b2d',
    );
    await tester.tap(find.text('찾기'));
    await tester.pumpAndSettle();

    // 이름이 먼저 보인다 — 눈으로 확인하고 누르라는 뜻이다. 이메일 등 다른
    // 인적 사항은 보여주지 않는다.
    expect(find.text('김민수'), findsOneWidget);
    expect(find.text('minsu@oncare.com'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey<String>('client-invite-message')),
      '센터에서 뵀어요',
    );
    await tester.tap(find.text('담당 요청 보내기'));
    await tester.pumpAndSettle();

    expect(repository.sent, hasLength(1));
    expect(repository.sent.single.memberId, 'user-a3f9c81e4b2d');
    expect(repository.sent.single.message, '센터에서 뵀어요');
  });

  testWidgets('없는 회원 ID에는 사유가 입력창에 붙는다', (tester) async {
    await _pumpDialog(tester, _FakeInviteRepository());

    await tester.enterText(
      find.byKey(const ValueKey<String>('client-connect-member-id')),
      'user-no-such-member',
    );
    await tester.tap(find.text('찾기'));
    await tester.pumpAndSettle();

    expect(find.text('그 회원 ID를 쓰는 회원을 찾지 못했어요'), findsOneWidget);
    expect(find.text('담당 요청 보내기'), findsNothing);
  });

  testWidgets('이미 다른 트레이너가 담당 중이면 보낼 수 없다고 말한다', (tester) async {
    await _pumpDialog(
      tester,
      _FakeInviteRepository(found: _lookup(hasTrainer: true)),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('client-connect-member-id')),
      'user-a3f9c81e4b2d',
    );
    await tester.tap(find.text('찾기'));
    await tester.pumpAndSettle();

    expect(find.text('이미 다른 트레이너가 담당 중인 회원이에요'), findsOneWidget);
    // 이유만 보여 주고 끝내지 않는다 — 누를 수 없어야 이유가 이유가 된다.
    expect(find.text('담당 요청 보내기'), findsNothing);
  });

  testWidgets('서버가 거절하면 그 사유가 화면에 남고 창은 닫히지 않는다', (tester) async {
    final repository = _FakeInviteRepository(found: _lookup())
      ..inviteFailure = const ValidationError(message: '이미 보낸 요청이 기다리고 있어요.');
    await _pumpDialog(tester, repository);

    await tester.enterText(
      find.byKey(const ValueKey<String>('client-connect-member-id')),
      'user-a3f9c81e4b2d',
    );
    await tester.tap(find.text('찾기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('담당 요청 보내기'));
    await tester.pumpAndSettle();

    expect(find.text('이미 보낸 요청이 기다리고 있어요.'), findsOneWidget);
    expect(find.byType(ClientConnectDialog), findsOneWidget);
  });

  testWidgets('답을 기다리는 요청은 여기서만 볼 수 있고 거둘 수 있다', (tester) async {
    final repository = _FakeInviteRepository(
      found: _lookup(),
      pending: <ClientInvite>[
        ClientInvite(
          id: 'tci-1',
          memberId: 'user-b7c2f0913da5',
          memberName: '이지수',
          memberEmail: 'jisu@oncare.com',
          status: ClientInviteStatus.pending,
          createdAt: DateTime(2026, 8, 18),
        ),
      ],
    );
    await _pumpDialog(tester, repository);

    expect(find.text('이지수'), findsOneWidget);

    await tester.tap(find.text('요청 거두기'));
    await tester.pumpAndSettle();

    expect(repository.cancelled, <String>['tci-1']);
  });

  testWidgets('가운데 뜨는 작은 창으로 열린다', (tester) async {
    // 상담 요청 인박스(showConsultationsDialog)와 같은 형식 — 바닥에서
    // 올라오는 시트가 아니라 Dialog 다. BottomSheet 위젯이 트리에 없어야
    // 한다.
    await _pumpDialog(tester, _FakeInviteRepository(found: _lookup()));

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  group('connectsImmediately (데모)', () {
    testWidgets('메시지 칸과 대기 목록 없이 바로 연결하고, 연결됨을 알린다', (tester) async {
      final repository = _FakeInviteRepository(
        found: _lookup(),
        connectsImmediately: true,
      );
      await _pumpDialog(tester, repository);

      await tester.enterText(
        find.byKey(const ValueKey<String>('client-connect-member-id')),
        'user-a3f9c81e4b2d',
      );
      await tester.tap(find.text('찾기'));
      await tester.pumpAndSettle();

      expect(find.text('김민수'), findsOneWidget);
      // 메시지 칸은 없다 — 데모에는 받을 상대가 없다.
      expect(
        find.byKey(const ValueKey<String>('client-invite-message')),
        findsNothing,
      );
      // 대기 목록 섹션도 없다 — 기다릴 답이 없다.
      expect(find.text('답을 기다리는 요청'), findsNothing);

      await tester.tap(find.text('연결하기'));
      // pumpAndSettle 이 아니라 한 프레임만 — 스낵바는 몇 초 뒤 스스로
      // 사라지는 타이머를 갖고 있어, 끝까지 settle 하면 뜬 순간을 지나쳐
      // 이미 닫힌 뒤를 보게 된다.
      await tester.pump();

      expect(repository.sent, hasLength(1));
      expect(find.text('김민수님과 연결됐어요'), findsOneWidget);
    });
  });
}
