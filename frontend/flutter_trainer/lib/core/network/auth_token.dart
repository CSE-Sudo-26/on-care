import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current access token, mirrored here (a leaf provider) so the
/// [AuthInterceptor] can read it synchronously without importing the auth
/// feature (avoids a dio_client ↔ session_controller import cycle). The
/// [SessionController] writes it on login/restore and clears it on
/// sign-out.
final authAccessTokenProvider = StateProvider<String?>(
  (ref) => null,
  name: 'authAccessToken',
);
