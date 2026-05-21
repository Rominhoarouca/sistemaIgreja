import 'package:equatable/equatable.dart';

/// Base class for all domain failures
abstract class Failure extends Equatable {
  const Failure([this.message = 'Ocorreu um erro inesperado']);
  final String message;

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Erro no servidor. Tente novamente.']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sem conexão com a internet.']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Erro ao acessar dados locais.']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Sessão expirada. Faça login novamente.']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Recurso não encontrado.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Dados inválidos.']);
}

class PermissionFailure extends Failure {
  const PermissionFailure([
    super.message = 'Você não tem permissão para esta ação.',
  ]);
}
