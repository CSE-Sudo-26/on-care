/// 헬스장 탭의 1:1 PT 예약 표기. (#1072)
///
/// 트레이너는 1:1 PT 만 진행한다 — 자리는 비었거나 예약된 둘 중 하나이고,
/// 다음 일정이 잡혀 있으면 빈 자리를 더 고를 이유가 없다. 헬스장이 없는 회원은
/// 이 탭에서 할 일이 헬스장 찾기뿐이라 지도가 맨 앞에 온다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/my_reservation.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/domain/entities/trainer_slot.dart';
import 'package:oncare/features/exercise/presentation/controllers/consultation_request_controller.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/widgets/gym_locator_map.dart';
import 'package:oncare/features/exercise/presentation/widgets/gym_tab.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

import '../../support/consultation_test_support.dart';

const Gym _gym = Gym(
  id: 'gym-pt',
  name: '1:1 테스트 헬스장',
  address: '서울시 테스트구',
  distanceKm: 0.4,
  rating: 4.8,
  tags: <String>['PT'],
  lat: 37.5559,
  lng: 126.9368,
);

const Trainer _trainer = Trainer(
  id: 'trainer-pt',
  gymId: 'gym-pt',
  name: '김트레이너',
  role: '전담 트레이너',
);

final DateTime _openAt = DateTime(2026, 9, 1, 10);
final DateTime _bookedAt = DateTime(2026, 9, 2, 10);

List<TrainerSlot> get _slots => <TrainerSlot>[
  TrainerSlot(
    id: 'slot-open',
    trainerId: _trainer.id,
    startsAt: _openAt,
    booked: false,
  ),
  TrainerSlot(
    id: 'slot-booked',
    trainerId: _trainer.id,
    startsAt: _bookedAt,
    booked: true,
  ),
];

void main() {
  Future<AppLocalizations> pumpTab(
    WidgetTester tester, {
    bool hasMyGym = true,
    List<MyReservation> reservations = const <MyReservation>[],
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: Environment.dev,
              apiBaseUrl: 'http://localhost',
              useMockApi: true,
            ),
          ),
          myGymProvider.overrideWith((ref) async => hasMyGym ? _gym : null),
          myTrainerProvider.overrideWith((ref) async => _trainer),
          nearbyGymsProvider.overrideWith((ref) async => const <Gym>[_gym]),
          gymFinderResultsProvider.overrideWith(
            (ref) async => const <Gym>[_gym],
          ),
          recommendedTrainersProvider.overrideWith(
            (ref) async => const <Trainer>[],
          ),
          trainerSlotsProvider(_trainer.id).overrideWith((ref) async => _slots),
          myReservationsProvider.overrideWith((ref) async => reservations),
          consultationRequestControllerProvider.overrideWith(
            (ref) => newTestConsultationController(),
          ),
          memberCoachProvider.overrideWith((ref) async => null),
          coachUnreadProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: GymTab(
                selectedSlot: null,
                onSlot: (String _) {},
                onFind: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(Scaffold).first));
  }

  testWidgets('빈 자리에는 잔여 인원이 붙지 않고, 마감된 자리만 그 사실을 적는다', (
    WidgetTester tester,
  ) async {
    final AppLocalizations l = await pumpTab(tester);

    // 1:1 PT 라 "잔여 N자리"가 성립하지 않는다 — 빈 칩은 시각만 보인다.
    expect(find.textContaining('잔여'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('slot-chip-slot-open')),
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('slot-chip-slot-booked')),
        matching: find.text(l.exSlotFull),
      ),
      findsOneWidget,
    );
  });

  testWidgets('빈 예약 시간 제목은 트레이너 이름을 그대로 쓴다', (WidgetTester tester) async {
    final AppLocalizations l = await pumpTab(tester);

    expect(find.text(l.exTrainerAvailability(_trainer.name)), findsOneWidget);
    expect(find.text('김트레이너 빈 예약 시간'), findsOneWidget);
    // AI 표식 대신 예약 성격에 맞는 아이콘이 붙는다.
    expect(find.byIcon(Icons.event_available_outlined), findsOneWidget);
  });

  testWidgets('다음 일정이 있으면 빈 예약 시간 영역을 감춘다', (WidgetTester tester) async {
    final AppLocalizations l = await pumpTab(
      tester,
      reservations: <MyReservation>[
        MyReservation(
          id: 'res-next',
          slotId: 'slot-open',
          trainerId: _trainer.id,
          startsAt: _openAt,
          cancellable: true,
        ),
      ],
    );

    // 내 예약은 남고, 자리를 더 고르는 영역만 사라진다.
    expect(find.text(l.exMyReservations), findsOneWidget);
    expect(find.text(l.exTrainerAvailability(_trainer.name)), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('slot-chip-slot-open')),
      findsNothing,
    );
  });

  testWidgets('지난 예약만 있으면 빈 예약 시간을 다시 보여준다', (WidgetTester tester) async {
    final AppLocalizations l = await pumpTab(
      tester,
      reservations: <MyReservation>[
        MyReservation(
          id: 'res-past',
          slotId: 'slot-old',
          trainerId: _trainer.id,
          startsAt: DateTime(2026, 8, 1, 10),
          cancellable: false,
        ),
      ],
    );

    expect(find.text(l.exTrainerAvailability(_trainer.name)), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('slot-chip-slot-open')),
      findsOneWidget,
    );
  });

  testWidgets('연결된 헬스장이 없으면 지도가 맨 앞에 온다', (WidgetTester tester) async {
    final AppLocalizations l = await pumpTab(tester, hasMyGym: false);

    expect(find.byType(GymLocatorMap), findsOneWidget);
    // 지도가 안내 문구·찾기 버튼보다 위에 있어야 "바로 보인다"가 성립한다.
    expect(
      tester.getTopLeft(find.byType(GymLocatorMap)).dy,
      lessThan(tester.getTopLeft(find.text(l.exNoConnectedGym)).dy),
    );
  });
}
