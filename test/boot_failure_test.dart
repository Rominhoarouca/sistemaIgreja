import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sistema_igreja/main.dart';

/// O app não pode falhar em silêncio no boot.
///
/// Tela branca sem mensagem é o pior modo de falha em celular: não há debugger
/// anexado, o `runZonedGuarded` engole o erro num `developer.log`, e quem está
/// com o aparelho na mão não tem o que reportar além de "não abriu".
void main() {
  testWidgets('sem injeção de dependências, mostra o erro em vez de tela branca', (
    tester,
  ) async {
    // Nada registrado no GetIt: resolver o AuthBloc vai lançar, como acontece
    // quando `setupInjection` falha no aparelho.
    await GetIt.I.reset();

    await tester.pumpWidget(const SistemaIgrejaApp());
    await tester.pump();

    expect(find.text('Falha ao iniciar o aplicativo'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    // A mensagem técnica precisa estar visível e copiável para o suporte.
    expect(find.byType(SelectableText), findsWidgets);
  });

  testWidgets('tela de erro de boot mostra a exceção e o começo do stack', (
    tester,
  ) async {
    await tester.pumpWidget(
      BootErrorApp(
        error: StateError('MissingPluginException(shared_preferences)'),
        stackTrace: StackTrace.fromString(
          '#0      ThemeController.load\n#1      main\n#2      _runMain',
        ),
      ),
    );
    await tester.pump();

    expect(
      find.textContaining('MissingPluginException(shared_preferences)'),
      findsOneWidget,
    );
    expect(find.textContaining('ThemeController.load'), findsOneWidget);
  });
}
