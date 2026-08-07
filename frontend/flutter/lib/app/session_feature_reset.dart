import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/session/session_feature_reset.dart';
import 'package:oncare/features/exercise/presentation/controllers/consultation_request_controller.dart';

/// Connects session transitions to account-specific feature state.
///
/// Register every feature reset here. Riverpod overrides replace each other,
/// so this must remain the single app-level registry.
Override sessionFeatureResetOverride() {
  return sessionFeatureResetProvider.overrideWith((ref) {
    return () {
      ref.invalidate(consultationRequestControllerProvider);
    };
  });
}
