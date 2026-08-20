import 'package:flutter/material.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 프로그램 편집기가 들고 있는 운동 한 행의 초안.
///
/// 입력 컨트롤러 묶음이라 저장 전까지는 어떤 도메인 값도 만들지 않는다.
/// 편집기를 닫을 때 [dispose] 로 함께 정리한다.
class ProgramDraft {
  ProgramDraft({
    required String name,
    required String sets,
    required String reps,
    required String weight,
  }) : name = TextEditingController(text: name),
       sets = TextEditingController(text: sets),
       reps = TextEditingController(text: reps),
       weight = TextEditingController(text: weight);

  factory ProgramDraft.fromItem(ProgramItem item) => ProgramDraft(
    name: item.name,
    sets: '${item.sets}',
    reps: item.reps,
    weight: item.weight == '-' ? '' : item.weight,
  );

  /// 새 운동 행의 기본값. reps 는 트레이너가 바로 고쳐 쓰는 입력값이라
  /// 트레이너의 로케일을 따른다.
  factory ProgramDraft.empty(AppLocalizations l) =>
      ProgramDraft(name: '', sets: '3', reps: l.progDefaultReps, weight: '');

  final TextEditingController name;
  final TextEditingController sets;
  final TextEditingController reps;
  final TextEditingController weight;

  void dispose() {
    name.dispose();
    sets.dispose();
    reps.dispose();
    weight.dispose();
  }
}
