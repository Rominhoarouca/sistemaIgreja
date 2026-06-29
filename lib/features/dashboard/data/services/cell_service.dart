import 'package:dio/dio.dart';
import '../../domain/exceptions/service_exception.dart';
import '../../domain/services/i_cell_service.dart';

/// DIP: implementação concreta de ICellService.
final class CellService implements ICellService {
  const CellService(this._dio);

  final Dio _dio;

  @override
  Future<List<Map<String, dynamic>>> getCells() async {
    try {
      final resp = await _dio.get('/cells');
      return ((resp.data as Map<String, dynamic>)['cells'] as List)
          .cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ServiceException(
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar células',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getCellById(String id) async {
    try {
      final resp = await _dio.get('/cells/$id');
      return (resp.data as Map<String, dynamic>)['cell']
          as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ServiceException(
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar célula',
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCellMembers(String cellId) async {
    try {
      final resp = await _dio.get('/cells/$cellId/members');
      return ((resp.data as Map<String, dynamic>)['members'] as List)
          .cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ServiceException(
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar membros',
      );
    }
  }

  @override
  Future<void> createCell(Map<String, dynamic> data) async {
    try {
      await _dio.post('/cells', data: data);
    } on DioException catch (e) {
      throw ServiceException(
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao criar célula',
      );
    }
  }

  @override
  Future<void> updateCell(String id, Map<String, dynamic> data) async {
    try {
      await _dio.patch('/cells/$id', data: data);
    } on DioException catch (e) {
      throw ServiceException(
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao salvar célula',
      );
    }
  }

  @override
  Future<void> deleteCell(String id) async {
    try {
      await _dio.delete('/cells/$id');
    } on DioException catch (e) {
      throw ServiceException(
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao excluir célula',
      );
    }
  }

  @override
  Future<void> addCellMember(String cellId, Map<String, dynamic> data) async {
    try {
      await _dio.post('/cells/$cellId/members', data: data);
    } on DioException catch (e) {
      throw ServiceException(
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao adicionar membro',
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getLeaders() async {
    try {
      final resp = await _dio.get('/users/leaders');
      return ((resp.data as Map<String, dynamic>)['leaders'] as List)
          .cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ServiceException(
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar líderes',
      );
    }
  }
}
