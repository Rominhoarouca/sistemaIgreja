import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import 'auth_storage.dart';

/// Dio HTTP client with automatic token injection and transparent token refresh.
///
/// On every request: injects `Authorization: Bearer <token>` header.
/// On 401 response (non-auth endpoints): attempts a silent token refresh and
/// retries the original request once. If refresh fails, [onForceLogout] is called.
class DioClient {
  /// Global fallback for force-logout, set once by the singleton registered
  /// in DI. Non-singleton clients (created directly in pages) will use this
  /// when their own [onForceLogout] is null.
  static void Function()? globalOnForceLogout;

  late final Dio _dio;
  final AuthStorage _storage;

  /// Called when a 401 cannot be recovered (refresh token expired / invalid).
  void Function()? onForceLogout;

  DioClient(this._storage) {
    final logLevel = _DioLogLevelX.fromEnvironment();

    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    if (!kReleaseMode && logLevel != _DioLogLevel.none) {
      _dio.interceptors.add(_DevLoggingInterceptor(level: logLevel));
    }

    _dio.interceptors.add(_AuthInterceptor(_dio, _storage, this));
  }

  Dio get dio => _dio;
}

enum _DioLogLevel { none, basic, verbose }

extension _DioLogLevelX on _DioLogLevel {
  static _DioLogLevel fromEnvironment() {
    const raw = String.fromEnvironment('DIO_LOG_LEVEL', defaultValue: 'basic');
    switch (raw.toLowerCase()) {
      case 'none':
        return _DioLogLevel.none;
      case 'verbose':
        return _DioLogLevel.verbose;
      case 'basic':
      default:
        return _DioLogLevel.basic;
    }
  }
}

class _DevLoggingInterceptor extends Interceptor {
  static const _startedAtKey = '__startedAtMicros';

  final _DioLogLevel level;

  _DevLoggingInterceptor({required this.level});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtKey] = DateTime.now().microsecondsSinceEpoch;

    _log('[DIO][REQ] ${options.method.toUpperCase()} ${options.uri}');

    if (level == _DioLogLevel.verbose) {
      _log('[DIO][REQ][HEADERS] ${_formatHeaders(options.headers)}');
      _log('[DIO][REQ][QUERY] ${_formatData(options.queryParameters)}');
      _log('[DIO][REQ][BODY] ${_formatData(options.data)}');
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final elapsed = _elapsedMs(response.requestOptions.extra[_startedAtKey]);
    _log(
      '[DIO][RES] ${response.statusCode} ${response.requestOptions.method.toUpperCase()} ${response.requestOptions.uri} (${elapsed}ms)',
    );

    if (level == _DioLogLevel.verbose) {
      _log('[DIO][RES][HEADERS] ${_formatHeaders(response.headers.map)}');
      _log('[DIO][RES][BODY] ${_formatData(response.data)}');
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final elapsed = _elapsedMs(err.requestOptions.extra[_startedAtKey]);
    _log(
      '[DIO][ERR] ${err.response?.statusCode ?? 'NO_STATUS'} ${err.requestOptions.method.toUpperCase()} ${err.requestOptions.uri} (${elapsed}ms) ${err.message ?? ''}',
    );

    if (level == _DioLogLevel.verbose) {
      _log('[DIO][ERR][HEADERS] ${_formatHeaders(err.requestOptions.headers)}');
      _log('[DIO][ERR][REQ_BODY] ${_formatData(err.requestOptions.data)}');
      _log('[DIO][ERR][RES_BODY] ${_formatData(err.response?.data)}');
    }

    handler.next(err);
  }

  int _elapsedMs(Object? startedAtMicros) {
    if (startedAtMicros is! int) return 0;
    final nowMicros = DateTime.now().microsecondsSinceEpoch;
    return ((nowMicros - startedAtMicros) / 1000).round();
  }

  String _formatHeaders(Map<dynamic, dynamic>? headers) {
    if (headers == null || headers.isEmpty) return '{}';

    final sanitized = <String, dynamic>{};
    headers.forEach((key, value) {
      final keyStr = key.toString();
      if (keyStr.toLowerCase() == 'authorization') {
        sanitized[keyStr] = _maskToken(value?.toString() ?? '');
      } else {
        sanitized[keyStr] = value;
      }
    });

    return _formatData(sanitized);
  }

  String _maskToken(String token) {
    if (token.isEmpty) return token;
    if (token.length <= 14) return '***';
    return '${token.substring(0, 10)}...${token.substring(token.length - 4)}';
  }

  String _formatData(Object? data) {
    if (data == null) return 'null';
    try {
      if (data is String) {
        return data.length > 4000
            ? '${data.substring(0, 4000)}...<truncated>'
            : data;
      }
      const encoder = JsonEncoder.withIndent('  ');
      final encoded = encoder.convert(data);
      return encoded.length > 4000
          ? '${encoded.substring(0, 4000)}...<truncated>'
          : encoded;
    } catch (_) {
      final fallback = data.toString();
      return fallback.length > 4000
          ? '${fallback.substring(0, 4000)}...<truncated>'
          : fallback;
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      // Mirrors logs to Flutter console where developer.log may be filtered.
      debugPrint(message);
    }
    developer.log(message, name: 'DIO');
  }
}

class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  final AuthStorage _storage;
  final DioClient _client;

  // Requisições concorrentes que expiram ao mesmo tempo (comum em telas que
  // disparam vários GETs em paralelo, ex. Future.wait) todas caem em 401
  // quase juntas. Antes, só a PRIMEIRA disparava o refresh — as demais viam
  // `_isRefreshing == true` e desistiam direto com o 401 original, sem
  // reter. Resultado: algumas ações falhavam silenciosamente até dar F5
  // (que recomeça do zero e só dispara 1 request por vez). Agora todo 401
  // concorrente espera o MESMO refresh em andamento (Completer compartilhado)
  // e cada um tenta de novo com o token novo assim que ele sai.
  Completer<String?>? _refreshCompleter;

  _AuthInterceptor(this._dio, this._storage, this._client);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _storage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // Storage read failed — proceed without auth header.
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

    if (!isUnauthorized || isAuthEndpoint) {
      handler.next(err);
      return;
    }

    final newAccess = await _refreshAccessToken();
    if (newAccess == null) {
      handler.next(err);
      return;
    }

    try {
      // Retry the original request with the new token.
      final retryOpts = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newAccess';
      final retryResponse = await _dio.fetch(retryOpts);
      handler.resolve(retryResponse);
    } catch (_) {
      handler.next(err);
    }
  }

  /// Garante uma única chamada a `/auth/refresh` em voo por vez — chamadas
  /// concorrentes aguardam o mesmo [Completer] em vez de disparar cada uma
  /// o seu próprio refresh (o que invalidaria o refresh token das outras).
  Future<String?> _refreshAccessToken() {
    final inFlight = _refreshCompleter;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    Future<void>(() async {
      try {
        final refreshToken = await _storage.getRefreshToken();
        if (refreshToken == null) {
          _triggerLogout();
          completer.complete(null);
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
        completer.complete(newAccess);
      } catch (_) {
        await _storage.clear();
        _triggerLogout();
        completer.complete(null);
      } finally {
        _refreshCompleter = null;
      }
    });

    return completer.future;
  }

  void _triggerLogout() {
    (_client.onForceLogout ?? DioClient.globalOnForceLogout)?.call();
  }
}
