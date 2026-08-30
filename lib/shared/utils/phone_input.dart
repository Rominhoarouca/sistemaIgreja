import 'package:flutter/services.dart';

/// Máscara de telefone brasileiro.
///
/// Alterna sozinha entre fixo e celular — `(11) 3333-4444` com 10 dígitos e
/// `(11) 99999-8888` com 11. A máscara fixa de 11 dígitos que estava espalhada
/// pelas telas não deixava digitar um número de 8 dígitos até o fim.
class BrPhoneInputFormatter extends TextInputFormatter {
  const BrPhoneInputFormatter();

  /// DDD + 9 dígitos.
  static const int _maxDigits = 11;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _digitsOf(newValue.text);
    final capped = digits.length > _maxDigits
        ? digits.substring(0, _maxDigits)
        : digits;
    final formatted = formatBrPhone(capped);

    // O cursor é reposicionado contando dígitos, não caracteres: inserir um
    // ')' ou '-' no meio deslocaria o cursor se fosse por offset bruto.
    final digitsBeforeCursor = _digitsOf(
      newValue.text.substring(0, newValue.selection.end.clamp(0, newValue.text.length)),
    ).length;

    var offset = formatted.length;
    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (_isDigit(formatted[i])) {
        seen++;
        if (seen == digitsBeforeCursor) {
          offset = i + 1;
          break;
        }
      }
    }
    if (digitsBeforeCursor == 0) offset = 0;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset.clamp(0, formatted.length)),
    );
  }

  static bool _isDigit(String c) => c.codeUnitAt(0) ^ 0x30 <= 9;

  static String _digitsOf(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');
}

/// Formatadores para qualquer campo de telefone do app.
const List<TextInputFormatter> brPhoneInputFormatters = [
  BrPhoneInputFormatter(),
];

/// Formata para exibição. Aceita o número com ou sem máscara; devolve o texto
/// original quando não parece um telefone (para não esconder dado ruim).
String formatBrPhone(String value) {
  final digits = BrPhoneInputFormatter._digitsOf(value);
  if (digits.isEmpty) return '';

  final ddd = digits.substring(0, digits.length.clamp(0, 2));
  if (digits.length <= 2) return '($ddd';

  final rest = digits.substring(2);
  // 9 dígitos = celular (5+4); 8 = fixo (4+4). Abaixo disso ainda está
  // digitando, então não quebra o bloco.
  final split = rest.length > 8 ? 5 : 4;
  if (rest.length <= split) return '($ddd) $rest';
  return '($ddd) ${rest.substring(0, split)}-${rest.substring(split)}';
}
