import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../design_system/design_system.dart';

/// Leitor do QR do responsável. Devolve o token lido via `Navigator.pop`.
///
/// O token vale 60 segundos e é consumido no servidor, então ler duas vezes o
/// mesmo código falha de propósito — por isso a tela para de escanear no
/// primeiro resultado, em vez de disparar várias chamadas.
class KidsScanPage extends StatefulWidget {
  const KidsScanPage({super.key, required this.title});

  final String title;

  @override
  State<KidsScanPage> createState() => _KidsScanPageState();
}

class _KidsScanPageState extends State<KidsScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;
  final _manualCtrl = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (value == null) return;

    _handled = true;
    _controller.stop();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Lanterna',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Trocar câmera',
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                // Mira: sem ela o professor não sabe onde encostar o celular.
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.white, width: 3),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                ),
              ],
            ),
          ),
          // Saída de emergência: câmera quebrada, permissão negada, tablet sem
          // lente. Sem isto, a sala trava.
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              children: [
                Text(
                  'Aponte para o QR Code no app do responsável.',
                  style: AppTypography.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: _manualEntry,
                  icon: const Icon(Icons.keyboard_outlined, size: 18),
                  label: const Text('Digitar o código manualmente'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _manualEntry() async {
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Código do QR'),
        content: AppTextField(
          controller: _manualCtrl,
          autofocus: true,
          maxLines: 3,
          hint: 'Cole aqui o código exibido no app do responsável',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final text = _manualCtrl.text.trim();
              if (text.isEmpty) return;
              Navigator.of(ctx).pop(text);
            },
            child: const Text('Usar'),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    Navigator.of(context).pop(value);
  }
}
