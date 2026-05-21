import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// Persists auth tokens and user profile using flutter_secure_storage.
class AuthStorage {
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  final _storage = const FlutterSecureStorage(aOptions: _androidOptions);

  Future<String?> getAccessToken() => _storage.read(key: AppConstants.tokenKey);

  Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.refreshTokenKey);

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await Future.wait([
      _storage.write(key: AppConstants.tokenKey, value: access),
      _storage.write(key: AppConstants.refreshTokenKey, value: refresh),
    ]);
  }

  Future<void> saveUserProfile(String jsonString) =>
      _storage.write(key: AppConstants.userProfileKey, value: jsonString);

  Future<String?> getUserProfile() =>
      _storage.read(key: AppConstants.userProfileKey);

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: AppConstants.tokenKey),
      _storage.delete(key: AppConstants.refreshTokenKey),
      _storage.delete(key: AppConstants.userProfileKey),
    ]);
  }

  Future<bool> hasAccessToken() async =>
      await _storage.read(key: AppConstants.tokenKey) != null;
}
