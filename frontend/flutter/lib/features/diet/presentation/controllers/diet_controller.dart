import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/features/diet/data/repositories/dio_diet_repository.dart';
import 'package:oncare/features/diet/data/repositories/mock_diet_repository.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/domain/repositories/diet_repository.dart';

final dietRepositoryProvider = Provider<DietRepository>((ref) {
  // In local/demo mode serve the fully-populated mock day (food photos,
  // per-food nutrition, per-meal AI feedback) so the diet tab renders
  // real-looking data with no backend. The real REST repo is used otherwise.
  if (ref.watch(appConfigProvider).useMockApi) {
    return const MockDietRepository();
  }
  return DioDietRepository(ref.watch(dioProvider));
}, name: 'dietRepository');

final dietTodayProvider = FutureProvider<DietDay>((ref) {
  return ref.watch(dietRepositoryProvider).fetchToday();
}, name: 'dietToday');
