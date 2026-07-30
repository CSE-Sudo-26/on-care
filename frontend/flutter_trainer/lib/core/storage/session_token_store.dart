import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oncare_trainer/core/storage/prefs_provider.dart';

/// Persists the trainer session's access token across app restarts.
///
/// Backed by [SharedPreferences] for now — the token is a mock demo
/// token until the real backend lands. The store is intentionally a
/// thin abstraction so the backing implementation can be swapped for
/// secure storage (Keychain / Keystore) when real credentials are
/// introduced, without touching the session layer.
class SessionTokenStore {
  /// Creates a store over the given [SharedPreferences] instance.
  const SessionTokenStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _tokenKey = 'trainer_access_token';
  static const String _nameKey = 'trainer_profile_name';
  static const String _emailKey = 'trainer_profile_email';

  /// Returns the persisted access token, or `null` if the trainer is
  /// signed out.
  String? readToken() {
    final token = _prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) return null;
    return token;
  }

  /// Returns the persisted profile name submitted at 회원가입, or `null`
  /// when the session used the seed identity (login / social / demo).
  String? readProfileName() => _readNonEmpty(_nameKey);

  /// Returns the persisted profile email submitted at 회원가입, or `null`
  /// when the session used the seed identity.
  String? readProfileEmail() => _readNonEmpty(_emailKey);

  /// Persists [token] so the session survives an app restart, together
  /// with the optional profile identity ([name] / [email]) submitted at
  /// 회원가입. A `null`/blank identity field is removed so restore falls
  /// back to the seed profile — logins keep the seed identity, while a
  /// registered trainer's submitted name/email survive a restart.
  Future<void> saveSession({
    required String token,
    String? name,
    String? email,
  }) async {
    await _prefs.setString(_tokenKey, token);
    await _writeOrRemove(_nameKey, name);
    await _writeOrRemove(_emailKey, email);
  }

  /// Clears the persisted token and profile identity (sign-out).
  Future<void> clear() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_nameKey);
    await _prefs.remove(_emailKey);
  }

  String? _readNonEmpty(String key) {
    final value = _prefs.getString(key);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> _writeOrRemove(String key, String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return _prefs.remove(key);
    return _prefs.setString(key, trimmed);
  }
}

/// Provides the [SessionTokenStore], wired to the app-wide prefs.
final sessionTokenStoreProvider = Provider<SessionTokenStore>((ref) {
  return SessionTokenStore(ref.watch(sharedPreferencesProvider));
});
