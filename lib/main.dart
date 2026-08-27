import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_constants.dart';
import 'core/firebase/firebase_service.dart';
import 'design_system/design_system.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/saas/presentation/church_context_controller.dart';
import 'features/saas/presentation/church_theme.dart';
import 'injection/injection.dart';
import 'routing/app_router.dart';
import 'shared/utils/app_snackbar.dart';

import 'dart:async';
import 'dart:developer' as developer;

Future<void> main() async {
  // Nada de `ensureInitialized()` aqui: o binding tem de nascer dentro do
  // mesmo zone que chama `runApp`, senão o Flutter avisa "Zone mismatch" a
  // cada boot e configurações por zone passam a valer de forma imprevisível.
  // A inicialização foi para dentro do `runZonedGuarded`, logo abaixo.

  // Global error handling to capture initialization/runtime errors that
  // otherwise cause the app to terminate when launched from the home screen.
  FlutterError.onError = (details) {
    // `presentError` primeiro: sem ele o erro só ia para o developer.log, que
    // não aparece no console do `flutter run` — falhas de layout ficavam
    // invisíveis e a tela apenas aparecia vazia, sem pista nenhuma.
    FlutterError.presentError(details);
    developer.log(
      'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
    // Forward to zone handler as well.
    Zone.current.handleUncaughtError(
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };

  // Nada aqui pode abortar antes do runApp: sem árvore de widgets o aparelho
  // mostra só uma tela branca, e o motivo fica preso num developer.log que
  // ninguém lê sem debugger anexado. Toda falha de boot vira tela de erro.
  var appStarted = false;

  await runZonedGuarded(
    () async {
      // Binding criado aqui dentro: mesmo zone do `runApp` lá embaixo.
      WidgetsFlutterBinding.ensureInitialized();

      // Estratégia de URL só existe na web, e depende do binding já existir.
      // Em iOS/Android a chamada lança antes do runApp — o app instala, abre
      // e fica na tela branca, sem árvore de widgets.
      if (kIsWeb) usePathUrlStrategy();

      Object? bootError;
      StackTrace? bootStack;

      // Marcos de boot em stdout: no aparelho, sem debugger, é o único rastro
      // que aparece no console do sistema (`idevicesyslog`). Um passo que não
      // imprime o próximo é um passo que travou.
      debugPrint('BOOT: início');

      try {
        // Timeout porque plugin de plataforma pode não responder: sem ele o
        // app fica esperando para sempre e o usuário vê tela branca.
        await ThemeController.instance.load().timeout(
          const Duration(seconds: 5),
        );
        debugPrint('BOOT: tema carregado');
      } catch (e, st) {
        // Tema é cosmético — segue com o padrão do sistema.
        debugPrint('BOOT: tema falhou ($e)');
        developer.log('ThemeController.load failed', error: e, stackTrace: st);
      }

      try {
        // Firebase antes do DI: o handler de background precisa estar
        // registrado cedo, e uma falha aqui não impede o app de abrir.
        FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
        await FirebaseService.instance.init().timeout(
          const Duration(seconds: 10),
        );
        debugPrint('BOOT: firebase ${FirebaseService.instance.isReady ? "pronto" : "indisponível"}');
      } catch (e) {
        debugPrint('BOOT: firebase falhou ($e)');
      }

      try {
        await setupInjection().timeout(const Duration(seconds: 15));
        // Só agora o Dio autenticado existe: é por ele que o token do
        // aparelho chega ao backend.
        FirebaseService.instance.dio = getIt<Dio>();
        debugPrint('BOOT: injeção pronta');
      } catch (e, st) {
        debugPrint('BOOT: injeção falhou ($e)');
        developer.log('setupInjection failed', error: e, stackTrace: st);
        // Sem DI o app não funciona: guarda para mostrar na tela.
        bootError = e;
        bootStack = st;
      }

      appStarted = true;
      debugPrint('BOOT: runApp');
      runApp(
        bootError == null
            ? const SistemaIgrejaApp()
            : BootErrorApp(error: bootError, stackTrace: bootStack),
      );
    },
    (error, stack) {
      developer.log('Uncaught zone error', error: error, stackTrace: stack);
      // Erro antes do primeiro runApp: mostra o motivo em vez da tela branca.
      if (!appStarted) {
        appStarted = true;
        runApp(BootErrorApp(error: error, stackTrace: stack));
      }
    },
  );
}

/// Tela de falha de inicialização.
///
/// Existe para o caso em que o app não consegue montar: em vez de uma tela
/// branca muda, mostra o erro no próprio aparelho — que costuma ser o único
/// lugar onde ele é visível quando não há debugger conectado.
class BootErrorApp extends StatelessWidget {
  const BootErrorApp({super.key, required this.error, this.stackTrace});

  final Object error;
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Falha ao iniciar o aplicativo',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Envie esta tela para o suporte técnico.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                SelectableText(
                  '$error',
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                ),
                if (stackTrace != null) ...[
                  const SizedBox(height: 16),
                  SelectableText(
                    // Primeiras linhas bastam para identificar a origem.
                    stackTrace!.toString().split('\n').take(12).join('\n'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SistemaIgrejaApp extends StatefulWidget {
  const SistemaIgrejaApp({super.key});

  @override
  State<SistemaIgrejaApp> createState() => _SistemaIgrejaAppState();
}

class _SistemaIgrejaAppState extends State<SistemaIgrejaApp> {
  AuthBloc? _authBloc;
  GoRouter? _router;
  Object? _initError;
  StackTrace? _initStack;
  StreamSubscription<RemoteMessage>? _aberturas;

  /// Toque numa notificação: leva à tela que resolve o assunto dela.
  ///
  /// Vale para os três caminhos — app aberto, em segundo plano, e aberto a
  /// partir da notificação com o app encerrado —, porque os três desembocam no
  /// mesmo `onMessageOpened`. Sem isto o toque só trazia o app à frente e
  /// parava na tela em que ele estava.
  void _abrirNotificacao(RemoteMessage m) {
    final router = _router;
    if (router == null) return;

    final destino = switch (m.data['type']) {
      // Para o professor, o que importa é a sala onde a criança está.
      'kids_ack' when (m.data['sessionId'] ?? '').isNotEmpty =>
        '/kids/sessions/${m.data['sessionId']}',
      // Para o responsável, o histórico de avisos dos filhos.
      'kids_alert' => AppRoutes.guardianAlerts,
      _ => AppRoutes.notifications,
    };

    try {
      router.push(destino);
    } catch (e) {
      debugPrint('Notificação: navegação para $destino falhou ($e)');
    }
  }

  @override
  void dispose() {
    _aberturas?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _aberturas = FirebaseService.instance.onMessageOpened.listen(
      _abrirNotificacao,
    );
    // Resolver o AuthBloc pode falhar quando o DI não subiu. Lançar aqui
    // derruba o primeiro build e devolve tela branca — daí o try.
    try {
      final bloc = getIt<AuthBloc>();
      _authBloc = bloc;
      _router = createRouter(bloc);
      bloc.add(const AuthCheckRequested());
      debugPrint('BOOT: router pronto');
    } catch (e, st) {
      debugPrint('BOOT: AuthBloc falhou ($e)');
      developer.log('AuthBloc init failed', error: e, stackTrace: st);
      _initError = e;
      _initStack = st;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authBloc = _authBloc;
    final router = _router;
    if (authBloc == null || router == null) {
      return BootErrorApp(
        error: _initError ?? 'Injeção de dependências indisponível',
        stackTrace: _initStack,
      );
    }

    return BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (prev, curr) => prev.runtimeType != curr.runtimeType,
        listener: (context, state) {
          // Carrega/limpa o contexto da igreja conforme autenticação.
          // SUPERADMIN é cross-tenant (`churchId = null`): para ele
          // `/church/me` responde 403 a cada login, sem nada a carregar.
          if (state is AuthAuthenticated) {
            if (!state.user.isSuperAdmin) {
              ChurchContextController.instance.load();
            }
            // Identifica o usuário no Crashlytics/Analytics: sem isso um crash
            // vira estatística anônima e não dá para saber se atinge um perfil
            // específico ou todo mundo.
            FirebaseService.instance.setUser(
              userId: state.user.id,
              role: state.user.role.name,
            );
            // Agora há sessão: o aparelho pode ser registrado para push.
            FirebaseService.instance.syncTokenIfAuthorized();
          } else if (state is AuthUnauthenticated) {
            ChurchContextController.instance.reset();
            FirebaseService.instance.unregisterDevice();
            FirebaseService.instance.clearUser();
          }
        },
        child: ListenableBuilder(
          // Reconstrói ao mudar o tema OU a cor do menu da igreja.
          listenable: Listenable.merge([
            ThemeController.instance,
            ChurchContextController.instance,
          ]),
          builder: (context, _) {
            final menuColor =
                ChurchContextController.instance.context?.church.menuColor;
            return MaterialApp.router(
              title: 'Sistema Igreja',
              debugShowCheckedModeBanner: false,
              theme: applyChurchMenuColor(AppTheme.light, menuColor),
              darkTheme: applyChurchMenuColor(AppTheme.dark, menuColor),
              themeMode: ThemeController.instance.mode,
              routerConfig: router,
              scaffoldMessengerKey: scaffoldMessengerKey,
              localizationsDelegates: const [
                DefaultCupertinoLocalizations.delegate,
                DefaultMaterialLocalizations.delegate,
                DefaultWidgetsLocalizations.delegate,
                FlutterQuillLocalizations.delegate,
              ],
            );
          },
        ),
      ),
    );
  }
}
