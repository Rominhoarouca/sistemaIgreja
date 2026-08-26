import 'package:flutter/widgets.dart';

/// Faixas de largura da interface.
///
/// Antes havia só duas: abaixo de 1024 era "celular", acima era "desktop". O
/// tablet caía na primeira e recebia a interface de telefone esticada — num
/// iPad Air 11" em retrato (820pt) os cards de KPI ficavam com ~390pt de
/// largura cada para mostrar um ícone e um número.
///
/// Os valores seguem os do Material 3 (compact / medium / expanded) e batem com
/// os aparelhos reais: iPad Air 11" tem 820pt em retrato e 1180pt em paisagem,
/// tablets Android de 10" ficam entre 800 e 1000pt em retrato.
abstract final class AppBreakpoints {
  /// A partir daqui é tablet: cabe mais de uma coluna de conteúdo.
  static const double tablet = 720;

  /// A partir daqui cabe a sidebar fixa junto do conteúdo.
  static const double desktop = 1024;

  /// Largura máxima de uma coluna de conteúdo. Acima disso o texto fica longo
  /// demais para ler e os cards viram faixas vazias.
  static const double contentMaxWidth = 840;

  /// Largura máxima de um formulário centralizado (login, cadastro).
  static const double formMaxWidth = 480;

  static double _w(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isPhone(BuildContext context) => _w(context) < tablet;
  static bool isTablet(BuildContext context) =>
      _w(context) >= tablet && _w(context) < desktop;
  static bool isDesktop(BuildContext context) => _w(context) >= desktop;

  /// Colunas do grid de indicadores: 2 no telefone, até 4 de tablet para cima.
  ///
  /// O card de indicador foi desenhado para ~185pt — a largura que ele tem num
  /// telefone com 2 colunas. Num tablet de 820pt, manter 2 colunas dá 390pt por
  /// card: o dobro do previsto, com o conteúdo perdido no meio do vazio. Por
  /// isso o teto sobe para 4 já no tablet; o que muda entre tablet e desktop é
  /// a moldura (sidebar), não a densidade do grid.
  ///
  /// Com [itemCount], escolhe o maior número de colunas que divide a lista sem
  /// deixar sobra — 4 cards viram uma linha de 4, e 6 viram duas de 3, em vez
  /// de uma linha cheia mais um item solitário.
  static int kpiColumns(BuildContext context, {int? itemCount}) {
    final maxColumns = _w(context) >= tablet ? 4 : 2;
    if (itemCount == null || itemCount <= maxColumns) return maxColumns;

    for (var c = maxColumns; c > 2; c--) {
      if (itemCount % c == 0) return c;
    }
    return maxColumns;
  }
}

/// Centraliza e limita a largura do conteúdo.
///
/// Em telas largas uma lista de cards em coluna única fica ilegível esticada de
/// ponta a ponta; aqui ela para de crescer e fica centralizada.
class AppContentWidth extends StatelessWidget {
  const AppContentWidth({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.contentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
