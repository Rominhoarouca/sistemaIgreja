import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_igreja/design_system/components/buttons/app_button.dart';
import 'package:sistema_igreja/design_system/theme/app_theme.dart';

const _longLabel = 'Baixar QR Code em alta resolução';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('label encolhe com ellipsis em largura apertada', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SizedBox(
          width: 120,
          child: AppButton(label: _longLabel, prefixIcon: Icons.download),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.takeException();

    // Nenhum overflow: o Flex não estourou a largura recebida.
    expect(tester.takeException(), isNull);

    final text = tester.widget<Text>(find.text(_longLabel));
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.maxLines, 1);
  });

  testWidgets('duas variantes lado a lado em Expanded não estouram', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const SizedBox(
          width: 240,
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Copiar link do cadastro',
                  variant: AppButtonVariant.outline,
                  prefixIcon: Icons.link,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'Baixar imagem PNG',
                  variant: AppButtonVariant.outline,
                  prefixIcon: Icons.download,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('todas as variantes sobrevivem a largura apertada', (
    tester,
  ) async {
    for (final variant in AppButtonVariant.values) {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 140,
            child: AppButton(
              label: _longLabel,
              variant: variant,
              prefixIcon: Icons.download,
              suffixIcon: Icons.chevron_right,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'variante $variant');
    }
  });

  testWidgets('IntrinsicWidth ao redor do botão não lança', (tester) async {
    // Trava o contrato: AppButton tem de responder dimensões intrínsecas, do
    // contrário quebra dentro de IntrinsicWidth/IntrinsicHeight/DataTable.
    // É o motivo de não haver LayoutBuilder na composição do rótulo.
    await tester.pumpWidget(
      _wrap(
        const IntrinsicWidth(
          child: AppButton(
            label: _longLabel,
            isFullWidth: false,
            prefixIcon: Icons.download,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(_longLabel), findsOneWidget);
  });

  testWidgets('estado isLoading segue mostrando o spinner', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SizedBox(
          width: 120,
          child: AppButton(label: _longLabel, isLoading: true),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(_longLabel), findsNothing);
  });
}
