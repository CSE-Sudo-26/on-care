import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/app/shell/nav_destinations.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/consultations/data/repositories/consultation_repository.dart';
import 'package:oncare_trainer/features/consultations/domain/entities/consultation_request.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations_ko.dart';

import '../../helpers/pump_app.dart';

/// 라벨 기대값은 로케일을 명시해 읽는다 — 기본 로케일이 바뀌어도 의도가 남는다.
final AppLocalizationsKo _ko = AppLocalizationsKo();

ConsultationRequest _request({
  String id = 'consult-1',
  String name = '김민수',
  String status = 'pending',
  String? message = '상담 부탁드립니다.',
}) => ConsultationRequest(
  id: id,
  memberId: 'user-$id',
  memberName: name,
  goalCode: 'weight_loss',
  purposeCode: 'chronic',
  preferredDate: DateTime(2026, 8, 12),
  preferredTimeCode: 'evening',
  message: message,
  status: status,
);

/// A stand-in inbox that reports itself enabled (so the nav row renders)
/// and records the decisions made against it.
class _FakeConsultationRepository implements ConsultationRepository {
  _FakeConsultationRepository({
    List<ConsultationRequest>? requests,
    this.failure,
  }) : requests = requests ?? <ConsultationRequest>[];

  List<ConsultationRequest> requests;
  final AppError? failure;

  final List<String> accepted = <String>[];
  final List<(String, String?)> rejected = <(String, String?)>[];

  @override
  bool get supportsInbox => true;

  @override
  Future<List<ConsultationRequest>> fetch({String status = 'pending'}) async {
    if (failure != null) throw failure!;
    return status == 'pending'
        ? requests.where((r) => r.isPending).toList()
        : requests;
  }

  @override
  Stream<List<ConsultationRequest>> watch({String status = 'pending'}) =>
      Stream<List<ConsultationRequest>>.fromFuture(fetch(status: status));

  @override
  Future<int> pendingCount() async => requests.where((r) => r.isPending).length;

  @override
  Stream<int> watchPendingCount() => Stream<int>.fromFuture(pendingCount());

  @override
  Future<void> accept(String id, {ConsultationSchedule? schedule}) async {
    accepted.add(id);
    requests = requests
        .map((r) => r.id == id ? _request(id: id, status: 'accepted') : r)
        .toList();
  }

  @override
  Future<void> reject(String id, {String? note}) async {
    rejected.add((id, note));
    requests = requests
        .map((r) => r.id == id ? _request(id: id, status: 'rejected') : r)
        .toList();
  }
}

Future<ProviderContainer> _pumpInbox(
  WidgetTester tester,
  _FakeConsultationRepository repo,
) => pumpTrainerApp(
  tester,
  token: 'demo-token',
  at: AppRoutes.consultations,
  extraOverrides: <Override>[
    consultationRepositoryProvider.overrideWithValue(repo),
  ],
);

void main() {
  testWidgets('renders a pending request with its decision actions', (
    tester,
  ) async {
    await _pumpInbox(
      tester,
      _FakeConsultationRepository(requests: <ConsultationRequest>[_request()]),
    );

    expect(find.text('상담 요청'), findsWidgets);
    expect(find.text('김민수'), findsOneWidget);
    expect(find.text('체중 감량'), findsOneWidget);
    expect(find.text('상담 부탁드립니다.'), findsOneWidget);
    expect(find.text('승인'), findsOneWidget);
    expect(find.text('거절'), findsOneWidget);
  });

  testWidgets('badges every request as addressed to this trainer', (
    tester,
  ) async {
    await _pumpInbox(
      tester,
      _FakeConsultationRepository(
        requests: <ConsultationRequest>[_request()],
      ),
    );

    // 요청은 트레이너 한 사람 앞으로만 온다 — "헬스장 문의" 갈래는 없어졌다.
    expect(find.text('트레이너 지정'), findsOneWidget);
    expect(find.text('헬스장 문의'), findsNothing);
  });

  testWidgets('accepting sends the decision to the repository', (tester) async {
    final repo = _FakeConsultationRepository(
      requests: <ConsultationRequest>[_request()],
    );
    await _pumpInbox(tester, repo);

    await tester.tap(find.text('승인'));
    await settle(tester);

    expect(repo.accepted, <String>['consult-1']);
  });

  testWidgets('a decided request shows its outcome, not the actions', (
    tester,
  ) async {
    final repo = _FakeConsultationRepository(
      requests: <ConsultationRequest>[_request(status: 'accepted')],
    );
    await _pumpInbox(tester, repo);
    // 처리된 건은 '전체' 필터에서만 보인다.
    await tester.tap(find.text('전체 보기'));
    await settle(tester);

    expect(find.text('담당 고객으로 등록됨'), findsOneWidget);
    expect(find.text('승인'), findsNothing);
  });

  testWidgets('an empty inbox explains itself instead of showing nothing', (
    tester,
  ) async {
    await _pumpInbox(tester, _FakeConsultationRepository());

    expect(find.text('대기 중인 상담 요청이 없어요'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    await _pumpInbox(
      tester,
      _FakeConsultationRepository(
        failure: const NetworkError(message: '연결이 불안정해요'),
      ),
    );

    expect(find.text('상담 요청을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('the demo console never shows the 상담 요청 row', (tester) async {
    // 데모는 지금 그대로여야 한다 — 목 모드에서는 인박스 진입점이 아예 없다.
    await withWideSurface(tester, () async {
      await pumpTrainerApp(tester, token: 'demo-token');

      expect(
        find.text(navLabel(_ko, consultationsDestination.label)),
        findsNothing,
      );
      for (final destination in navDestinations) {
        expect(find.text(navLabel(_ko, destination.label)), findsWidgets);
      }
    });
  });

  testWidgets('the real-API console also keeps the separate row hidden', (
    tester,
  ) async {
    await withWideSurface(tester, () async {
      await pumpTrainerApp(
        tester,
        token: 'demo-token',
        extraOverrides: <Override>[
          consultationRepositoryProvider.overrideWithValue(
            _FakeConsultationRepository(),
          ),
        ],
      );

      expect(
        find.text(navLabel(_ko, consultationsDestination.label)),
        findsNothing,
      );
    });
  });
}
