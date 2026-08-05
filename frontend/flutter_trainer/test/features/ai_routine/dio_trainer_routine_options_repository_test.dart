import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/ai_routine/data/repositories/dio_trainer_routine_options_repository.dart';

class _MockDio extends Mock implements Dio {}

Map<String, Object?> _optionsBody() => <String, Object?>{
  'analysis': <String, Object?>{
    'goal': '혈압',
    'sodium_today_mg': 2100,
    'sodium_over_target': true,
    'avg_completion_rate': 55,
    'latest_routine': '걷기',
    'note': '무릎 주의',
  },
  'plan_a': <String, Object?>{
    'key': 'A',
    'label': '회복',
    'total_minutes': 21,
    'intensity': '낮음',
    'exercises': <Object?>[
      <String, Object?>{'name': '걷기', 'minutes': 21, 'type': '유산소'},
    ],
    'reason': '회복',
    'rationale': '지속',
  },
  'plan_b': <String, Object?>{
    'key': 'B',
    'label': '강도',
    'total_minutes': 30,
    'intensity': '높음',
    'exercises': <Object?>[
      <String, Object?>{'name': '러닝', 'minutes': 30, 'type': '유산소'},
    ],
    'reason': '강도',
    'rationale': '운동량',
  },
  'generated_by': 'rule',
};

void main() {
  late _MockDio dio;
  late DioTrainerRoutineOptionsRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = DioTrainerRoutineOptionsRepository(dio);
  });

  test('generate POSTs the steering inputs and parses A/B', () async {
    when(
      () => dio.post<Map<String, Object?>>(
        '/trainer/clients/m1/routine-options',
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, Object?>>(
        requestOptions: RequestOptions(
          path: '/trainer/clients/m1/routine-options',
        ),
        statusCode: 200,
        data: _optionsBody(),
      ),
    );

    final o = await repo.generate(
      'm1',
      availableMinutes: 30,
      intensityPreference: 'moderate',
      trainerNote: '무릎 주의',
    );
    expect(o.planA.key, 'A');
    expect(o.planB.totalMinutes, 30);

    verify(
      () => dio.post<Map<String, Object?>>(
        '/trainer/clients/m1/routine-options',
        data: <String, Object?>{
          'available_minutes': 30,
          'intensity_preference': 'moderate',
          'trainer_note': '무릎 주의',
        },
      ),
    ).called(1);
  });

  test('surfaces a failure as AppError', () async {
    when(
      () => dio.post<Map<String, Object?>>(
        '/trainer/clients/m1/routine-options',
        data: any(named: 'data'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(
          path: '/trainer/clients/m1/routine-options',
        ),
        type: DioExceptionType.badResponse,
        response: Response<Object?>(
          requestOptions: RequestOptions(
            path: '/trainer/clients/m1/routine-options',
          ),
          statusCode: 404,
        ),
      ),
    );

    await expectLater(
      repo.generate(
        'm1',
        availableMinutes: 30,
        intensityPreference: 'moderate',
        trainerNote: '',
      ),
      throwsA(isA<AppError>()),
    );
  });

  test('encodes an opaque member id as one path segment', () async {
    const path = '/trainer/clients/member%2Fwith%3Freserved/routine-options';
    when(
      () => dio.post<Map<String, Object?>>(path, data: any(named: 'data')),
    ).thenAnswer(
      (_) async => Response<Map<String, Object?>>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: _optionsBody(),
      ),
    );

    await repo.generate(
      'member/with?reserved',
      availableMinutes: 30,
      intensityPreference: 'moderate',
      trainerNote: '',
    );

    verify(
      () => dio.post<Map<String, Object?>>(path, data: any(named: 'data')),
    ).called(1);
  });
}
