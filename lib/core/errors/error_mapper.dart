import 'package:dio/dio.dart';

import 'failures.dart';

/// Único ponto de conversão de erros de transporte em [Failure] de domínio.
///
/// Regra da arquitetura: datasources deixam `DioException` propagar cru;
/// apenas RepositoryImpl chama `ErrorMapper.map` dentro do catch. A UI nunca
/// vê `DioException` — consome `failure.message` (já em pt-BR).
abstract class ErrorMapper {
  static Failure map(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final message = _extractMessage(error);

      switch (statusCode) {
        case 401:
          return AuthFailure(message ?? 'Sessão expirada. Faça login novamente.');
        case 403:
          return PermissionFailure(
            message ?? 'Você não tem permissão para esta ação.',
          );
        case 404:
          return NotFoundFailure(message ?? 'Recurso não encontrado.');
        case 409:
        case 422:
          return ValidationFailure(message ?? 'Dados inválidos.');
      }
      if (statusCode != null && statusCode >= 500) {
        return const ServerFailure();
      }
      if (statusCode == null) {
        // Sem resposta HTTP: timeout/conexão recusada/DNS.
        return const NetworkFailure();
      }
      return ServerFailure(message ?? 'Erro no servidor. Tente novamente.');
    }

    final text = error.toString();
    if (text.contains('SocketException') || text.contains('HandshakeException')) {
      return const NetworkFailure();
    }
    return const ServerFailure();
  }

  /// Extrai a mensagem amigável do corpo de erro da API.
  ///
  /// Formatos aceitos (nesta ordem): `{error: {message}}`, `message`,
  /// `detail`, `msg`, corpo string puro. Ignora páginas HTML e as mensagens
  /// verbosas padrão do Dio ("This exception was thrown...").
  static String? _extractMessage(DioException e) {
    final data = e.response?.data;

    if (data is Map<String, dynamic>) {
      final nested = data['error'];
      if (nested is Map<String, dynamic>) {
        final message = nested['message'];
        if (message is String && message.isNotEmpty) return message;
      }
      for (final key in const ['message', 'detail', 'msg']) {
        final message = data[key];
        if (message is String && message.isNotEmpty) return message;
      }
    } else if (data is String && data.isNotEmpty) {
      if (!data.contains('<!DOCTYPE') && !data.contains('<html')) {
        return data;
      }
    }

    final raw = e.message;
    if (raw != null &&
        raw.isNotEmpty &&
        !raw.contains('This exception was thrown') &&
        !raw.contains('status code of')) {
      return raw;
    }
    return null;
  }
}
