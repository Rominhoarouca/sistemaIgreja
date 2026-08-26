import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Exibe notificações enquanto o app está aberto.
///
/// Com o app em segundo plano quem desenha a notificação é o sistema, a partir
/// do bloco `notification` do payload FCM. Em primeiro plano isso não acontece:
/// no Android a mensagem chega direto ao `onMessage` e nada aparece na tela.
/// Este serviço preenche essa lacuna.
class LocalNotifications {
  LocalNotifications._();
  static final LocalNotifications instance = LocalNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Precisam casar com os `channelId` que a API manda no payload
  /// (`FcmSender.sendToTokens`): canal inexistente no aparelho faz o Android
  /// cair no padrão e ignorar a importância que pedimos.
  static const _canalAvisos = AndroidNotificationChannel(
    'avisos',
    'Avisos',
    description: 'Comunicados e avisos da igreja.',
    importance: Importance.high,
  );

  static const _canalCriticos = AndroidNotificationChannel(
    'alertas_criticos',
    'Alertas críticos',
    description: 'Emergências da salinha infantil.',
    importance: Importance.max,
  );

  /// Chamado quando o usuário toca numa notificação exibida por nós.
  void Function(Map<String, dynamic> data)? onTap;

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // As permissões já foram pedidas pelo firebase_messaging; pedir de novo
        // aqui abriria um segundo diálogo.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || onTap == null) return;
          onTap!(_decode(payload));
        },
      );

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(_canalAvisos);
      await android?.createNotificationChannel(_canalCriticos);

      _ready = true;
    } catch (e) {
      debugPrint('LocalNotifications: init falhou ($e)');
    }
  }

  /// Mostra uma mensagem FCM recebida com o app aberto.
  Future<void> showFromMessage(RemoteMessage message) async {
    if (!_ready) return;

    final notification = message.notification;
    // Sem bloco `notification` é push silencioso (só dados): nada a exibir.
    if (notification == null) return;

    final critical = message.data['level'] == 'EMERGENCY';

    try {
      await _plugin.show(
        // Id derivado do messageId: reenvio da mesma mensagem substitui a
        // notificação em vez de empilhar duplicatas.
        message.messageId.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            critical ? _canalCriticos.id : _canalAvisos.id,
            critical ? _canalCriticos.name : _canalAvisos.name,
            channelDescription: critical
                ? _canalCriticos.description
                : _canalAvisos.description,
            importance: critical ? Importance.max : Importance.high,
            priority: critical ? Priority.max : Priority.high,
            // Texto longo não fica cortado numa linha só.
            styleInformation: BigTextStyleInformation(notification.body ?? ''),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: critical
                ? InterruptionLevel.timeSensitive
                : InterruptionLevel.active,
          ),
        ),
        payload: _encode(message.data),
      );
    } catch (e) {
      debugPrint('LocalNotifications: exibição falhou ($e)');
    }
  }

  // O payload do plugin é uma string só; os dados do FCM são sempre
  // `Map<String, String>`, então este par simples basta.
  static String _encode(Map<String, dynamic> data) =>
      data.entries.map((e) => '${e.key}=${e.value}').join('');

  static Map<String, dynamic> _decode(String raw) {
    final out = <String, dynamic>{};
    for (final part in raw.split('')) {
      final i = part.indexOf('=');
      if (i > 0) out[part.substring(0, i)] = part.substring(i + 1);
    }
    return out;
  }
}
