/// Exceção de domínio que encapsula erros da camada de dados,
/// desacoplando a UI de DioException.
class ServiceException implements Exception {
  const ServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
