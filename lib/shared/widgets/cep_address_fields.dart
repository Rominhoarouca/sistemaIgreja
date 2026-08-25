import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../../design_system/design_system.dart';
import 'address_selector.dart';

/// Valor resolvido pelos campos de endereço por CEP.
class CepAddressValue {
  const CepAddressValue({
    required this.address,
    required this.numero,
    required this.complemento,
    required this.bairroId,
  });

  final String address;
  final String numero;
  final String? complemento;
  final String? bairroId;

  bool get isEmpty => address.isEmpty && numero.isEmpty && bairroId == null;

  /// Junta logradouro + número (+ complemento) num texto só — para modelos que
  /// têm um único campo `address`, sem colunas próprias de número/complemento
  /// (ex.: membro de célula).
  String get combined {
    final parts = <String>[
      if (address.isNotEmpty) address,
      if (numero.isNotEmpty) numero,
    ];
    var text = parts.join(', ');
    if (complemento != null && complemento!.isNotEmpty) {
      text = text.isEmpty ? complemento! : '$text - $complemento';
    }
    return text;
  }
}

/// CEP com busca automática (ViaCEP) + logradouro/número/complemento + bairro.
///
/// Mesmo fluxo do auto-cadastro público do visitante, componentizado para uso
/// nos formulários internos (líder/admin): informa o CEP, busca o endereço, e
/// tenta casar UF/cidade/bairro com os registros locais (`/location/...`) para
/// pré-selecionar o [AddressSelector] — o usuário pode corrigir manualmente se
/// o casamento falhar ou o bairro não existir na base.
///
/// Sem geocodificação: diferente do cadastro público (que localiza células
/// próximas no mapa), aqui só o endereço em si importa — visitante e membro
/// não têm latitude/longitude.
class CepAddressFields extends StatefulWidget {
  const CepAddressFields({
    super.key,
    required this.dio,
    required this.onChanged,
    this.isBairroRequired = false,
  });

  /// Dio autenticado do app (usado para `/location/...` e passado ao
  /// [AddressSelector]). A busca no ViaCEP usa um `Dio()` avulso, já que é uma
  /// API pública fora do backend.
  final Dio dio;
  final ValueChanged<CepAddressValue> onChanged;
  final bool isBairroRequired;

  @override
  State<CepAddressFields> createState() => _CepAddressFieldsState();
}

class _CepAddressFieldsState extends State<CepAddressFields> {
  final _cepCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _complementoCtrl = TextEditingController();

  bool _cepLoading = false;
  String? _estadoId;
  String? _cidadeId;
  String? _bairroId;

  @override
  void initState() {
    super.initState();
    _addressCtrl.addListener(_emit);
    _numeroCtrl.addListener(_emit);
    _complementoCtrl.addListener(_emit);
  }

  @override
  void dispose() {
    _cepCtrl.dispose();
    _addressCtrl.dispose();
    _numeroCtrl.dispose();
    _complementoCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      CepAddressValue(
        address: _addressCtrl.text.trim(),
        numero: _numeroCtrl.text.trim(),
        complemento: _complementoCtrl.text.trim().isEmpty
            ? null
            : _complementoCtrl.text.trim(),
        bairroId: _bairroId,
      ),
    );
  }

  void _onCepChanged(String value) {
    final cleaned = value.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length == 8 && !_cepLoading) {
      _lookupCep(cleaned);
    }
  }

  Future<void> _lookupCep(String cep) async {
    setState(() => _cepLoading = true);
    try {
      final resp = await Dio().get('https://viacep.com.br/ws/$cep/json/');
      final data = resp.data as Map<String, dynamic>;
      if (data['erro'] == true) {
        setState(() => _cepLoading = false);
        return;
      }

      final logradouro = data['logradouro'] as String? ?? '';
      final bairroNome = data['bairro'] as String? ?? '';
      final localidade = data['localidade'] as String? ?? '';
      final uf = data['uf'] as String? ?? '';

      String? foundEstadoId, foundCidadeId, foundBairroId;
      try {
        final estadosResp = await widget.dio.get('/location/estados');
        final estados =
            (estadosResp.data as Map<String, dynamic>)['estados'] as List;
        for (final e in estados) {
          final estado = e as Map<String, dynamic>;
          if ((estado['uf'] as String?)?.toUpperCase() == uf.toUpperCase()) {
            foundEstadoId = estado['id'] as String;
            break;
          }
        }

        if (foundEstadoId != null) {
          final cidadesResp = await widget.dio.get(
            '/location/estados/$foundEstadoId/cidades',
          );
          final cidades =
              (cidadesResp.data as Map<String, dynamic>)['cidades'] as List;
          for (final c in cidades) {
            final cidade = c as Map<String, dynamic>;
            if ((cidade['name'] as String?)?.trim().toLowerCase() ==
                localidade.trim().toLowerCase()) {
              foundCidadeId = cidade['id'] as String;
              break;
            }
          }

          if (foundCidadeId != null) {
            final bairrosResp = await widget.dio.get(
              '/location/cidades/$foundCidadeId/bairros',
            );
            final bairros =
                (bairrosResp.data as Map<String, dynamic>)['bairros'] as List;
            for (final b in bairros) {
              final bairro = b as Map<String, dynamic>;
              if ((bairro['name'] as String?)?.trim().toLowerCase() ==
                  bairroNome.trim().toLowerCase()) {
                foundBairroId = bairro['id'] as String;
                break;
              }
            }
          }
        }
      } catch (_) {
        // Segue só com o logradouro do ViaCEP; usuário ajusta o bairro na mão.
      }

      if (!mounted) return;
      setState(() {
        _addressCtrl.text = logradouro;
        _estadoId = foundEstadoId;
        _cidadeId = foundCidadeId;
        _bairroId = foundBairroId;
        _cepLoading = false;
      });
      _emit();
    } catch (_) {
      if (!mounted) return;
      setState(() => _cepLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            AppTextField(
              controller: _cepCtrl,
              label: 'CEP (busca automática)',
              hint: '00000-000',
              prefixIcon: Icons.location_on_outlined,
              suffixIcon: _cepLoading ? null : Icons.search_outlined,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onChanged: _onCepChanged,
              inputFormatters: [
                MaskTextInputFormatter(
                  mask: '#####-###',
                  filter: {'#': RegExp(r'[0-9]')},
                ),
              ],
              enabled: !_cepLoading,
            ),
            if (_cepLoading)
              const Positioned(
                right: 50,
                top: 0,
                bottom: 0,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        AppTextField(
          controller: _addressCtrl,
          label: 'Endereço',
          hint: 'Preenchido pelo CEP — ajuste se preciso',
          prefixIcon: Icons.home_outlined,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.base),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: AppTextField(
                controller: _numeroCtrl,
                label: 'Número',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: AppSpacing.base),
            Expanded(
              flex: 3,
              child: AppTextField(
                controller: _complementoCtrl,
                label: 'Complemento (opcional)',
                textInputAction: TextInputAction.done,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        AddressSelector(
          dio: widget.dio,
          isRequired: widget.isBairroRequired,
          initialEstadoId: _estadoId,
          initialCidadeId: _cidadeId,
          initialBairroId: _bairroId,
          onChanged: (id) {
            _bairroId = id;
            _emit();
          },
        ),
      ],
    );
  }
}
