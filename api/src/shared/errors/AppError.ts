export class AppError extends Error {
  public readonly statusCode: number;
  public readonly code: string;
  /**
   * Contexto estruturado que o cliente precisa para agir sobre o erro — por
   * exemplo, a lista de crianças que impede o fechamento de uma sala. Só use
   * para dado que a tela realmente exibe.
   */
  public details?: Record<string, unknown>;

  constructor(message: string, statusCode = 400, code = 'BAD_REQUEST') {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.name = 'AppError';
    Object.setPrototypeOf(this, new.target.prototype);
  }

  withDetails(details: Record<string, unknown>): AppError {
    this.details = details;
    return this;
  }

  static unauthorized(message = 'Não autorizado'): AppError {
    return new AppError(message, 401, 'UNAUTHORIZED');
  }

  static forbidden(message = 'Acesso negado'): AppError {
    return new AppError(message, 403, 'FORBIDDEN');
  }

  static notFound(message = 'Recurso não encontrado'): AppError {
    return new AppError(message, 404, 'NOT_FOUND');
  }

  static conflict(message: string): AppError {
    return new AppError(message, 409, 'CONFLICT');
  }

  static internal(message = 'Erro interno'): AppError {
    return new AppError(message, 500, 'INTERNAL_ERROR');
  }
}
