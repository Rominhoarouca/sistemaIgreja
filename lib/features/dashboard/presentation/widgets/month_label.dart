/// Rótulo curto de mês para os eixos dos gráficos.
///
/// Duas origens alimentam os mesmos gráficos e cada uma manda um formato:
/// o dashboard da igreja vem do Postgres como `YYYY-MM`, enquanto os painéis
/// de coordenador e supervisor montam o rótulo no cliente (`'ago'`). Chamar
/// `substring(5)` direto quebrava com o segundo formato — `'ago'.substring(5)`
/// lança `RangeError`. Aqui os dois convergem para a mesma abreviação.
library;

const _monthAbbreviations = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

/// Converte o campo `month` de uma série mensal em rótulo de eixo.
///
/// Aceita `YYYY-MM` e devolve a abreviação em pt-BR; qualquer outro valor
/// (inclusive um rótulo já abreviado) é devolvido como veio.
String monthAxisLabel(Object? raw) {
  final value = raw?.toString() ?? '';
  final match = RegExp(r'^\d{4}-(\d{2})$').firstMatch(value);
  if (match == null) return value;

  final month = int.parse(match.group(1)!);
  if (month < 1 || month > 12) return value;
  return _monthAbbreviations[month - 1];
}
