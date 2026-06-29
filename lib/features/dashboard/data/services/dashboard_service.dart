import 'package:dio/dio.dart';
import '../../domain/exceptions/service_exception.dart';
import '../../domain/services/i_dashboard_service.dart';

/// DIP: implementação concreta de IDashboardService.
/// A UI depende da interface, não desta classe.
final class DashboardService implements IDashboardService {
  const DashboardService(this._dio);

  final Dio _dio;

  @override
  Future<Map<String, dynamic>> getStats() async {
    try {
      final resp = await _dio.get('/dashboard/stats');
      return (resp.data as Map<String, dynamic>)['stats']
          as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ServiceException(
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar estatísticas',
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMonthlyStats() async {
    try {
      final resp = await _dio.get('/dashboard/monthly-stats');
      return ((resp.data as Map<String, dynamic>)['months'] as List)
          .cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ServiceException(
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar dados mensais',
      );
    }
  }
}
