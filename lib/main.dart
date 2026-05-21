import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'design_system/design_system.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'injection/injection.dart';
import 'routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupInjection();
  runApp(const SistemaIgrejaApp());
}

class SistemaIgrejaApp extends StatefulWidget {
  const SistemaIgrejaApp({super.key});

  @override
  State<SistemaIgrejaApp> createState() => _SistemaIgrejaAppState();
}

class _SistemaIgrejaAppState extends State<SistemaIgrejaApp> {
  late final AuthBloc _authBloc;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authBloc = getIt<AuthBloc>();
    _router = createRouter(_authBloc);
    _authBloc.add(const AuthCheckRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: _authBloc,
      child: MaterialApp.router(
        title: 'Sistema Igreja',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: _router,
      ),
    );
  }
}
