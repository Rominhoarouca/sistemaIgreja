import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../injection/injection.dart';
import '../../data/album_models.dart';
import '../../data/album_repository.dart';
import '../widgets/photo_montage.dart';

/// Um álbum por dia com registro de encontro, recortado pelo que o perfil
/// administra (admin: igreja toda; coordenador: sua coordenação; supervisor:
/// seus líderes).
class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key});

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  late final AlbumRepository _repo;
  List<AlbumDay> _days = [];
  bool _loading = true;
  String? _error;

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
      final days = await _repo.listDays();
      if (!mounted) return;
      setState(() {
        _days = days;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Não foi possível carregar os álbuns';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Álbuns dos encontros')),
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 32))
          : _error != null
          ? AppErrorState(message: _error!, onRetry: _load)
          : _days.isEmpty
          ? const AppEmptyState(
              title: 'Nenhuma foto ainda',
              subtitle:
                  'Os álbuns aparecem aqui quando as células enviarem fotos '
                  'no registro de presença.',
              icon: Icons.photo_library_outlined,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                itemCount: _days.length,
                itemBuilder: (_, i) {
                  final day = _days[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.base),
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      onTap: () => context.push(
                        AppRoutes.albumDay.replaceFirst(':date', day.date),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PhotoMontage(
                            photoUrls: day.coverPhotos,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppSpacing.radiusMd),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.base),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    formatAlbumDate(day.date),
                                    style: AppTypography.titleSmall,
                                  ),
                                ),
                                AppBadge(
                                  label: day.photoCount == 1
                                      ? '1 foto'
                                      : '${day.photoCount} fotos',
                                  variant: AppBadgeVariant.neutral,
                                  size: AppBadgeSize.sm,
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
            ),
    );
  }
}

const _weekdays = [
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
  'Domingo',
];

const _months = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// `2026-07-04` → `Sábado, 4 de julho de 2026`.
///
/// A data é lida como UTC: `meeting_date` é `date` no banco, e converter para
/// o fuso local jogaria o dia para trás.
String formatAlbumDate(String isoDate) {
  final parsed = DateTime.tryParse('${isoDate}T00:00:00Z');
  if (parsed == null) return isoDate;
  final d = parsed.toUtc();
  return '${_weekdays[d.weekday - 1]}, ${d.day} de ${_months[d.month - 1]} '
      'de ${d.year}';
}
