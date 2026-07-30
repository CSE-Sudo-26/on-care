import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/ai_routine/data/repositories/dio_trainer_routine_repository.dart';
import 'package:oncare_trainer/features/ai_routine/domain/entities/assigned_routine.dart';

class _MockDio extends Mock implements Dio {}

Response<T> _ok<T>(T body, String path) => Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 201,
      data: body,
    );

DioException _httpError(int status, String path) => DioException(
      requestOptions: RequestOptions(path: path),
      type: DioExceptionType.badResponse,
      response: Response<Object?>(
        requestOptions: RequestOptions(path: path),
        statusCode: status,
      ),
    );

void main() {
  late _MockDio dio;
  late DioTrainerRoutineRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = DioTrainerRoutineRepository(dio);
  });

  test('assignRoutine POSTs the normalised RoutineAssignRequest body', () async {
    when(() => dio.post<Map<String, Object?>>(
          '/trainer/clients/m1/routines',
          data: any(named: 'data'),
        )).thenAnswer(
      (_) async => _ok<Map<String, Object?>>(
        <String, Object?>{'id': 'r1'},
        '/trainer/clients/m1/routines',
      ),
    );

    await repo.assignRoutine(
      'm1',
      const AssignedRoutine(
        id: '',
        name: 'AI 맞춤 루틴',
        minutes: 999, // clamped to 600
        type: 'weird', // -> 근력
        reason: '걷기, 스쿼트',
        source: 'ai',
      ),
    );

    verify(() => dio.post<Map<String, Object?>>(
          '/trainer/clients/m1/routines',
          data: <String, Object?>{
            'name': 'AI 맞춤 루틴',
            'minutes': 600,
            'type': '근력',
            'reason': '걷기, 스쿼트',
            'source': 'ai',
          },
        )).called(1);
  });

  test('assignRoutine surfaces a failure as AppError', () async {
    when(() => dio.post<Map<String, Object?>>(
          '/trainer/clients/m1/routines',
          data: any(named: 'data'),
        )).thenThrow(_httpError(500, '/trainer/clients/m1/routines'));

    await expectLater(
      repo.assignRoutine(
        'm1',
        const AssignedRoutine(
          id: '',
          name: 'x',
          minutes: 30,
          type: '근력',
          reason: '',
          source: 'ai',
        ),
      ),
      throwsA(isA<AppError>()),
    );
  });

  test('watchAssignedRoutines parses the list', () async {
    when(() => dio.get<List<dynamic>>('/trainer/clients/m1/routines')).thenAnswer(
      (_) async => Response<List<dynamic>>(
        requestOptions: RequestOptions(path: '/trainer/clients/m1/routines'),
        statusCode: 200,
        data: <dynamic>[
          <String, Object?>{'id': 'r1', 'name': '저강도 유산소', 'minutes': 30, 'type': '유산소', 'reason': '혈압', 'source': 'ai'},
        ],
      ),
    );

    final routines = await repo.watchAssignedRoutines('m1').first;
    expect(routines.single.name, '저강도 유산소');
    expect(routines.single.type, '유산소');
  });

  test('watchAssignedRoutines surfaces a 404 as NotFoundError', () async {
    when(() => dio.get<List<dynamic>>('/trainer/clients/x/routines'))
        .thenThrow(_httpError(404, '/trainer/clients/x/routines'));

    await expectLater(
      repo.watchAssignedRoutines('x'),
      emitsError(isA<NotFoundError>()),
    );
  });
}
