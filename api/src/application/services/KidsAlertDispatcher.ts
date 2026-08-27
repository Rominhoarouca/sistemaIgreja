import type { PrismaClient } from '@prisma/client';
import type { KidsAlert, KidsAlertLevel, KidsChannel, KidsGuardian } from '@domain/entities/Kids';
import type { IKidsRepository, PlannedDelivery } from '@domain/repositories/IKidsRepository';
import { logger } from '@shared/logger/logger';
import type { FcmSender } from './FcmSender';

/**
 * Um canal de entrega de alerta. Falha lançando — quem chama registra o motivo
 * na `KidsAlertDelivery`, que é o rastro de que a igreja tentou avisar.
 */
export interface IAlertChannel {
  readonly channel: KidsChannel;
  send(alert: KidsAlert, guardian: KidsGuardian | null): Promise<string | null>;
}

/**
 * Entrega in-app: grava na caixa de notificações que o app já lê hoje.
 *
 * Funciona sem infra externa e é o histórico que a tela de Notificações lê.
 * O push nativo não substitui isto: `PushAlertChannel` faz os dois.
 */
export class InAppAlertChannel implements IAlertChannel {
  readonly channel: KidsChannel = 'PUSH';

  constructor(private readonly prisma: PrismaClient) {}

  async send(alert: KidsAlert, guardian: KidsGuardian | null): Promise<string | null> {
    const userId = guardian?.userId ?? null;
    if (!userId) throw new Error('Responsável sem conta no app');

    const notification = await this.prisma.notification.create({
      data: {
        title: `${alert.roomName} · ${alert.childName}`,
        // Sem dado de saúde aqui: a mensagem do professor é livre, mas a ficha
        // clínica fica atrás de autenticação, nunca na notificação.
        body: alert.message,
        createdById: alert.createdById,
        recipients: { create: [{ userId }] },
      },
      select: { id: true },
    });
    return notification.id;
  }
}

/**
 * Entrega push: grava o registro in-app **e** dispara o FCM para os aparelhos
 * do responsável.
 *
 * Os dois juntos de propósito. O registro in-app é o histórico que fica na
 * tela de Notificações; o push é o que faz o celular tocar na hora. Um alerta
 * que só existisse como push sumiria da vista assim que o pai dispensasse a
 * notificação.
 */
export class PushAlertChannel implements IAlertChannel {
  readonly channel: KidsChannel = 'PUSH';

  constructor(
    private readonly prisma: PrismaClient,
    private readonly inApp: InAppAlertChannel,
    private readonly fcm: FcmSender,
  ) {}

  async send(alert: KidsAlert, guardian: KidsGuardian | null): Promise<string | null> {
    const userId = guardian?.userId ?? null;
    if (!userId) throw new Error('Responsável sem conta no app');

    // Histórico primeiro: se o push falhar, o aviso ainda existe no app.
    const notificationId = await this.inApp.send(alert, guardian);

    if (!this.fcm.isEnabled) {
      logger.warn('[kids] FCM desativado — alerta entregue só in-app');
      return notificationId;
    }

    const devices = await this.prisma.deviceToken.findMany({
      where: { userId },
      select: { token: true },
    });

    if (devices.length === 0) {
      // Não é falha: o responsável simplesmente não autorizou notificações.
      logger.info(`[kids] responsável ${userId} sem aparelho registrado`);
      return notificationId;
    }

    const { sent, invalidTokens } = await this.fcm.sendToTokens(
      devices.map((d) => d.token),
      {
        title: `${alert.roomName} · ${alert.childName}`,
        body: alert.message,
        data: {
          type: 'kids_alert',
          alertId: alert.id,
          childId: alert.childId,
          level: alert.level,
          notificationId: notificationId ?? '',
        },
        level: alert.level,
      },
    );

    // Token de app desinstalado fica no banco para sempre se ninguém limpar.
    if (invalidTokens.length > 0) {
      await this.prisma.deviceToken.deleteMany({
        where: { token: { in: invalidTokens } },
      });
      logger.info(`[kids] ${invalidTokens.length} token(s) inválido(s) removido(s)`);
    }

    // Havia aparelho e nenhum recebeu: isso é falha de entrega de verdade.
    if (sent === 0) {
      throw new Error('Nenhum aparelho recebeu o push');
    }

    return notificationId;
  }
}

/**
 * WhatsApp via Cloud API. Enquanto as credenciais não existirem, falha com
 * motivo explícito — melhor uma entrega marcada como FAILED e visível do que
 * a ilusão de que a mensagem saiu.
 */
export class WhatsappAlertChannel implements IAlertChannel {
  readonly channel: KidsChannel = 'WHATSAPP';

  async send(alert: KidsAlert, guardian: KidsGuardian | null): Promise<string | null> {
    const token = process.env['WHATSAPP_TOKEN'];
    const phoneNumberId = process.env['WHATSAPP_PHONE_NUMBER_ID'];
    if (!token || !phoneNumberId) {
      throw new Error(
        'WhatsApp Cloud API não configurada (WHATSAPP_TOKEN/WHATSAPP_PHONE_NUMBER_ID)',
      );
    }
    if (!guardian?.phone) throw new Error('Responsável sem telefone');

    const template =
      alert.level === 'EMERGENCY' ? 'kids_emergencia' : 'kids_alerta_urgente';

    const response = await fetch(
      `https://graph.facebook.com/v21.0/${phoneNumberId}/messages`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          to: guardian.phone.replace(/\D/g, ''),
          type: 'template',
          template: {
            name: template,
            language: { code: 'pt_BR' },
            components: [
              {
                type: 'body',
                parameters: [
                  { type: 'text', text: alert.roomName },
                  { type: 'text', text: alert.childName },
                  { type: 'text', text: alert.message },
                ],
              },
            ],
          },
        }),
      },
    );

    if (!response.ok) {
      const detail = await response.text();
      throw new Error(`WhatsApp respondeu ${response.status}: ${detail.slice(0, 200)}`);
    }
    const json = (await response.json()) as { messages?: { id: string }[] };
    return json.messages?.[0]?.id ?? null;
  }
}

/**
 * Ligação telefônica. Não envia nada: quem liga é o professor, pelo aparelho.
 * A entrega fica `QUEUED` até ele confirmar a discagem — o registro é do ato
 * humano, não de uma automação.
 */
export class ManualCallChannel implements IAlertChannel {
  readonly channel: KidsChannel = 'CALL';

  async send(): Promise<string | null> {
    throw new Error('PENDING_MANUAL_CALL');
  }
}

/**
 * Decide os canais de cada alerta e dispara as entregas.
 *
 * Escalonamento (§7.5 da doc): quanto mais grave, mais caminhos em paralelo.
 * Nível 3 nunca depende de um canal só.
 */
export class KidsAlertDispatcher {
  constructor(
    private readonly kidsRepo: IKidsRepository,
    private readonly channels: IAlertChannel[],
  ) {}

  /** Canais que o alerta deve usar, dado o nível e quem é o responsável. */
  plan(level: KidsAlertLevel, guardians: KidsGuardian[]): PlannedDelivery[] {
    const planned: PlannedDelivery[] = [];

    for (const guardian of guardians) {
      const hasApp = guardian.userId !== null;
      const hasWhatsapp = guardian.hasWhatsapp && guardian.phone.length > 0;

      if (level === 'INFO') {
        // Um canal só: aviso corriqueiro não justifica acordar dois.
        if (hasApp) planned.push({ channel: 'PUSH', guardianId: guardian.id, userId: guardian.userId });
        else if (hasWhatsapp)
          planned.push({ channel: 'WHATSAPP', guardianId: guardian.id, userId: null });
        continue;
      }

      // URGENT e EMERGENCY: os dois canais sempre, em paralelo.
      if (hasApp) {
        planned.push({
          channel: level === 'EMERGENCY' ? 'CRITICAL_PUSH' : 'PUSH',
          guardianId: guardian.id,
          userId: guardian.userId,
        });
      }
      if (hasWhatsapp) {
        planned.push({ channel: 'WHATSAPP', guardianId: guardian.id, userId: null });
      }
      if (level === 'EMERGENCY' && guardian.phone) {
        planned.push({ channel: 'CALL', guardianId: guardian.id, userId: null });
      }
    }

    return planned;
  }

  /**
   * Dispara as entregas pendentes do alerta. Nunca lança: uma falha de canal
   * vira `FAILED` com o erro registrado — derrubar a requisição faria o
   * professor achar que o alerta não foi criado, quando foi.
   */
  async dispatch(alert: KidsAlert, guardians: KidsGuardian[]): Promise<void> {
    const byId = new Map(guardians.map((g) => [g.id, g]));

    await Promise.all(
      alert.deliveries
        .filter((d) => d.status === 'QUEUED')
        .map(async (delivery) => {
          const channel = this.channels.find((c) => this.matches(c, delivery.channel));
          if (!channel) {
            await this.kidsRepo.markDeliveryFailed(
              delivery.id,
              `Canal ${delivery.channel} sem implementação`,
            );
            return;
          }

          const guardian = delivery.guardianId ? byId.get(delivery.guardianId) ?? null : null;

          try {
            const providerId = await channel.send(alert, guardian);
            await this.kidsRepo.markDeliverySent(delivery.id, providerId);
          } catch (err) {
            const message = err instanceof Error ? err.message : String(err);
            // A ligação fica pendente por desenho: espera o professor discar.
            if (message === 'PENDING_MANUAL_CALL') return;
            logger.warn(
              `[kids] entrega ${delivery.channel} falhou para alerta ${alert.id}: ${message}`,
            );
            await this.kidsRepo.markDeliveryFailed(delivery.id, message);
          }
        }),
    );
  }

  private matches(channel: IAlertChannel, wanted: KidsChannel): boolean {
    // CRITICAL_PUSH usa o mesmo canal PUSH; a diferença vai no payload
    // (prioridade e interruption-level), decidida pelo nível do alerta.
    if (wanted === 'CRITICAL_PUSH') return channel.channel === 'PUSH';
    return channel.channel === wanted;
  }
}
