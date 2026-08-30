import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Montagem (mosaico) das fotos de um grupo.
///
/// O layout muda com a quantidade para nunca sobrar buraco: 1 foto ocupa tudo,
/// 2 dividem ao meio, 3 viram uma grande + duas empilhadas e 4+ formam a grade
/// 2×2. Mais que isso é cortado — a montagem é uma capa, não a galeria.
class PhotoMontage extends StatelessWidget {
  const PhotoMontage({
    super.key,
    required this.photoUrls,
    this.aspectRatio = 16 / 10,
    this.borderRadius,
  });

  final List<String> photoUrls;
  final double aspectRatio;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppSpacing.radiusMd);
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(borderRadius: radius, child: _buildLayout()),
    );
  }

  Widget _buildLayout() {
    final urls = photoUrls.take(4).toList();
    if (urls.isEmpty) return const _MontagePlaceholder();
    if (urls.length == 1) return _tile(urls[0]);

    if (urls.length == 2) {
      return Row(
        children: [
          Expanded(child: _tile(urls[0])),
          const SizedBox(width: 2),
          Expanded(child: _tile(urls[1])),
        ],
      );
    }

    if (urls.length == 3) {
      return Row(
        children: [
          Expanded(flex: 2, child: _tile(urls[0])),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _tile(urls[1])),
                const SizedBox(height: 2),
                Expanded(child: _tile(urls[2])),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _tile(urls[0])),
              const SizedBox(width: 2),
              Expanded(child: _tile(urls[1])),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _tile(urls[2])),
              const SizedBox(width: 2),
              Expanded(child: _tile(urls[3])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(String url) => CachedNetworkImage(
    imageUrl: url,
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
    placeholder: (_, _) => Container(color: AppColors.grey200),
    errorWidget: (_, _, _) => const _MontagePlaceholder(),
  );
}

class _MontagePlaceholder extends StatelessWidget {
  const _MontagePlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.grey100,
    alignment: Alignment.center,
    child: const Icon(
      Icons.photo_outlined,
      color: AppColors.grey400,
      size: AppSpacing.iconLg,
    ),
  );
}
