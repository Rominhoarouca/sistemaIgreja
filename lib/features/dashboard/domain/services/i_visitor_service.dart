// ISP: interface focada apenas em operações de visitantes
abstract interface class IVisitorService {
  Future<List<Map<String, dynamic>>> getVisitors();
  Future<Map<String, dynamic>> getVisitorById(String id);
  Future<void> createVisitor(Map<String, dynamic> data);
}
