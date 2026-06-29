// ISP: interface focada apenas em operações de células
abstract interface class ICellService {
  Future<List<Map<String, dynamic>>> getCells();
  Future<Map<String, dynamic>> getCellById(String id);
  Future<List<Map<String, dynamic>>> getCellMembers(String cellId);
  Future<void> createCell(Map<String, dynamic> data);
  Future<void> updateCell(String id, Map<String, dynamic> data);
  Future<void> deleteCell(String id);
  Future<void> addCellMember(String cellId, Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> getLeaders();
}
