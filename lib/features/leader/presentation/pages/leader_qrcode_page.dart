import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/qr_code_card.dart';
import '../../../saas/presentation/church_context_controller.dart';
import '../../../../injection/injection.dart';

/// QR Code de cadastro por célula, para o líder.
///
/// Diferente do QR Code geral da igreja, este já leva a célula no link
/// (`&celula=`): o visitante não precisa procurar a célula certa na lista, ela
/// vem preenchida e travada. Um QR por célula, já que um líder pode ter mais
/// de uma.
class LeaderQrCodePage extends StatefulWidget {
  const LeaderQrCodePage({super.key});

  @override
  State<LeaderQrCodePage> createState() => _LeaderQrCodePageState();
}

class _LeaderCell {
  const _LeaderCell({required this.id, required this.name, this.typeName});

  factory _LeaderCell.fromJson(Map<String, dynamic> json) => _LeaderCell(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Célula',
    typeName: json['cellType'] as String?,
  );

  final String id;
  final String name;
  final String? typeName;
}

class _LeaderQrCodePageState extends State<LeaderQrCodePage> {
  late final Dio _dio;
  bool _loading = true;
  String? _error;
  List<_LeaderCell> _cells = [];

  @override
  void initState() {
    super.initState();
    _dio = getIt<DioClient>().dio;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _dio.get('/cells/my-cell');
      final raw = (resp.data as Map<String, dynamic>)['cells'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _cells = raw
            .map((c) => _LeaderCell.fromJson(c as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar suas células';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Code da célula')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.base),
            AppButton(
              label: 'Tentar novamente',
              variant: AppButtonVariant.outline,
              isFullWidth: false,
              onPressed: _load,
            ),
          ],
        ),
      );
    }

    // O slug da igreja é obrigatório no link: a tela de cadastro é pública e
    // sem ele o backend não sabe em qual igreja gravar.
    final church = ChurchContextController.instance.church;
    if (church == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cells.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        child: AppEmptyState(
          title: 'Você ainda não tem célula',
          subtitle:
              'Quando uma célula for atribuída a você, o QR Code de cadastro '
              'dela aparece aqui.',
          icon: Icons.qr_code_2_outlined,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
      children: [
        _Intro(multiple: _cells.length > 1),
        const SizedBox(height: AppSpacing.base),
        for (final cell in _cells) ...[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: QrCodeCard(
                title: cell.name,
                subtitle: cell.typeName == null
                    ? 'O visitante já entra vinculado a esta célula.'
                    : '${cell.typeName} · o visitante já entra vinculado a '
                          'esta célula.',
                link:
                    '${AppConstants.publicAppOrigin}'
                    '${AppRoutes.visitorSelfRegister}'
                    '?igreja=${church.slug}&celula=${cell.id}',
                fileName: 'qrcode-celula-${cell.id}',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
        ],
        const SizedBox(height: AppSpacing.xl2),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.multiple});

  final bool multiple;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;

    return AppCard(
      color: isDark ? AppColors.chipDark : AppColors.chip,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.qr_code_2_outlined,
            size: AppSpacing.iconSm,
            color: isDark ? AppColors.linkDark : AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cadastro direto na célula',
                  style: AppTypography.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  multiple
                      ? 'Um QR Code para cada célula sua. Quem escanear já '
                            'entra vinculado à célula do código, sem precisar '
                            'escolher na lista.'
                      : 'Quem escanear já entra vinculado à sua célula, sem '
                            'precisar escolher na lista.',
                  style: AppTypography.bodySmall.copyWith(color: mutedColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
