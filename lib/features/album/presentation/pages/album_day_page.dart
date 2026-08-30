import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../injection/injection.dart';
import '../../data/album_models.dart';
import '../../data/album_repository.dart';
import '../widgets/photo_montage.dart';
import 'albums_page.dart' show formatAlbumDate;

/// Álbum de um dia, navegado de cima para baixo na cadeia de gestão.
///
/// Em cada nível: a montagem do que está selecionado fica no topo e o carrossel
/// embaixo traz o nível seguinte — coordenações → supervisões → células → e,
/// na ponta, as fotos daquela célula. O perfil de quem entrou decide onde a
/// navegação começa (a API já devolve a árvore recortada).
class AlbumDayPage extends StatefulWidget {
  const AlbumDayPage({super.key, required this.date});

  final String date;

  @override
  State<AlbumDayPage> createState() => _AlbumDayPageState();
}

class _AlbumDayPageState extends State<AlbumDayPage> {
  late final AlbumRepository _repo;
  AlbumDayView? _album;
  bool _loading = true;
  String? _error;

  /// Caminho aberto até aqui. Vazio = raiz (todos os grupos do dia).
  final List<AlbumNode> _path = [];

  @override
  void initState() {
    super.initState();
    _repo = AlbumRepository(getIt<DioClient>().dio);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final album = await _repo.getDay(widget.date);
      if (!mounted) return;
      setState(() {
        _album = album;
        _path.clear();
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Não foi possível carregar o álbum';
      });
    }
  }

  AlbumNode? get _current => _path.isEmpty ? null : _path.last;

  /// Montagem do topo: o nó aberto, ou o dia inteiro na raiz.
  List<String> get _topMontage =>
      _current?.coverPhotos ?? _album?.allCovers ?? const [];

  /// Itens do carrossel: grupos do nível seguinte ou, na ponta, as fotos.
  List<AlbumNode> get _carouselGroups =>
      _current == null ? (_album?.groups ?? const []) : _current!.children;

  bool get _showingPhotos => _current != null && !_current!.hasChildren;

  void _open(AlbumNode node) => setState(() => _path.add(node));

  bool _goBack() {
    if (_path.isEmpty) return false;
    setState(() => _path.removeLast());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final album = _album;
    return PopScope(
      // Voltar desce um nível antes de fechar a tela — o caminho aberto é
      // navegação, mesmo sem rota própria.
      canPop: _path.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _current?.name ?? 'Álbum do dia',
                style: AppTypography.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                formatAlbumDate(widget.date),
                style: AppTypography.labelSmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: AppLoadingIndicator(size: 32))
            : _error != null
            ? AppErrorState(message: _error!, onRetry: _load)
            : album == null || album.photoCount == 0
            ? const AppEmptyState(
                title: 'Sem fotos neste dia',
                icon: Icons.photo_library_outlined,
              )
            : _buildContent(album),
      ),
    );
  }

  Widget _buildContent(AlbumDayView album) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
      children: [
        if (_path.isNotEmpty) ...[
          _breadcrumb(),
          const SizedBox(height: AppSpacing.sm),
        ],
        PhotoMontage(photoUrls: _topMontage),
        const SizedBox(height: AppSpacing.base),
        Text(
          _showingPhotos
              ? 'Fotos da célula'
              : _levelTitle(album),
          style: AppTypography.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_showingPhotos)
          _PhotoCarousel(photos: _current!.photos)
        else
          _GroupCarousel(groups: _carouselGroups, onOpen: _open),
        const SizedBox(height: AppSpacing.xl2),
      ],
    );
  }

  /// Título do carrossel: os níveis dos itens que ele mostra.
  ///
  /// O degrau do meio pode misturar supervisões e líderes ligados direto à
  /// coordenação, então o título junta os dois quando é o caso.
  String _levelTitle(AlbumDayView album) {
    final groups = _carouselGroups;
    if (groups.isEmpty) return 'Nada por aqui';
    final levels = {for (final g in groups) g.level};
    final label = levels.length == 1
        ? levels.first.plural
        : (levels.toList()..sort((a, b) => a.index.compareTo(b.index)))
              .map((l) => l.plural)
              .join(' e ');
    return '$label (${groups.length})';
  }

  Widget _breadcrumb() {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InkWell(
          onTap: () => setState(_path.clear),
          child: Text(
            'Início',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.primary,
            ),
          ),
        ),
        for (var i = 0; i < _path.length; i++) ...[
          const Icon(Icons.chevron_right, size: 14, color: AppColors.grey400),
          InkWell(
            onTap: i == _path.length - 1
                ? null
                : () => setState(() => _path.removeRange(i + 1, _path.length)),
            child: Text(
              _path[i].name,
              style: AppTypography.labelMedium.copyWith(
                color: i == _path.length - 1
                    ? AppColors.textSecondary
                    : AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Carrossel de grupos — cada item é a montagem daquele grupo.
class _GroupCarousel extends StatelessWidget {
  const _GroupCarousel({required this.groups, required this.onOpen});

  final List<AlbumNode> groups;
  final void Function(AlbumNode) onOpen;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return Text(
        'Nenhum grupo com foto neste dia.',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final group = groups[i];
          return SizedBox(
            width: 260,
            child: AppCard(
              padding: EdgeInsets.zero,
              onTap: () => onOpen(group),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PhotoMontage(
                    photoUrls: group.coverPhotos,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs2),
                        Text(
                          '${group.level.label} · '
                          '${group.photoCount == 1 ? '1 foto' : '${group.photoCount} fotos'}',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Carrossel das fotos de uma célula. Toque abre em tela cheia.
class _PhotoCarousel extends StatelessWidget {
  const _PhotoCarousel({required this.photos});

  final List<AlbumPhoto> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Text(
        'Nenhuma foto nesta célula.',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }
    return SizedBox(
      height: 240,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.86),
        itemCount: photos.length,
        itemBuilder: (_, i) {
          final photo = photos[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: AppCard(
              padding: EdgeInsets.zero,
              onTap: () => _openFullscreen(context, photos, i),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppSpacing.radiusMd),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: photo.url,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: AppColors.grey200),
                        errorWidget: (_, _, _) => Container(
                          color: AppColors.grey100,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.grey400,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          photo.cellName,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((photo.lesson ?? '').isNotEmpty)
                          Text(
                            photo.lesson!,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openFullscreen(
    BuildContext context,
    List<AlbumPhoto> photos,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenGallery(
          photos: photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _FullscreenGallery extends StatelessWidget {
  const _FullscreenGallery({required this.photos, required this.initialIndex});

  final List<AlbumPhoto> photos;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(photos[initialIndex].cellName),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: photos.length,
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: CachedNetworkImage(
              imageUrl: photos[i].url,
              fit: BoxFit.contain,
              placeholder: (_, _) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (_, _, _) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
