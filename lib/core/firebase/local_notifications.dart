import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/kids/data/kids_models.dart';

/// Exibe notificações enquanto o app está aberto.
///
/// Com o app em segundo plano quem desenha a notificação é o sistema, a partir
/// do bloco `notification` do payload FCM. Em primeiro plano isso não acontece:
/// no Android a mensagem chega direto ao `onMessage` e nada aparece na tela.
/// Este serviço preenche essa lacuna — e é também onde o alerta ganha cara de
/// alerta: imagem, vibração e som mudam conforme a urgência.
class LocalNotifications {
  LocalNotifications._();
  static final LocalNotifications instance = LocalNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Canais versionados de propósito.
  ///
  /// O Android congela importância, vibração e som no momento em que o canal é
  /// criado: alterar o código depois não muda nada em quem já tem o app
  /// instalado, e não existe API para reconfigurar. Trocar o id é a única
  /// forma de aplicar um padrão novo — daí o sufixo. Ao mexer em qualquer um
  /// destes, suba a versão e atualize o mapa em `FcmSender.channelFor`.
  static final _canalAvisos = AndroidNotificationChannel(
    'avisos_v2',
    'Avisos',
    description: 'Comunicados e avisos da igreja.',
    importance: Importance.high,
  );

  /// Vibração longa e dupla: perceptível no bolso sem ser a de emergência.
  static final _canalUrgentes = AndroidNotificationChannel(
    'urgentes_v2',
    'Urgentes',
    description: 'A sala precisa falar com você.',
    importance: Importance.high,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
  );

  /// Emergência: som próprio e vibração longa e insistente. `audioAttributes`
  /// em alarme faz o Android tocar mesmo com o toque no mínimo.
  static final _canalCriticos = AndroidNotificationChannel(
    'alertas_criticos_v2',
    'Alertas críticos',
    description: 'Emergências da salinha infantil.',
    importance: Importance.max,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([
      0, 900, 300, 900, 300, 900, 300, 900,
    ]),
    sound: const RawResourceAndroidNotificationSound('alerta'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
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
      await android?.createNotificationChannel(_canalUrgentes);
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

    final nivel = KidsAlertLevel.fromWire(message.data['level'] as String?);

    try {
      await _plugin.show(
        // Id derivado do messageId: reenvio da mesma mensagem substitui a
        // notificação em vez de empilhar duplicatas.
        message.messageId.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: await _android(nivel, notification.body ?? ''),
          iOS: await _ios(nivel),
        ),
        payload: _encode(message.data),
      );
    } catch (e) {
      debugPrint('LocalNotifications: exibição falhou ($e)');
    }
  }

  AndroidNotificationChannel _canal(KidsAlertLevel nivel) => switch (nivel) {
    KidsAlertLevel.emergency => _canalCriticos,
    KidsAlertLevel.urgent => _canalUrgentes,
    KidsAlertLevel.info => _canalAvisos,
  };

  /// Nome do drawable (em `android/app/src/main/res/drawable`) e do asset
  /// usados como imagem grande. `null` em aviso comum: imagem ali só rouba
  /// espaço da mensagem.
  static String? _arte(KidsAlertLevel nivel) => switch (nivel) {
    KidsAlertLevel.emergency => 'notif_emergencia',
    KidsAlertLevel.urgent => 'notif_urgente',
    KidsAlertLevel.info => null,
  };

  Future<AndroidNotificationDetails> _android(
    KidsAlertLevel nivel,
    String corpo,
  ) async {
    final canal = _canal(nivel);
    final arte = _arte(nivel);

    return AndroidNotificationDetails(
      canal.id,
      canal.name,
      channelDescription: canal.description,
      importance: canal.importance,
      priority: nivel == KidsAlertLevel.info ? Priority.high : Priority.max,
      // Repetidos aqui além do canal: em Android 7 e anteriores não existe
      // canal, e é este bloco que vale.
      enableVibration: true,
      vibrationPattern: canal.vibrationPattern,
      sound: canal.sound,
      color: switch (nivel) {
        KidsAlertLevel.emergency => const Color(0xFFB00020),
        KidsAlertLevel.urgent => const Color(0xFFF9A825),
        KidsAlertLevel.info => null,
      },
      colorized: nivel != KidsAlertLevel.info,
      // Emergência fica na barra até ser tocada: dispensar sem querer é o
      // modo mais fácil de perder o aviso que mais importa.
      ongoing: nivel == KidsAlertLevel.emergency,
      fullScreenIntent: nivel == KidsAlertLevel.emergency,
      category: nivel == KidsAlertLevel.emergency
          ? AndroidNotificationCategory.alarm
          : null,
      styleInformation: arte == null
          // Texto longo não fica cortado numa linha só.
          ? BigTextStyleInformation(corpo)
          : BigPictureStyleInformation(
              DrawableResourceAndroidBitmap(arte),
              largeIcon: DrawableResourceAndroidBitmap(arte),
              summaryText: corpo,
              htmlFormatSummaryText: false,
            ),
    );
  }

  Future<DarwinNotificationDetails> _ios(KidsAlertLevel nivel) async {
    final arte = _arte(nivel);
    // O iOS anexa arquivo, não asset: o bundle precisa virar um arquivo em
    // disco antes de ser referenciado.
    final caminho = arte == null ? null : await _assetEmDisco(arte);

    return DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: nivel == KidsAlertLevel.emergency ? 'alerta.wav' : null,
      interruptionLevel: switch (nivel) {
        KidsAlertLevel.emergency => InterruptionLevel.critical,
        KidsAlertLevel.urgent => InterruptionLevel.timeSensitive,
        KidsAlertLevel.info => InterruptionLevel.active,
      },
      attachments: caminho == null
          ? null
          : [DarwinNotificationAttachment(caminho)],
    );
  }

  /// Copia o PNG do bundle para o diretório temporário, uma vez por execução.
  final _emDisco = <String, String>{};
  Future<String?> _assetEmDisco(String nome) async {
    if (_emDisco.containsKey(nome)) return _emDisco[nome];
    try {
      final bytes = await rootBundle.load('assets/images/$nome.png');
      final dir = await getTemporaryDirectory();
      final arquivo = File('${dir.path}/$nome.png');
      await arquivo.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      _emDisco[nome] = arquivo.path;
      return arquivo.path;
    } catch (e) {
      debugPrint('LocalNotifications: anexo $nome indisponível ($e)');
      return null;
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
