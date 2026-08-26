import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:multiplicado/features/kids/presentation/pages/guardian_home_page.dart';
import 'package:multiplicado/features/kids/presentation/pages/kids_home_page.dart';
import 'package:multiplicado/features/kids/presentation/pages/kids_rooms_admin_page.dart';
import 'package:multiplicado/features/kids/presentation/pages/kids_session_page.dart';

/// Renderiza as telas do Kids contra um backend falso alimentado pelas mesmas
/// fixtures reais dos testes de contrato.
///
/// O que isto pega e o teste de modelo não pega: overflow de layout, campo
/// nulo estourando na tela, estado de erro que nunca aparece. É o mais perto de
/// "abrir o app" que dá para automatizar.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.routes);

  /// Caminho da requisição → corpo JSON da resposta.
  final Map<String, Object> routes;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final match = routes.entries.firstWhere(
      (e) => options.path.startsWith(e.key),
      orElse: () => throw StateError('rota não mapeada no teste: ${options.path}'),
    );
    return ResponseBody.fromString(
      jsonEncode(match.value),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _fixture(String name) => jsonDecode(
  File('test/features/kids/fixtures/$name.json').readAsStringSync(),
) as Map<String, dynamic>;

void _installFakeDio(Map<String, Object> routes) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local/v1'))
    ..httpClientAdapter = _FakeAdapter(routes);
  if (GetIt.I.isRegistered<Dio>()) GetIt.I.unregister<Dio>();
  GetIt.I.registerSingleton<Dio>(dio);
}

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  tearDown(() {
    if (GetIt.I.isRegistered<Dio>()) GetIt.I.unregister<Dio>();
  });

  testWidgets('home do professor lista salas e alertas abertos', (tester) async {
    _installFakeDio({
      '/kids/rooms': _fixture('rooms'),
      '/kids/alerts': _fixture('alerts'),
    });

    await tester.pumpWidget(_wrap(const KidsHomePage()));
    await tester.pumpAndSettle();

    expect(find.text('Kids'), findsOneWidget);
    expect(find.text('Minhas salas'), findsOneWidget);

    final rooms = (_fixture('rooms')['rooms'] as List)
        .map((r) => (r as Map<String, dynamic>)['name'] as String)
        .toSet();
    for (final name in rooms) {
      // skipOffstage: false — com alertas abertos no topo, as últimas salas
      // nascem fora da viewport do teste, mas precisam estar na árvore.
      expect(
        find.text(name, skipOffstage: false),
        findsWidgets,
        reason: 'sala $name sumiu da lista',
      );
    }
  });

  testWidgets('sala mostra crianças presentes, ocupação e anotações', (tester) async {
    final session = _fixture('session');
    _installFakeDio({'/kids/sessions/': session});

    await tester.pumpWidget(
      _wrap(
        KidsSessionPage(
          sessionId: (session['session'] as Map<String, dynamic>)['id'] as String,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final data = session['session'] as Map<String, dynamic>;
    expect(find.text(data['roomName'] as String), findsWidgets);

    final present = (session['checkins'] as List)
        .where((c) => (c as Map<String, dynamic>)['status'] == 'CHECKED_IN')
        .length;
    expect(find.text('Na sala ($present)'), findsOneWidget);

    // Botão de check-in só existe enquanto a sala está aberta.
    if (data['status'] == 'OPEN') {
      expect(find.text('Check-in'), findsOneWidget);
    }
  });

  testWidgets('sala vazia explica o próximo passo em vez de ficar em branco', (
    tester,
  ) async {
    _installFakeDio({
      '/kids/sessions/': {
        'session': {
          'id': 's1',
          'roomId': 'r1',
          'roomName': 'Berçário',
          'serviceDate': '2026-08-23T00:00:00.000Z',
          'serviceName': 'Culto',
          'status': 'OPEN',
          'capacity': 10,
          'presentCount': 0,
          'totalCheckins': 0,
          'openAlerts': 0,
          'openedAt': '2026-08-23T09:00:00.000Z',
        },
        'checkins': const [],
        'notes': const [],
      },
    });

    await tester.pumpWidget(_wrap(const KidsSessionPage(sessionId: 's1')));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma criança na sala'), findsOneWidget);
    expect(find.text('0 de 10 lugares'), findsOneWidget);
  });

  testWidgets('home do responsável mostra onde cada filho está', (tester) async {
    _installFakeDio({
      '/kids/my-children': _fixture('my_children'),
      '/kids/my-alerts': _fixture('my_alerts'),
    });

    await tester.pumpWidget(_wrap(const GuardianHomePage()));
    await tester.pumpAndSettle();

    expect(find.text('Meus filhos'), findsOneWidget);
    expect(find.text('Meu QR Code'), findsOneWidget);

    final children = (_fixture('my_children')['children'] as List)
        .map((c) => (c as Map<String, dynamic>)['name'] as String);
    for (final name in children) {
      expect(find.text(name), findsWidgets);
    }
  });

  testWidgets('QR do responsável renderiza e mostra a contagem de renovação', (
    tester,
  ) async {
    _installFakeDio({
      '/kids/my-qr': {'token': 'fake.jwt.token', 'expiresIn': 60},
    });

    await tester.pumpWidget(_wrap(const GuardianQrPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Mostre este código na entrega e na retirada'), findsOneWidget);
    expect(find.textContaining('Renova em'), findsOneWidget);
  });

  testWidgets('admin avisa quando a sala não tem professor vinculado', (
    tester,
  ) async {
    _installFakeDio({
      '/kids/rooms': {
        'rooms': [
          {
            'id': 'r1',
            'name': 'Sala Nova',
            'capacity': 12,
            'isActive': true,
            'color': '#3F51B5',
            'teachers': const [],
            'openSession': null,
          },
        ],
      },
    });

    await tester.pumpWidget(_wrap(const KidsRoomsAdminPage()));
    await tester.pumpAndSettle();

    // Sala sem professor não abre sessão nenhuma — o aviso evita descobrir
    // isso no domingo de manhã.
    expect(find.text('Sem professores vinculados'), findsOneWidget);
    expect(find.text('Nova sala'), findsOneWidget);
  });

  testWidgets('erro da API vira mensagem com botão de tentar de novo', (
    tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local/v1'))
      ..httpClientAdapter = _ThrowingAdapter();
    if (GetIt.I.isRegistered<Dio>()) GetIt.I.unregister<Dio>();
    GetIt.I.registerSingleton<Dio>(dio);

    await tester.pumpWidget(_wrap(const KidsHomePage()));
    await tester.pumpAndSettle();

    expect(find.text('Plano não inclui o Kids'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}

/// Devolve o 402 que a API emite quando a igreja não assina o módulo.
class _ThrowingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'error': {'code': 'FEATURE_LOCKED', 'message': 'Plano não inclui o Kids'},
      }),
      402,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
