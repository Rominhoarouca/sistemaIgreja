import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_igreja/core/errors/error_mapper.dart';
import 'package:sistema_igreja/core/errors/failures.dart';

DioException _dioError({int? status, Object? data, String? message}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    message: message,
    response: status == null
        ? null
        : Response(requestOptions: options, statusCode: status, data: data),
  );
}

void main() {
  group('ErrorMapper.map — status → Failure', () {
    const table = <int, Type>{
      401: AuthFailure,
      403: PermissionFailure,
      404: NotFoundFailure,
      409: ValidationFailure,
      422: ValidationFailure,
      500: ServerFailure,
      503: ServerFailure,
    };

    for (final entry in table.entries) {
      test('${entry.key} → ${entry.value}', () {
        final failure = ErrorMapper.map(_dioError(status: entry.key));
        expect(failure.runtimeType, entry.value);
      });
    }

    test('sem resposta HTTP → NetworkFailure', () {
      expect(ErrorMapper.map(_dioError()), isA<NetworkFailure>());
    });

    test('status inesperado (418) → ServerFailure', () {
      expect(ErrorMapper.map(_dioError(status: 418)), isA<ServerFailure>());
    });

    test('SocketException fora do Dio → NetworkFailure', () {
      expect(
        ErrorMapper.map(Exception('SocketException: connection refused')),
        isA<NetworkFailure>(),
      );
    });

    test('erro desconhecido → ServerFailure', () {
      expect(ErrorMapper.map(StateError('boom')), isA<ServerFailure>());
    });
  });

  group('ErrorMapper.map — extração de mensagem', () {
    test('usa error.message aninhado (formato da API)', () {
      final failure = ErrorMapper.map(_dioError(
        status: 409,
        data: {
          'error': {'message': 'E-mail já cadastrado'},
        },
      ));
      expect(failure.message, 'E-mail já cadastrado');
    });

    test('usa message direto', () {
      final failure = ErrorMapper.map(
        _dioError(status: 404, data: {'message': 'Célula não encontrada'}),
      );
      expect(failure.message, 'Célula não encontrada');
    });

    test('aceita detail e msg como fallback', () {
      expect(
        ErrorMapper.map(_dioError(status: 409, data: {'detail': 'a'})).message,
        'a',
      );
      expect(
        ErrorMapper.map(_dioError(status: 409, data: {'msg': 'b'})).message,
        'b',
      );
    });

    test('ignora corpo HTML e cai no padrão da Failure', () {
      final failure = ErrorMapper.map(
        _dioError(status: 404, data: '<!DOCTYPE html><html>...</html>'),
      );
      expect(failure.message, 'Recurso não encontrado.');
    });

    test('ignora mensagem verbosa do Dio', () {
      final failure = ErrorMapper.map(_dioError(
        status: 403,
        message: 'This exception was thrown because the response has...',
      ));
      expect(failure.message, 'Você não tem permissão para esta ação.');
    });

    test('500 nunca vaza corpo — mensagem genérica', () {
      final failure = ErrorMapper.map(
        _dioError(status: 500, data: {'message': 'stack trace interno'}),
      );
      expect(failure.message, 'Erro no servidor. Tente novamente.');
    });
  });
}
