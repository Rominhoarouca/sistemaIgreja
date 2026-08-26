/// Plural em pt-BR para contagens exibidas na interface.
///
/// Substitui o padrão `'$n célula(s)'`, que aparecia em uma dúzia de telas e
/// deixava o parêntese visível para o usuário mesmo quando a contagem não era
/// ambígua.
library;

/// `plural(1, 'célula')` → "1 célula"; `plural(3, 'célula')` → "3 células".
///
/// [plural] cobre o caso irregular (ex.: `líder` → `líderes`); sem ele o
/// sufixo padrão é `s`.
String plural(int count, String singular, [String? plural]) {
  final word = count == 1 ? singular : (plural ?? '${singular}s');
  return '$count $word';
}
