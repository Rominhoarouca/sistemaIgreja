import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../design_system/design_system.dart';
// Helper de download já usado pela exportação de relatórios.
import '../../features/dashboard/data/download_stub.dart'
    if (dart.library.html) '../../features/dashboard/data/download_web.dart';
import '../utils/app_snackbar.dart';

/// Card com o QR Code de um link de cadastro, o link em texto e as ações de
/// copiar e baixar em PNG (para imprimir ou mandar no grupo).
///
/// O QR é sempre desenhado sobre branco, mesmo no tema escuro: leitor de QR
/// depende do contraste claro/escuro e um QR invertido falha em vários
/// aplicativos de câmera.
class QrCodeCard extends StatefulWidget {
  const QrCodeCard({
    super.key,
    required this.title,
    required this.link,
    required this.fileName,
    this.subtitle,
    this.size = 220,
  });

  final String title;
  final String? subtitle;
  final String link;

  /// Nome do arquivo sugerido no download, sem extensão.
  final String fileName;
  final double size;

  @override
  State<QrCodeCard> createState() => _QrCodeCardState();
}

class _QrCodeCardState extends State<QrCodeCard> {
  final _qrKey = GlobalKey();
  bool _downloading = false;

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.link));
    if (!mounted) return;
    AppSnackbar.success('Link copiado');
  }

  Future<void> _downloadPng() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      // pixelRatio 3 dá resolução suficiente para imprimir em A4.
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      final bytes = data.buffer.asUint8List();

      if (kIsWeb) {
        downloadFileWeb(bytes, '${widget.fileName}.png');
      } else if (mounted) {
        // Fora do web não há um destino óbvio sem plugin de share/arquivo.
        AppSnackbar.warning(
          'Download disponível na versão web. Use "Copiar link" aqui.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error('Erro ao gerar PNG: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: AppTypography.titleSmall),
          if (widget.subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs2),
            Text(
              widget.subtitle!,
              style: AppTypography.bodySmall.copyWith(color: mutedColor),
            ),
          ],
          const SizedBox(height: AppSpacing.base),
          Center(
            child: RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                color: AppColors.white,
                child: QrImageView(
                  data: widget.link,
                  version: QrVersions.auto,
                  size: widget.size,
                  backgroundColor: AppColors.white,
                  // Nível M tolera ~15% de dano/sujeira no papel impresso.
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceVariantDark : AppColors.grey50,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: SelectableText(
              widget.link,
              style: AppTypography.bodySmall.copyWith(color: mutedColor),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Copiar link',
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.sm,
                  prefixIcon: Icons.link_outlined,
                  onPressed: _copyLink,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: _downloading ? 'Gerando...' : 'Baixar PNG',
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.sm,
                  prefixIcon: Icons.download_outlined,
                  onPressed: _downloading ? null : _downloadPng,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
