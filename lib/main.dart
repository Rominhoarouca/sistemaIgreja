import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
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
  WidgetsFlutterBinding.ensureInitialized();
  // Estratégia de URL só existe na web. Em iOS/Android a chamada lança antes do
  // runApp — o app instala, abre e fica na tela branca, sem árvore de widgets.
  if (kIsWeb) usePathUrlStrategy();

  // Global error handling to capture initialization/runtime errors that
  // otherwise cause the app to terminate when launched from the home screen.
  FlutterError.onError = (details) {
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
        await setupInjection().timeout(const Duration(seconds: 15));
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
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
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

  @override
  void initState() {
    super.initState();
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
          if (state is AuthAuthenticated) {
            ChurchContextController.instance.load();
          } else if (state is AuthUnauthenticated) {
            ChurchContextController.instance.reset();
          }
        },
        child: ListenableBuilder(
          // Reconstrói ao mudar o tema OU a cor do menu da igreja.
          listenable: Listenable.merge([
            ThemeController.instance,
            ChurchContextController.instance,
          ]),
          builder: (context, _) {
            final menuColor = ChurchContextController.instance.context?.church.menuColor;
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
