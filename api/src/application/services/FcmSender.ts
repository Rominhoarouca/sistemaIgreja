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

  /**
   * Canal do Android por nível de urgência.
   *
   * O sufixo `_v2` não é decorativo: o Android congela vibração, som e
   * importância quando o canal é criado, e mudar isso depois exige um id novo.
   * Estes valores precisam bater exatamente com os de
   * `lib/core/firebase/local_notifications.dart` — um id que o app não criou
   * faz o sistema cair no canal padrão e descartar a urgência que pedimos.
   */
  /**
   * URL pública da arte do alerta, ou `null` quando não há o que mostrar.
   *
   * Com o app aberto quem desenha a notificação é o próprio app, e ele usa o
   * PNG do bundle. Fechado, quem desenha é o sistema, que só conhece o que vem
   * no payload — e só aceita URL http(s), não asset. Por isso a mesma imagem
   * existe nos dois lugares. Sem `PUBLIC_BASE_URL` a notificação continua
   * chegando, apenas sem a arte.
   */
  static artFor(level: 'INFO' | 'URGENT' | 'EMERGENCY'): string | null {
    if (level === 'INFO') return null;
    const base = process.env['PUBLIC_BASE_URL'];
    if (!base) return null;
    const arquivo = level === 'EMERGENCY' ? 'notif_emergencia' : 'notif_urgente';
    return `${base.replace(/\/$/, '')}/v1/public/notificacoes/${arquivo}.png`;
  }

  static channelFor(level: 'INFO' | 'URGENT' | 'EMERGENCY'): string {
    switch (level) {
      case 'EMERGENCY':
        return 'alertas_criticos_v2';
      case 'URGENT':
        return 'urgentes_v2';
      default:
        return 'avisos_v2';
    }
  }

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
      /** Define canal, vibração e som no Android. Default: aviso comum. */
      level?: 'INFO' | 'URGENT' | 'EMERGENCY';
    },
  ): Promise<{ sent: number; invalidTokens: string[] }> {
    this.ensureInit();
    if (!this.app || tokens.length === 0) return { sent: 0, invalidTokens: [] };

    const messaging = getMessaging(this.app);

    // `critical` continua aceito para quem chama sem informar o nível.
    const nivel = payload.level ?? (payload.critical ? 'EMERGENCY' : 'INFO');
    const arte = FcmSender.artFor(nivel);

    const results = await Promise.allSettled(
      tokens.map((token) => {
        const message: Message = {
          token,
          notification: { title: payload.title, body: payload.body },
          data: payload.data ?? {},
          android: {
            priority: 'high',
            notification: {
              channelId: FcmSender.channelFor(nivel),
              // Emergência ignora o modo silencioso do canal padrão.
              priority: nivel === 'INFO' ? 'default' : 'max',
              ...(arte ? { imageUrl: arte } : {}),
            },
          },
          apns: {
            headers: {
              'apns-priority': '10',
              // Time-sensitive fura o Resumo de Notificações e o Foco.
              ...(nivel !== 'INFO' ? { 'apns-push-type': 'alert' } : {}),
            },
            payload: {
              aps: {
                // Som próprio só na emergência; o arquivo vem no bundle do app.
                sound: nivel === 'EMERGENCY' ? 'alerta.wav' : 'default',
                ...(nivel === 'EMERGENCY'
                  ? { 'interruption-level': 'time-sensitive' }
                  : {}),
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
