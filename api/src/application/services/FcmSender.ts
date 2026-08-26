import { cert, getApps, initializeApp, type App } from 'firebase-admin/app';
import { getMessaging, type Message } from 'firebase-admin/messaging';
import fs from 'node:fs';
import { logger } from '@shared/logger/logger';

/**
 * Envio de push pelo FCM (HTTP v1).
 *
 * A credencial vem de `FIREBASE_SERVICE_ACCOUNT`, que aceita o caminho de um
 * arquivo JSON ou o próprio JSON inline (útil em container). Sem ela o
 * remetente fica inativo: `isEnabled` responde `false` e nada é enviado — o
 * app não deixa de funcionar por falta de push.
 *
 * A API legada de FCM (server key) foi desligada pelo Google em 2024; a v1
 * exige OAuth2, e é por isso que o segredo aqui é uma service account e não
 * uma chave simples.
 */
export class FcmSender {
  private app: App | null = null;
  private initialized = false;

  get isEnabled(): boolean {
    this.ensureInit();
    return this.app !== null;
  }

  private ensureInit(): void {
    if (this.initialized) return;
    this.initialized = true;

    const raw = process.env['FIREBASE_SERVICE_ACCOUNT'];
    if (!raw) {
      logger.warn('[fcm] FIREBASE_SERVICE_ACCOUNT ausente — push desativado');
      return;
    }

    try {
      const json = raw.trim().startsWith('{')
        ? raw
        : fs.readFileSync(raw, 'utf8');
      const credentials = JSON.parse(json) as {
        project_id?: string;
        client_email?: string;
        private_key?: string;
      };

      if (!credentials.project_id || !credentials.client_email || !credentials.private_key) {
        logger.error('[fcm] service account incompleta — push desativado');
        return;
      }

      // Nome próprio: o app default pode já existir se outro módulo inicializar.
      const existing = getApps().find((a) => a.name === 'fcm');
      this.app =
        existing ??
        initializeApp(
          {
            credential: cert({
              projectId: credentials.project_id,
              clientEmail: credentials.client_email,
              // Em .env a chave vem com \n escapado.
              privateKey: credentials.private_key.replace(/\\n/g, '\n'),
            }),
          },
          'fcm',
        );
      logger.info(`[fcm] pronto (projeto ${credentials.project_id})`);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      logger.error(`[fcm] falha ao carregar credencial: ${msg}`);
      this.app = null;
    }
  }

  /**
   * Envia para vários tokens. Devolve os que o FCM rejeitou como inválidos,
   * para que quem chamou possa removê-los — token de app desinstalado fica
   * para sempre no banco se ninguém limpar.
   */
  async sendToTokens(
    tokens: string[],
    payload: {
      title: string;
      body: string;
      data?: Record<string, string>;
      critical?: boolean;
    },
  ): Promise<{ sent: number; invalidTokens: string[] }> {
    this.ensureInit();
    if (!this.app || tokens.length === 0) return { sent: 0, invalidTokens: [] };

    const messaging = getMessaging(this.app);

    const results = await Promise.allSettled(
      tokens.map((token) => {
        const message: Message = {
          token,
          notification: { title: payload.title, body: payload.body },
          data: payload.data ?? {},
          android: {
            priority: 'high',
            notification: {
              channelId: payload.critical ? 'alertas_criticos' : 'avisos',
              // Emergência ignora o modo silencioso do canal padrão.
              priority: payload.critical ? 'max' : 'default',
            },
          },
          apns: {
            headers: {
              'apns-priority': '10',
              // Time-sensitive fura o Resumo de Notificações e o Foco.
              ...(payload.critical ? { 'apns-push-type': 'alert' } : {}),
            },
            payload: {
              aps: {
                sound: 'default',
                ...(payload.critical ? { 'interruption-level': 'time-sensitive' } : {}),
              },
            },
          },
        };
        return messaging.send(message);
      }),
    );

    const invalidTokens: string[] = [];
    let sent = 0;

    results.forEach((r, i) => {
      if (r.status === 'fulfilled') {
        sent += 1;
        return;
      }
      const code = (r.reason as { code?: string } | undefined)?.code ?? '';
      // Só estes dois significam "token morto"; erro de rede não deve apagar
      // o registro de um aparelho que ainda existe.
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
      ) {
        invalidTokens.push(tokens[i]!);
      } else {
        const msg = r.reason instanceof Error ? r.reason.message : String(r.reason);
        logger.warn(`[fcm] envio falhou: ${msg}`);
      }
    });

    return { sent, invalidTokens };
  }
}
