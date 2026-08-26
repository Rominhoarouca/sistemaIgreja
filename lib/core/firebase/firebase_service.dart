import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import 'local_notifications.dart';

/// Handler de mensagem em segundo plano.
///
/// Precisa ser função de topo (não método, não closure): o Flutter cria um
/// isolate novo para executá-la e só consegue referenciar um ponto de entrada
/// global. Por nascer em isolate separado, o Firebase é inicializado de novo
/// aqui dentro.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('FCM background: ${message.messageId}');
}

/// Ponto único de inicialização do Firebase.
///
/// Tudo aqui é best-effort: uma falha de rede ou de configuração do Firebase
/// não pode impedir o app de abrir. O que der errado vira log e segue.
class FirebaseService {
  FirebaseService._();

  /// Chave pública do par VAPID (Console → Cloud Messaging → Certificados push
  /// da Web). Obrigatória para emitir token na web; ignorada em iOS/Android,
  /// que usam APNs e FCM nativos. É a metade pública do par — pode ficar no
  /// código do cliente, é o que o navegador envia ao serviço de push.
  static const _webVapidKey =
      'BLgrrnVIpExKJ7tyTZpaTX7TdW4hZKzBiJh6RScrX1WwJjqv7VTvls3jBS63e_OZxW1-V_cIkHVPTNoXaQI24qo';

  static final FirebaseService instance = FirebaseService._();

  bool _ready = false;
  bool get isReady => _ready;

  FirebaseAnalytics? _analytics;
  FirebaseAnalytics? get analytics => _analytics;

  /// Observer para registrar navegação automaticamente no Analytics.
  FirebaseAnalyticsObserver? get navigatorObserver =>
      _analytics == null ? null : FirebaseAnalyticsObserver(analytics: _analytics!);

  /// Token FCM do aparelho. `null` enquanto não houver permissão ou registro.
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Dio autenticado, injetado depois do DI subir. Sem ele o token não tem
  /// como chegar ao backend.
  Dio? _dio;
  /// Só guarda a referência: registrar aqui daria 401, porque no boot ainda
  /// não há sessão. Quem dispara o registro é o listener de autenticação.
  set dio(Dio value) => _dio = value;

  /// Busca o token e registra o aparelho quando a permissão já existe.
  ///
  /// O token do FCM pode mudar entre execuções, e o backend precisa do valor
  /// atual — por isso roda a cada inicialização, não só na primeira.
  Future<void> syncTokenIfAuthorized() async {
    if (!_ready) return;
    try {
      final status = await pushStatus();
      if (status != AuthorizationStatus.authorized &&
          status != AuthorizationStatus.provisional) {
        return;
      }
      final messaging = FirebaseMessaging.instance;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        // Permissão concedida não significa registrado no APNs: são estados
        // separados no iOS. Quem chama `registerForRemoteNotifications` é o
        // `requestPermission` do plugin, então pular esta chamada por já estar
        // autorizado deixa o app para sempre sem token APNs — e sem push.
        // Com a permissão já concedida o iOS não abre diálogo nenhum aqui.
        await messaging.requestPermission(alert: true, badge: true, sound: true);
        if (await _awaitApnsToken(messaging) == null) {
          debugPrint('FCM: APNs não registrou — token adiado');
          return;
        }
      }
      _fcmToken = await messaging.getToken(
        vapidKey: kIsWeb ? _webVapidKey : null,
      );
      await registerDevice();
    } catch (e) {
      debugPrint('FCM: sync de token falhou ($e)');
    }
  }

  /// Envia o token para a API. Idempotente por token — pode ser chamado a cada
  /// boot e a cada refresh.
  Future<void> registerDevice() async {
    final dio = _dio;
    final token = _fcmToken;
    if (dio == null || token == null) return;
    try {
      await dio.post('/devices', data: {
        'token': token,
        'platform': kIsWeb
            ? 'web'
            : defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      });
      debugPrint('FCM: aparelho registrado na API');
    } catch (e) {
      // Sem push o app segue funcionando; não vale derrubar nada por isso.
      debugPrint('FCM: registro do aparelho falhou ($e)');
    }
  }

  /// Baixa o aparelho no logout, senão o push continua chegando para quem
  /// entrar depois neste mesmo celular.
  Future<void> unregisterDevice() async {
    final dio = _dio;
    final token = _fcmToken;
    if (dio == null || token == null) return;
    try {
      await dio.delete('/devices', data: {'token': token});
    } catch (e) {
      debugPrint('FCM: baixa do aparelho falhou ($e)');
    }
  }

  /// Mensagens recebidas com o app em primeiro plano.
  final _foreground = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onForegroundMessage => _foreground.stream;

  /// Mensagem que abriu o app (toque na notificação).
  final _opened = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onMessageOpened => _opened.stream;

  Future<void> init() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _ready = true;
    } catch (e, st) {
      debugPrint('Firebase: initializeApp falhou ($e)');
      debugPrintStack(stackTrace: st);
      return; // sem app inicializado não há o que configurar
    }

    await _setupCrashlytics();
    await _setupAnalytics();
    // Só os listeners: nada aqui abre diálogo nem espera pelo usuário.
    await _attachMessagingListeners();
  }

  // ── Crashlytics ───────────────────────────────────────────────────────────

  Future<void> _setupCrashlytics() async {
    // Web não tem Crashlytics.
    if (kIsWeb) return;
    try {
      final crashlytics = FirebaseCrashlytics.instance;

      // Em debug não faz sentido poluir o painel com crashes de
      // desenvolvimento; o registro fica só para builds de release.
      await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

      // Erros do framework Flutter. `presentError` continua sendo chamado em
      // `main.dart`, então a tarja vermelha de layout não deixa de aparecer.
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        previousOnError?.call(details);
        crashlytics.recordFlutterError(details);
      };

      // Erros assíncronos que escapam de qualquer zone.
      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e) {
      debugPrint('Firebase: Crashlytics falhou ($e)');
    }
  }

  /// Registra quem está usando o app — aparece no relatório de crash e ajuda a
  /// distinguir "quebra para todo mundo" de "quebra para um perfil".
  Future<void> setUser({
    required String userId,
    String? role,
    String? churchId,
  }) async {
    if (kIsWeb || !_ready) return;
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId);
      if (role != null) {
        await FirebaseCrashlytics.instance.setCustomKey('role', role);
        await _analytics?.setUserProperty(name: 'role', value: role);
      }
      if (churchId != null) {
        await FirebaseCrashlytics.instance.setCustomKey('church_id', churchId);
      }
      await _analytics?.setUserId(id: userId);
    } catch (e) {
      debugPrint('Firebase: setUser falhou ($e)');
    }
  }

  Future<void> clearUser() async {
    if (!_ready) return;
    try {
      await _analytics?.setUserId(id: null);
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.setUserIdentifier('');
      }
    } catch (_) {}
  }

  // ── Analytics ─────────────────────────────────────────────────────────────

  Future<void> _setupAnalytics() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      await _analytics!.setAnalyticsCollectionEnabled(!kDebugMode);
    } catch (e) {
      debugPrint('Firebase: Analytics falhou ($e)');
      _analytics = null;
    }
  }

  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    try {
      await _analytics?.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('Firebase: logEvent($name) falhou ($e)');
    }
  }

  // ── Push (FCM) ────────────────────────────────────────────────────────────

  /// Listeners de mensagem. Não pede permissão e não busca token — nada aqui
  /// depende de resposta do usuário, então pode rodar no boot.
  Future<void> _attachMessagingListeners() async {
    try {
      final messaging = FirebaseMessaging.instance;

      messaging.onTokenRefresh.listen((t) {
        _fcmToken = t;
        unawaited(registerDevice());
      });

      // Em primeiro plano o sistema não desenha nada: quem exibe somos nós.
      await LocalNotifications.instance.init();
      LocalNotifications.instance.onTap = (data) {
        // Toque numa notificação nossa entra pelo mesmo caminho do toque numa
        // notificação do sistema — quem escuta não precisa distinguir.
        _opened.add(RemoteMessage(data: data.map((k, v) => MapEntry(k, '$v'))));
      };

      FirebaseMessaging.onMessage.listen((m) {
        debugPrint('FCM foreground: ${m.notification?.title}');
        unawaited(LocalNotifications.instance.showFromMessage(m));
        _foreground.add(m);
      });
      FirebaseMessaging.onMessageOpenedApp.listen(_opened.add);

      // App aberto a partir de uma notificação estando encerrado.
      //
      // Sem `await` de propósito: no simulador iOS (e em qualquer aparelho sem
      // token APNs) esta chamada nunca completa, e aguardá-la trava o boot até
      // o timeout. O resultado só importa para o deep-link do toque, que pode
      // chegar alguns instantes depois.
      unawaited(
        messaging
            .getInitialMessage()
            .timeout(const Duration(seconds: 5))
            .then((initial) {
              if (initial != null) _opened.add(initial);
            })
            .catchError((Object e) {
              debugPrint('FCM: getInitialMessage indisponível ($e)');
              return null;
            }),
      );
    } catch (e) {
      debugPrint('Firebase: listeners de messaging falharam ($e)');
    }
  }

  /// Pede permissão de notificação e registra o aparelho.
  ///
  /// Fica **fora** do boot de propósito: `requestPermission` abre o diálogo do
  /// sistema e só retorna quando o usuário responde — chamado na inicialização,
  /// ele trava o app até alguém tocar no botão. Chame isto na tela onde o
  /// usuário liga notificações, onde o pedido tem contexto.
  ///
  /// Devolve o token FCM quando concedida, `null` caso contrário.
  Future<String?> requestPushPermission() async {
    if (!_ready) return null;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('FCM permissão: ${settings.authorizationStatus}');

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return null;
      }

      // Notificação em primeiro plano no iOS: sem isto ela chega silenciosa.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Em iOS o registro no APNs acontece de forma assíncrona depois da
      // permissão: chamar `getToken()` direto falha com
      // `apns-token-not-set`. Espera o token APNs aparecer antes de seguir.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final apns = await _awaitApnsToken(messaging);
        if (apns == null) {
          debugPrint('FCM: APNs não registrou a tempo — token adiado');
          return null;
        }
      }

      _fcmToken = await messaging.getToken(
        vapidKey: kIsWeb ? _webVapidKey : null,
      );
      await registerDevice();
      return _fcmToken;
    } catch (e) {
      debugPrint('Firebase: requestPushPermission falhou ($e)');
      return null;
    }
  }

  /// Aguarda o registro no APNs. Retorna o token, ou `null` se não vier a
  /// tempo — sem rede ou sem a APNs Key configurada no Firebase, ele não vem.
  Future<String?> _awaitApnsToken(
    FirebaseMessaging messaging, {
    Duration limite = const Duration(seconds: 15),
  }) async {
    final prazo = DateTime.now().add(limite);
    while (DateTime.now().isBefore(prazo)) {
      final t = await messaging.getAPNSToken();
      if (t != null) return t;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  /// Status atual, sem abrir diálogo — serve para a tela decidir se ainda
  /// precisa pedir permissão.
  Future<AuthorizationStatus> pushStatus() async {
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return s.authorizationStatus;
    } catch (_) {
      return AuthorizationStatus.notDetermined;
    }
  }
}
