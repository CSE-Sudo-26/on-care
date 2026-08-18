/// 예약·취소 실 API E2E — 트레이너 웹 단계 (#637).
///
/// 회원 앱 단계와 번갈아 실행된다. 순서와 실행 방법은
/// `scripts/run_reservation_e2e.sh` 와 `docs/local_fullstack.md` 참고.
///
///  1. `create-slot`            — 트레이너가 UI 로 미래 슬롯을 연다.
///  2. (회원) `reserve`
///  3. `verify-schedule`        — 그 예약이 만든 일정이 트레이너 일정에 보인다.
///  4. (회원) `cancel`
///  5. `verify-schedule-removed`— 취소하면 그 일정이 사라진다.
///  6. `cleanup`                — 이번 실행이 연 슬롯을 닫는다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/features/schedule/presentation/pages/schedule_page.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/reservation_slots_sheet.dart';

import 'support/e2e_harness.dart';

/// 슬롯을 여는 날. 시트의 기본 시각이 10:00 이라 **오늘이면 이미 지난 시각**이 될 수
/// 있어 하루 뒤를 쓴다. 시각 선택은 `showTimePicker` 라 기본값을 그대로 쓰는 편이
/// 다이얼을 흉내 내는 것보다 깨질 거리가 적다.
DateTime get _slotDay => DateTime.now().add(const Duration(days: 1));
const int _capacity = 2;

Future<void> _openSchedule(WidgetTester tester, DateTime day) async {
  await tester.tap(find.byKey(const ValueKey<String>('sidebar-${AppRoutes.schedule}')));
  await pumpUntil(tester, find.byType(SchedulePage), step: '스케줄 화면');
  await tester.tap(find.byKey(ValueKey<String>('schedule-day-${ymd(day)}')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(installPluginFakes);

  testWidgets('트레이너 단계: $e2ePhase', (WidgetTester tester) async {
    final E2eApi api = await E2eApi.login(trainerEmail);

    switch (e2ePhase) {
      case 'create-slot':
        // 같은 시각에 이미 슬롯이 있을 수 있다(앞선 실행의 잔여). id 를 시각으로
        // 찾으면 남의 것을 잡으므로, 만들기 전후의 차집합으로 이번 것을 고른다.
        final Set<String> before = <String>{
          for (final Map<String, dynamic> slot in await api.trainerSlots())
            slot['id'] as String,
        };

        await bootSignedOut(tester);
        await loginAsTrainer(tester);
        await _openSchedule(tester, _slotDay);

        await tester.tap(find.byKey(const ValueKey<String>('schedule-open-slots')));
        await pumpUntil(
          tester,
          find.byKey(const ValueKey<String>('slot-create')),
          step: '예약 슬롯 시트',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('slot-capacity-input')),
          '$_capacity',
        );
        await tester.tap(find.byKey(const ValueKey<String>('slot-create')));

        // 서버가 만든 슬롯을 먼저 확정하고, 그 id 로 화면을 확인한다. 화면의 행만
        // 보면 "무엇이든 하나 생겼다" 까지만 알 수 있다.
        Map<String, dynamic>? created;
        final DateTime deadline = DateTime.now().add(const Duration(seconds: 20));
        while (created == null && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 200));
          for (final Map<String, dynamic> slot in await api.trainerSlots()) {
            if (!before.contains(slot['id'])) {
              created = slot;
              break;
            }
          }
        }
        expect(created, isNotNull, reason: '슬롯 열기 UI 가 서버에 슬롯을 만들지 못했습니다.');

        expect(created!['capacity'], _capacity);
        expect(
          created['remaining'],
          _capacity,
          reason: '새로 연 슬롯의 잔여 좌석은 정원과 같아야 합니다.',
        );
        expect(created['is_closed'], isFalse);

        // 시트를 닫았다 다시 연다. 생성 직후의 목록을 그대로 훑으면 결과가 흔들린다 —
        // 자리가 쌓여 목록이 길어지면 새 자리는 맨 아래에 붙는데, 갱신으로 리스트가
        // 재빌드될 때 스크롤 위치가 초기화되어 바닥에 닿기 전에 훑기가 끝난다.
        // 다시 열면 목록을 새로 받아오므로, 확인하려는 계약("연 자리가 슬롯 목록에
        // 보인다")은 그대로 두고 타이밍 의존만 걷어낼 수 있다.
        // 닫기 아이콘은 시트 안에서만 찾는다. 트리 전체를 뒤지면 같은 화면에 다른
        // 닫기 컨트롤이 붙는 순간 여러 개가 잡혀 깨진다.
        await tester.tap(
          find.descendant(
            of: find.byType(ReservationSlotsSheet),
            matching: find.byIcon(Icons.close),
          ),
        );
        await pumpUntilAbsent(
          tester,
          find.byType(ReservationSlotsSheet),
          step: '슬롯 시트 닫힘',
        );
        await tester.tap(find.byKey(const ValueKey<String>('schedule-open-slots')));
        await pumpUntil(
          tester,
          find.byKey(const ValueKey<String>('slot-create')),
          step: '예약 슬롯 시트 재진입',
        );

        await pumpUntilVisibleInList(
          tester,
          find.byKey(ValueKey<String>('slot-row-${created['id']}')),
          // `Scrollable` 로 찾으면 정원 입력칸의 내부 편집 스크롤까지 잡힌다.
          list: find.descendant(
            of: find.byType(ReservationSlotsSheet),
            matching: find.byType(ListView),
          ),
          step: '새 슬롯이 시트 목록에 표시',
        );

        // 이 시각에 **이미 있던** 예약 일정들. 앞선 실행이 남긴 것과 이번 예약이
        // 만들 것을 구분하는 기준선이다.
        final DateTime startsAt = DateTime.parse(
          created['starts_at'] as String,
        ).toLocal();
        E2eState.merge(<String, Object?>{
          'slotId': created['id'],
          'slotStartsAt': created['starts_at'],
          'slotCapacity': _capacity,
          'sessionIdsBefore': <String>[
            for (final Map<String, dynamic> session
                in await api.reservationSessionsAt(startsAt))
              session['id'] as String,
          ],
        });

      case 'verify-schedule':
        final E2eState state = E2eState.read();
        final DateTime startsAt = state.slotStartsAt;

        // 회원이 잡은 자리가 트레이너의 일정으로 파생됐는지 — 서버에서 먼저 확정한다.
        // 앞선 실행이 남긴 같은 시각의 일정과 섞이지 않도록 기준선과의 차집합으로 고른다.
        final Set<String> before = state.sessionIdsBefore;
        final List<Map<String, dynamic>> fresh = <Map<String, dynamic>>[
          for (final Map<String, dynamic> row
              in await api.reservationSessionsAt(startsAt))
            if (!before.contains(row['id'])) row,
        ];
        expect(
          fresh,
          hasLength(1),
          reason: '회원 예약으로 생긴 일정이 정확히 하나여야 합니다(발견: ${fresh.length}건).',
        );
        final Map<String, dynamic> session = fresh.single;

        await bootSignedOut(tester);
        await loginAsTrainer(tester);
        await _openSchedule(tester, startsAt);

        // 그리고 그 일정이 실제로 트레이너 화면에 그려지는지.
        await pumpUntil(
          tester,
          find.byKey(ValueKey<String>('schedule-session-${session['id']}')),
          step: '회원 예약으로 생긴 일정 표시',
        );
        expect(find.text(memberName), findsWidgets);

        E2eState.merge(<String, Object?>{'scheduleId': session['id']});

      case 'verify-schedule-removed':
        final E2eState state = E2eState.read();
        final DateTime startsAt = state.slotStartsAt;
        final String scheduleId = state.require('scheduleId');

        // 이번 실행이 만든 그 일정이 사라졌는가. "그 시각에 아무 일정도 없다" 가
        // 아니라 **우리 것이 없다** 를 본다 — 앞선 실행의 잔여가 있어도 판정이 흔들리지
        // 않아야 한다.
        expect(
          <String>[
            for (final Map<String, dynamic> row
                in await api.reservationSessionsAt(startsAt))
              row['id'] as String,
          ],
          isNot(contains(scheduleId)),
          reason: '취소했는데 파생 일정이 서버에 남아 있습니다.',
        );

        await bootSignedOut(tester);
        await loginAsTrainer(tester);
        await _openSchedule(tester, startsAt);

        await pumpUntilAbsent(
          tester,
          find.byKey(ValueKey<String>('schedule-session-$scheduleId')),
          step: '취소된 일정 사라짐',
        );

        // 좌석도 함께 돌아왔는지. 예약 전 정원과 같아야 한다.
        final Map<String, dynamic> slot = await api.slotById(
          state.require('slotId'),
        );
        expect(
          slot['remaining'],
          slot['capacity'],
          reason: '취소 후 잔여 좌석이 정원까지 복구되지 않았습니다.',
        );

      case 'cleanup':
        // 슬롯 삭제 API 는 없다(닫기만 가능). 닫아 두면 다음 실행이 이 자리를 다시
        // 잡지 않으므로 반복 실행이 서로 간섭하지 않는다.
        final E2eState state = E2eState.read();
        await api.closeSlot(state.require('slotId'));
        final Map<String, dynamic> slot = await api.slotById(
          state.require('slotId'),
        );
        expect(slot['is_closed'], isTrue);

      default:
        fail('알 수 없는 E2E_PHASE: "$e2ePhase"');
    }
  });
}
