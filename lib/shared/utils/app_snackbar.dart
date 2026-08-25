import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../design_system/design_system.dart';

/// Global key registrado no MaterialApp.
/// Permite exibir SnackBars acima de dialogs e bottom sheets.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Extrai mensagem de erro de forma segura de uma DioException
///
/// LEGADO (refactor Clean Architecture): UI não deve tocar DioException.
/// Novo código usa ErrorMapper.map no RepositoryImpl e consome
/// failure.message. Esta função morre na Fase 9, quando os call sites
/// remanescentes tiverem migrado. Não anotada @Deprecated de propósito:
/// 105 avisos no analyze afogariam problemas reais durante a migração.
String extractDioErrorMessage(
  DioException e, {
  String fallback = 'Erro ao processar requisição',
}) {
  // Debug log
  if (kDebugMode) {
    debugPrint('[DioException] status: ${e.response?.statusCode}');
    debugPrint('[DioException] data type: ${e.response?.data.runtimeType}');
    debugPrint('[DioException] data: ${e.response?.data}');
    debugPrint('[DioException] message: ${e.message}');
  }

  try {
    if (e.response?.data != null) {
      final data = e.response!.data;

      // If response.data is a Map, try to extract message fields
      if (data is Map<String, dynamic>) {
        // First check for nested error object: { error: { message: "..." } }
        if (data['error'] is Map<String, dynamic>) {
          final errorObj = data['error'] as Map<String, dynamic>;
          final message = (errorObj['message'] as String?) ?? '';
          if (message.isNotEmpty) {
            if (kDebugMode) {
              debugPrint(
                '[DioException] Extracted from nested error: $message',
              );
            }
            return message;
          }
        }

        // Try direct fields: message, detail, msg
        var message =
            (data['message'] as String?) ??
            (data['detail'] as String?) ??
            (data['msg'] as String?) ??
            '';

        if (message.isNotEmpty) {
          if (kDebugMode)
            debugPrint('[DioException] Extracted message: $message');
          return message;
        }
      }
      // If response.data is already a String (like HTML error page)
      else if (data is String && data.isNotEmpty) {
        // Don't return HTML error pages
        if (!data.contains('<!DOCTYPE') && !data.contains('<html')) {
          return data;
        }
      }
    }
  } catch (ex) {
    if (kDebugMode)
      debugPrint('[DioException] Error extracting from response.data: $ex');
  }

  // If we got here, response.data didn't have a good message
  // Check e.message, but ignore verbose Dio messages
  if (e.message != null && e.message!.isNotEmpty) {
    final msg = e.message!;

    // If message contains the verbose "This exception was thrown" text, ignore it
    if (msg.contains('This exception was thrown') ||
        msg.contains('status code of')) {
      if (kDebugMode) {
        debugPrint(
          '[DioException] Message is verbose Dio error, returning fallback',
        );
      }
      return fallback;
    }

    // Otherwise, return the message (might be a custom error)
    return msg;
  }

  return fallback;
}

abstract class AppSnackbar {
  static void error(String message) {
    scaffoldMessengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  static void success(String message) {
    scaffoldMessengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  static void warning(String message) {
    scaffoldMessengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 3),
        ),
      );
  }
}
