import { randomInt } from 'crypto';
import bcrypt from 'bcryptjs';

/**
 * Senha de retirada de 5 dígitos, para o responsável que não usa o app.
 *
 * Cinco dígitos são 100 mil combinações — fraco contra força bruta, e é uma
 * escolha de produto: o código precisa ser ditável no balcão e caber numa
 * etiqueta. O que sustenta a segurança é o resto: hash no banco, escopo de um
 * único check-in, e bloqueio depois de poucas tentativas ([maxAttempts]).
 */
export class PickupCodeService {
  /** Erros consecutivos antes de travar a retirada por código. */
  readonly maxAttempts = 5;
  private readonly lockMinutes = 15;
  private readonly rounds = 10;

  generate(): string {
    // randomInt (CSPRNG), não Math.random: código previsível abriria a porta.
    return randomInt(0, 100_000).toString().padStart(5, '0');
  }

  async hash(code: string): Promise<string> {
    return bcrypt.hash(code, this.rounds);
  }

  async verify(code: string, hash: string): Promise<boolean> {
    return bcrypt.compare(code, hash);
  }

  /** Últimos 2 dígitos — conferência visual sem expor a senha inteira. */
  last2(code: string): string {
    return code.slice(-2);
  }

  lockUntil(attempts: number): Date | null {
    if (attempts + 1 < this.maxAttempts) return null;
    return new Date(Date.now() + this.lockMinutes * 60 * 1000);
  }

  /** Avisa o ADMIN a partir da 3ª tentativa: pode ser tentativa de retirada indevida. */
  shouldWarnAdmin(attempts: number): boolean {
    return attempts + 1 >= 3;
  }
}
