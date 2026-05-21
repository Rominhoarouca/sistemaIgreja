import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import 'auth_storage.dart';

/// Dio HTTP client with automatic token injection and transparent token refresh.
///
/// On every request: injects `Authorization: Bearer <token>` header.
/// On 401 response (non-auth endpoints): attempts a silent token refresh and
/// retries the original request once. If refresh fails, [onForceLogout] is called.
class DioClient {
  late final Dio _dio;
  final AuthStorage _storage;

  /// Called when a 401 cannot be recovered (refresh token expired / invalid).
  void Function()? onForceLogout;

  DioClient(this._storage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(_AuthInterceptor(_dio, _storage, this));
  }

  Dio get dio => _dio;
}

class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  final AuthStorage _storage;
  final DioClient _client;
  bool _isRefreshing = false;

  _AuthInterceptor(this._dio, this._storage, this._client);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final isAuthEndpoint =
        err.requestOptions.path.contains('/auth/login') ||
        err.requestOptions.path.contains('/auth/refresh') ||
        err.requestOptions.path.contains('/auth/register');

    if (!isUnauthorized || isAuthEndpoint || _isRefreshing) {
      handler.next(err);
      return;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        _triggerLogout();
        handler.next(err);
        return;
      }

      final refreshResponse = await _dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(
          headers: {
            'Authorization': null, // remove token for refresh call
            'Content-Type': 'application/json',
          },
          extra: {'skipAuth': true},
        ),
      );

      final newAccess = refreshResponse.data['accessToken'] as String;
      final newRefresh = refreshResponse.data['refreshToken'] as String;
      await _storage.saveTokens(access: newAccess, refresh: newRefresh);

      // Retry the original request with the new token.
      final retryOpts = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newAccess';
      final retryResponse = await _dio.fetch(retryOpts);
      handler.resolve(retryResponse);
    } catch (_) {
      await _storage.clear();
      _triggerLogout();
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }

  void _triggerLogout() => _client.onForceLogout?.call();
}
