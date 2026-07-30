import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/qr_code_card.dart';
import '../../../saas/presentation/church_context_controller.dart';

/// QR Code do cadastro público da igreja.
///
/// O link carrega o slug da igreja (`?igreja=`) porque o formulário de
/// auto-cadastro é aberto sem login: é o slug que diz ao backend em qual
/// igreja gravar o visitante.
class AdminQrCodePage extends StatelessWidget {
  const AdminQrCodePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ChurchContextController.instance,
      builder: (context, _) {
        final church = ChurchContextController.instance.church;

        return Scaffold(
          appBar: AppBar(title: const Text('QR Code de cadastro')),
          body: church == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                  children: [
                    _Intro(churchName: church.name),
                    const SizedBox(height: AppSpacing.base),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: QrCodeCard(
                          title: 'Cadastro de visitante — ${church.name}',
                          subtitle:
                              'Quem escanear escolhe a célula que frequenta, '
                              'ou marca que ainda não frequenta nenhuma.',
                          link:
                              '${AppConstants.publicAppOrigin}'
                              '${AppRoutes.visitorSelfRegister}'
                              '?igreja=${church.slug}',
                          fileName: 'qrcode-cadastro-${church.slug}',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl2),
                  ],
                ),
        );
      },
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.churchName});

  final String churchName;

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
            Icons.info_outline,
            size: AppSpacing.iconSm,
            color: isDark ? AppColors.linkDark : AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cadastro aberto da igreja',
                  style: AppTypography.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Imprima ou compartilhe este QR Code. O cadastro feito por '
                  'ele entra em $churchName e aparece na lista de visitantes. '
                  'Para um QR Code que já vem com a célula preenchida, cada '
                  'líder tem o seu na área dele.',
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
