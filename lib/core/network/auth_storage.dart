import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Persists auth tokens and user profile.
///
/// On web: uses [SharedPreferences] (backed by localStorage) because
/// [FlutterSecureStorage] on web ties its encryption key to the page origin
/// (including port), which changes between `flutter run` invocations.
/// On native: uses [FlutterSecureStorage] with encrypted storage.
class AuthStorage {
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  final _secure = const FlutterSecureStorage(aOptions: _androidOptions);

  // ── helpers ────────────────────────────────────────────────────────────

  Future<String?> _read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
    return _secure.read(key: key);
  }

  Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      await _secure.write(key: key, value: value);
    }
  }

  Future<void> _delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      await _secure.delete(key: key);
    }
  }

  // ── public API ─────────────────────────────────────────────────────────

  Future<String?> getAccessToken() => _read(AppConstants.tokenKey);

  Future<String?> getRefreshToken() => _read(AppConstants.refreshTokenKey);

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await Future.wait([
      _write(AppConstants.tokenKey, access),
      _write(AppConstants.refreshTokenKey, refresh),
    ]);
  }

  Future<void> saveUserProfile(String jsonString) =>
      _write(AppConstants.userProfileKey, jsonString);

  Future<String?> getUserProfile() => _read(AppConstants.userProfileKey);

  Future<void> clear() async {
    await Future.wait([
      _delete(AppConstants.tokenKey),
      _delete(AppConstants.refreshTokenKey),
      _delete(AppConstants.userProfileKey),
    ]);
  }

  Future<bool> hasAccessToken() async {
    final token = await _read(AppConstants.tokenKey);
    return token != null;
  }
}
