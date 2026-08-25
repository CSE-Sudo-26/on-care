/// 배정 루틴 한 줄이 속한 단계 — 준비운동 · 본운동 · 마무리. (#934)
///
/// 트레이너 앱·백엔드와 같은 계약값을 쓴다. 이 칸이 없던 시절의 루틴은 전부
/// 본운동으로 읽는다 — 없는 단계를 지어내지 않는다.
library;

import 'package:oncare/gen/l10n/app_localizations.dart';

const String kRoutinePhaseWarmup = 'warmup';
const String kRoutinePhaseMain = 'main';
const String kRoutinePhaseCooldown = 'cooldown';

/// 화면이 그리는 차례 — 몸을 풀고 → 본 운동 → 정리.
const List<String> kRoutinePhases = <String>[
  kRoutinePhaseWarmup,
  kRoutinePhaseMain,
  kRoutinePhaseCooldown,
];

/// 서버 값을 계약값으로 좁힌다. 모르는 값은 본운동이다.
String normaliseRoutinePhase(Object? raw) {
  final String value = (raw as String?)?.trim() ?? '';
  return kRoutinePhases.contains(value) ? value : kRoutinePhaseMain;
}

/// 화면에 적는 단계 이름.
String routinePhaseLabel(AppLocalizations l, String phase) =>
    switch (normaliseRoutinePhase(phase)) {
      kRoutinePhaseWarmup => l.exRoutinePhaseWarmup,
      kRoutinePhaseCooldown => l.exRoutinePhaseCooldown,
      _ => l.exRoutinePhaseMain,
    };
