import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef ResetSessionFeatureState = void Function();

/// Features with account-specific in-memory state register their reset work at
/// the app composition boundary. Auth only invokes this contract.
final sessionFeatureResetProvider = Provider<ResetSessionFeatureState>(
  (ref) => () {},
  name: 'sessionFeatureReset',
);
