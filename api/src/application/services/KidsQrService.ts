import { randomUUID } from 'crypto';
import jwt from 'jsonwebtoken';
import type { PrismaClient } from '@prisma/client';
import { AppError } from '@shared/errors/AppError';

/** Conteúdo do QR do responsável. Curto de propósito: cabe num código denso. */
interface KidsQrPayload {
  /** userId do responsável. */
  sub: string;
  /** churchId — o professor de outra igreja não pode ler este QR. */
  chr: string | null;
  /** Identificador do uso; consumido uma vez só. */
  jti: string;
  iat: number;
  exp: number;
}

export interface ResolvedQr {
  readonly guardianUserId: string;
  readonly churchId: string | null;
  readonly jti: string;
}

/**
 * QR de identificação do responsável.
 *
 * O token é gerado **no servidor** (a chave não sai daqui) e vale 60 s: um
 * print do código vira inútil quase imediatamente, o que é o ponto — sem TTL
 * curto, a foto do QR viraria uma chave permanente da criança.
 *
 * Cada `jti` só pode ser consumido uma vez (tabela `kids_qr_nonces`). Sem isso,
 * dentro da janela de validade o mesmo código abriria a porta duas vezes.
 */
export class KidsQrService {
  /** Curto o bastante para um print não servir; longo para dar tempo de ler. */
  private readonly ttlSeconds = 60;

  constructor(private readonly prisma: PrismaClient) {}

  private get secret(): string {
    const secret = process.env['JWT_SECRET'];
    if (!secret) throw AppError.internal('Configuração JWT ausente');
    return secret;
  }

  issue(userId: string, churchId: string | null): { token: string; expiresIn: number } {
    const token = jwt.sign(
      { sub: userId, chr: churchId, jti: randomUUID() },
      this.secret,
      { expiresIn: this.ttlSeconds },
    );
    return { token, expiresIn: this.ttlSeconds };
  }

  /**
   * Valida assinatura, validade, tenant e replay. Consome o `jti` — chamar duas
   * vezes com o mesmo token falha na segunda.
   */
  async consume(token: string, readerChurchId: string | null): Promise<ResolvedQr> {
    let payload: KidsQrPayload;
    try {
      payload = jwt.verify(token, this.secret) as KidsQrPayload;
    } catch (err) {
      const expired = err instanceof jwt.TokenExpiredError;
      throw new AppError(
        expired ? 'QR Code expirado. Peça para gerar de novo.' : 'QR Code inválido',
        401,
        expired ? 'KIDS_QR_EXPIRED' : 'KIDS_QR_INVALID',
      );
    }

    if (readerChurchId !== null && payload.chr !== readerChurchId) {
      throw new AppError('QR Code de outra igreja', 403, 'KIDS_QR_WRONG_TENANT');
    }

    const expiresAt = new Date(payload.exp * 1000);
    try {
      await this.prisma.kidsQrNonce.create({
        data: { jti: payload.jti, userId: payload.sub, expiresAt },
      });
    } catch {
      // Chave primária duplicada = o mesmo QR já foi lido.
      throw new AppError('QR Code já utilizado', 409, 'KIDS_QR_REPLAY');
    }

    return { guardianUserId: payload.sub, churchId: payload.chr, jti: payload.jti };
  }

  /** Limpa nonces vencidos — chamado pelo job noturno. */
  async purgeExpired(): Promise<number> {
    const { count } = await this.prisma.kidsQrNonce.deleteMany({
      where: { expiresAt: { lt: new Date() } },
    });
    return count;
  }
}
