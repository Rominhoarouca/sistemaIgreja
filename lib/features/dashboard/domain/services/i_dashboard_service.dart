// ISP: interface focada apenas em estatísticas do dashboard
abstract interface class IDashboardService {
  Future<Map<String, dynamic>> getStats();
  Future<List<Map<String, dynamic>>> getMonthlyStats();
}
