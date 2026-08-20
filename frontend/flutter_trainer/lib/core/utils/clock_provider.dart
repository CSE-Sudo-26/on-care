import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/utils/clock.dart';

/// 화면이 "지금" 을 읽는 자리. 기본값은 서비스 기준 시계([nowKst]). (#1006)
///
/// 시계를 provider 로 빼 두는 까닭은 **테스트**다. 1분마다 스스로 갱신하는 화면은
/// 그 시각을 바깥에서 정할 수 없으면 무엇도 검증할 수 없다 — 실제 시계를 그대로
/// 쓰면 "30분이 지나면 선이 반 칸 내려온다" 를 재려고 30분을 기다려야 한다.
///
/// 기본값이 `nowKst` 그대로라 앱의 동작은 달라지지 않는다. `DateTime.now()` 를
/// 섞지 않는다는 규약(`test/core/utils/clock_test.dart`)도 그대로 지켜진다 —
/// 이 자리가 돌려주는 것이 바로 그 함수다.
final scheduleClockProvider = Provider<DateTime Function()>(
  (ref) => nowKst,
  name: 'scheduleClock',
);
