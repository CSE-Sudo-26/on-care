/// 루틴 한 줄의 단계 계약. (#934)
///
/// 저장값은 영어 키다 — 화면 문구를 저장하면 로케일이 계약이 된다. 단계 칸이
/// 없던 초안·템플릿은 전부 본운동으로 읽어야 기존 데이터가 깨지지 않는다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/features/coaching/data/dtos/program_draft_dtos.dart';
import 'package:oncare_trainer/features/coaching/domain/program_editor_state.dart';
import 'package:oncare_trainer/features/coaching/domain/program_template.dart';
import 'package:oncare_trainer/features/coaching/domain/routine_phase.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations_ko.dart';

void main() {
  test('모르는 값과 빈 값은 본운동으로 읽는다', () {
    expect(normaliseRoutinePhase(null), kRoutinePhaseMain);
    expect(normaliseRoutinePhase(''), kRoutinePhaseMain);
    expect(normaliseRoutinePhase('준비운동'), kRoutinePhaseMain);
    expect(normaliseRoutinePhase('warmup'), kRoutinePhaseWarmup);
    expect(normaliseRoutinePhase('cooldown'), kRoutinePhaseCooldown);
  });

  test('단계 이름은 로케일에서 온다', () {
    final l = AppLocalizationsKo();
    expect(routinePhaseLabel(l, kRoutinePhaseWarmup), '준비운동');
    expect(routinePhaseLabel(l, kRoutinePhaseMain), '본운동');
    expect(routinePhaseLabel(l, kRoutinePhaseCooldown), '마무리');
  });

  test('초안 payload 가 단계를 싣고, 옛 초안은 본운동으로 열린다', () {
    const ProgramExerciseDraft draft = ProgramExerciseDraft(
      id: 'e-1',
      name: '가벼운 걷기',
      type: '유산소',
      minutes: 10,
      phase: kRoutinePhaseWarmup,
    );

    expect(programExerciseToJson(draft)['phase'], 'warmup');
    // 단계 칸이 없던 초안.
    expect(
      programExerciseFromJson(<String, Object?>{
        'id': 'e-2',
        'name': '스쿼트',
        'type': '근력',
      }).phase,
      kRoutinePhaseMain,
    );
  });

  test('템플릿도 같은 계약을 쓴다', () {
    const TemplateExercise warmup = TemplateExercise(
      name: '준비 스트레칭',
      minutes: 10,
      type: '스트레칭',
      phase: kRoutinePhaseWarmup,
    );

    expect(warmup.toJson()['phase'], 'warmup');
    expect(
      TemplateExercise.fromJson(<String, Object?>{
        'name': '스쿼트',
        'minutes': 15,
        'type': '근력',
      }).phase,
      kRoutinePhaseMain,
    );
  });
}
