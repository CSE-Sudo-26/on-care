/// 루틴 한 줄이 속한 단계 — 준비운동 · 본운동 · 마무리. (#934)
///
/// 저장값은 영어 키다(`warmup`·`main`·`cooldown`) — 화면 문구를 그대로 저장하면
/// 로케일이 계약이 된다. 이 칸이 없던 시절의 루틴·템플릿은 전부 본운동으로
/// 읽는다: 그때 트레이너가 적은 구성은 실제로 본운동이었고, 없는 단계를
/// 지어내지 않는다.
library;

import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

const String kRoutinePhaseWarmup = 'warmup';
const String kRoutinePhaseMain = 'main';
const String kRoutinePhaseCooldown = 'cooldown';

/// 화면과 저장이 함께 쓰는 순서 — 몸을 풀고 → 본 운동 → 정리.
const List<String> kRoutinePhases = <String>[
  kRoutinePhaseWarmup,
  kRoutinePhaseMain,
  kRoutinePhaseCooldown,
];

/// 서버·저장값을 계약값으로 좁힌다. 모르는 값은 본운동이다.
String normaliseRoutinePhase(Object? raw) {
  final String value = (raw as String?)?.trim() ?? '';
  return kRoutinePhases.contains(value) ? value : kRoutinePhaseMain;
}

/// 화면에 적는 단계 이름.
String routinePhaseLabel(AppLocalizations l, String phase) =>
    switch (normaliseRoutinePhase(phase)) {
      kRoutinePhaseWarmup => l.routinePhaseWarmup,
      kRoutinePhaseCooldown => l.routinePhaseCooldown,
      _ => l.routinePhaseMain,
    };
