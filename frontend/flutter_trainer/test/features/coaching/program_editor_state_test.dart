import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/features/coaching/domain/program_editor_state.dart';

void main() {
  ProgramEditorState draftWith({required String name, required String sets}) {
    return ProgramEditorState(
      name: '프로그램',
      sessions: <ProgramSessionDraft>[
        ProgramSessionDraft(
          id: 'session-1',
          name: '세션 A',
          exercises: <ProgramExerciseDraft>[
            ProgramExerciseDraft(id: 'exercise-1', name: name, sets: sets),
          ],
        ),
      ],
    );
  }

  test('flat routine support follows the backend item constraints', () {
    expect(draftWith(name: ' 스쿼트 ', sets: '3').supportsFlatRoutine, isTrue);
    expect(draftWith(name: ' ', sets: '3').supportsFlatRoutine, isFalse);
    expect(
      draftWith(
        name: List<String>.filled(101, '운동').join(),
        sets: '3',
      ).supportsFlatRoutine,
      isFalse,
    );
    expect(draftWith(name: '스쿼트', sets: '').supportsFlatRoutine, isFalse);
    expect(draftWith(name: '스쿼트', sets: '100').supportsFlatRoutine, isFalse);
  });

  test('flat routine support rejects structures the API cannot represent', () {
    const empty = ProgramEditorState(
      name: '프로그램',
      sessions: <ProgramSessionDraft>[
        ProgramSessionDraft(id: 'session-1', name: '세션 A', exercises: []),
      ],
    );
    final multiple = ProgramEditorState(
      name: '프로그램',
      sessions: <ProgramSessionDraft>[
        empty.sessions.single,
        empty.sessions.single,
      ],
    );

    expect(empty.supportsFlatRoutine, isFalse);
    expect(multiple.supportsFlatRoutine, isFalse);
  });
}
