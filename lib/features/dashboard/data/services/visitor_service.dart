import 'package:dio/dio.dart';
import '../../domain/exceptions/service_exception.dart';
import '../../domain/services/i_visitor_service.dart';

/// DIP: implementação concreta de IVisitorService.
final class VisitorService implements IVisitorService {
  const VisitorService(this._dio);

  final Dio _dio;

  @override
  Future<List<Map<String, dynamic>>> getVisitors() async {
    try {
      final resp = await _dio.get('/visitors');
      return ((resp.data as Map<String, dynamic>)['data'] as List)
          .cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ServiceException(
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar visitantes',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getVisitorById(String id) async {
    try {
      final resp = await _dio.get('/visitors/$id');
      return (resp.data as Map<String, dynamic>)['visitor']
          as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ServiceException(
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao abrir visitante',
      );
    }
  }

  @override
  Future<void> createVisitor(Map<String, dynamic> data) async {
    try {
      await _dio.post('/visitors', data: data);
    } on DioException catch (e) {
      throw ServiceException(
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao cadastrar visitante',
      );
    }
  }
}
