import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/features/ai_routine/data/dtos/routine_options_dtos.dart';

void main() {
  test('routineOptionsFromJson maps analysis + A/B plans', () {
    final o = routineOptionsFromJson(<String, Object?>{
      'analysis': <String, Object?>{
        'goal': '혈압 관리',
        'sodium_today_mg': 2100,
        'sodium_over_target': true,
        'avg_completion_rate': 55,
        'latest_routine': '걷기',
        'note': '무릎 주의',
      },
      'plan_a': <String, Object?>{
        'key': 'A',
        'label': '회복·지속 중심',
        'total_minutes': 21,
        'intensity': '낮음',
        'exercises': <Object?>[
          <String, Object?>{'name': '저강도 걷기', 'minutes': 13, 'type': '유산소'},
          <String, Object?>{'name': '코어 스트레칭', 'minutes': 8, 'type': '스트레칭'},
        ],
        'reason': '지속 중심',
        'rationale': '오늘 나트륨 2100mg (목표 초과) ...',
      },
      'plan_b': <String, Object?>{
        'key': 'B',
        'label': '강도·운동량 중심',
        'total_minutes': 30,
        'intensity': '높음',
        'exercises': <Object?>[
          <String, Object?>{'name': '인터벌 러닝', 'minutes': 30, 'type': '유산소'},
        ],
        'reason': '강도 상향',
        'rationale': '목표 기준 ...',
      },
      'generated_by': 'rule',
    });

    expect(o.analysis.goal, '혈압 관리');
    expect(o.analysis.sodiumOverTarget, isTrue);
    expect(o.analysis.avgCompletionRate, 55);
    expect(o.planA.key, 'A');
    expect(o.planA.exercises.length, 2);
    expect(o.planA.exercises.first.name, '저강도 걷기');
    expect(o.planB.totalMinutes, 30);
    expect(o.generatedBy, 'rule');
  });

  test('tolerates missing/invalid fields', () {
    final o = routineOptionsFromJson(<String, Object?>{});
    expect(o.analysis.goal, '');
    expect(o.planA.exercises, isEmpty);
    expect(o.generatedBy, '');
  });
}
