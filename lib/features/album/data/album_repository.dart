import 'package:dio/dio.dart';

import 'album_models.dart';

/// Acesso às rotas do álbum de fotos dos encontros.
class AlbumRepository {
  AlbumRepository(this._dio);

  final Dio _dio;

  Future<List<AlbumDay>> listDays({int limit = 30}) async {
    final resp = await _dio.get(
      '/albums/days',
      queryParameters: {'limit': limit},
    );
    return ((resp.data as Map<String, dynamic>)['days'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(AlbumDay.fromJson)
        .toList();
  }

  Future<AlbumDayView> getDay(String date) async {
    final resp = await _dio.get('/albums/$date');
    return AlbumDayView.fromJson(
      (resp.data as Map<String, dynamic>)['album'] as Map<String, dynamic>,
    );
  }
}
