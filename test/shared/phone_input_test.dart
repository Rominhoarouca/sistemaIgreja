import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplicado/shared/utils/phone_input.dart';

void main() {
  test('formata celular e fixo', () {
    expect(formatBrPhone('11999998888'), '(11) 99999-8888');
    expect(formatBrPhone('1133334444'), '(11) 3333-4444');
    expect(formatBrPhone('119'), '(11) 9');
    expect(formatBrPhone('11'), '(11');
    expect(formatBrPhone(''), '');
    expect(formatBrPhone('(11) 99999-8888'), '(11) 99999-8888');
  });

  test('digitando aplica a máscara e mantém o cursor no fim', () {
    const formatter = BrPhoneInputFormatter();
    var value = const TextEditingValue(text: '');
    for (final digit in '11999998888'.split('')) {
      final typed = TextEditingValue(
        text: value.text + digit,
        selection: TextSelection.collapsed(offset: value.text.length + 1),
      );
      value = formatter.formatEditUpdate(value, typed);
    }
    expect(value.text, '(11) 99999-8888');
    expect(value.selection.baseOffset, value.text.length);
  });

  test('não deixa passar de 11 dígitos', () {
    const formatter = BrPhoneInputFormatter();
    final result = formatter.formatEditUpdate(
      const TextEditingValue(text: ''),
      const TextEditingValue(text: '119999988889999'),
    );
    expect(result.text, '(11) 99999-8888');
  });
}
