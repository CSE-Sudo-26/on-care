import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/features/account/data/repositories/dio_account_repository.dart';
import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/account/domain/repositories/account_repository.dart';

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => DioAccountRepository(ref.watch(dioProvider)),
  name: 'accountRepository',
);

class ProfileController extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() {
    return ref.watch(accountRepositoryProvider).fetchProfile();
  }

  /// PUT 응답에 포함된 최신 프로필을 홈·식단·운동 화면에 즉시 공유한다.
  void applyUpdatedProfile(UserProfile profile) {
    state = AsyncData<UserProfile>(profile);
  }
}

final profileProvider = AsyncNotifierProvider<ProfileController, UserProfile>(
  ProfileController.new,
  name: 'profile',
);
