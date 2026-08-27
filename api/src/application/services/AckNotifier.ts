import type { PrismaClient } from '@prisma/client';
import { logger } from '@shared/logger/logger';
import type { FcmSender } from './FcmSender';

/**
 * Avisa a sala quando o responsável confirma que está a caminho.
 *
 * O "Estou indo" existe para a equipe saber que pode parar de ligar e começar a
 * preparar a criança. Sem este retorno, a confirmação morria no banco: mudava o
 * status do alerta e ninguém na sala ficava sabendo.
 *
 * Vai para quem levantou o alerta e para os professores daquela sala — quem
 * abriu pode já ter saído do turno, e a criança continua lá.
 */
export class AckNotifier {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly fcm: FcmSender,
  ) {}

  async responsavelACaminho(params: {
    alertId: string;
    sessionId: string;
    createdById: string;
    childName: string;
    roomName: string;
    guardianName: string | null;
  }): Promise<void> {
    const destinatarios = await this.destinatarios(params.sessionId, params.createdById);
    if (destinatarios.length === 0) return;

    const titulo = `${params.roomName} · a caminho`;
    const corpo = params.guardianName
      ? `${params.guardianName} confirmou que está indo buscar ${params.childName}.`
      : `O responsável confirmou que está indo buscar ${params.childName}.`;

    // Histórico primeiro: se o push falhar, a sala ainda vê na lista de
    // notificações. É o mesmo princípio do alerta que vai para o responsável.
    let notificationId: string | null = null;
    try {
      const n = await this.prisma.notification.create({
        data: {
          title: titulo,
          body: corpo,
          createdById: params.createdById,
          recipients: { create: destinatarios.map((userId) => ({ userId })) },
        },
        select: { id: true },
      });
      notificationId = n.id;
    } catch (err) {
      logger.error(`[kids] falha ao registrar aviso de retirada: ${String(err)}`);
    }

    if (!this.fcm.isEnabled) return;

    const devices = await this.prisma.deviceToken.findMany({
      where: { userId: { in: destinatarios } },
      select: { token: true },
    });
    if (devices.length === 0) return;

    const { invalidTokens } = await this.fcm.sendToTokens(
      devices.map((d) => d.token),
      {
        title: titulo,
        body: corpo,
        data: {
          type: 'kids_ack',
          alertId: params.alertId,
          sessionId: params.sessionId,
          notificationId: notificationId ?? '',
        },
        // Boa notícia: não precisa de sirene nem de vibração de emergência.
        level: 'INFO',
      },
    );

    if (invalidTokens.length > 0) {
      await this.prisma.deviceToken.deleteMany({
        where: { token: { in: invalidTokens } },
      });
    }
  }

  /** Autor do alerta + professores da sala, sem repetir. */
  private async destinatarios(sessionId: string, createdById: string): Promise<string[]> {
    const sessao = await this.prisma.kidsSession.findUnique({
      where: { id: sessionId },
      select: { room: { select: { teachers: { select: { userId: true } } } } },
    });
    const ids = new Set<string>([createdById]);
    for (const t of sessao?.room.teachers ?? []) ids.add(t.userId);
    return [...ids];
  }
}
