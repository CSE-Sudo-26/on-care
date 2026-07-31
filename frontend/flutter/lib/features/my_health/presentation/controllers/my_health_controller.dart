import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/features/my_health/data/repositories/dio_my_health_repository.dart';
import 'package:oncare/features/my_health/data/repositories/mock_my_health_repository.dart';
import 'package:oncare/features/my_health/domain/entities/health_history.dart';
import 'package:oncare/features/my_health/domain/repositories/my_health_repository.dart';

final myHealthRepositoryProvider = Provider<MyHealthRepository>((ref) {
  // 실모드(USE_MOCK_API=false)에서는 백엔드 /users/me/health 로 실제 프로필·활동점수·
  // 위험도를 읽는다(health_profile 있으면 실데이터, 없으면 백엔드가 데모 기본값 반환).
  // 데모/로컬 모드에서만 인메모리 mock 을 사용한다. diet/exercise 와 동일한 분기.
  if (ref.watch(appConfigProvider).useMockApi) {
    return const MockMyHealthRepository();
  }
  return DioMyHealthRepository(ref.watch(dioProvider));
}, name: 'myHealthRepository');

final myHealthStateProvider = FutureProvider<MyHealthState>((ref) {
  return ref.watch(myHealthRepositoryProvider).fetchState();
}, name: 'myHealthState');
