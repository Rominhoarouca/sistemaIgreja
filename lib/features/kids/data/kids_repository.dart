import 'package:dio/dio.dart';

import 'kids_models.dart';

/// Acesso a `/v1/kids/*`. Uma instância por tela é desnecessário — o [Dio] vem
/// do DI e já carrega auth, refresh e tenant.
class KidsRepository {
  const KidsRepository(this._dio);

  final Dio _dio;

  // ── Salas ─────────────────────────────────────────────────────────────────

  Future<List<KidsRoom>> listRooms() async {
    final response = await _dio.get('/kids/rooms');
    final rooms =
        (response.data as Map<String, dynamic>)['rooms'] as List? ?? [];
    return rooms
        .map((e) => KidsRoom.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<KidsRoom> createRoom({
    required String name,
    required int capacity,
    String? description,
    int? minAgeMonths,
    int? maxAgeMonths,
    String? color,
  }) async {
    final response = await _dio.post(
      '/kids/rooms',
      data: {
        'name': name,
        'capacity': capacity,
        if (description != null && description.isNotEmpty)
          'description': description,
        'minAgeMonths': ?minAgeMonths,
        'maxAgeMonths': ?maxAgeMonths,
        'color': ?color,
      },
    );
    return KidsRoom.fromJson(
      (response.data as Map<String, dynamic>)['room'] as Map<String, dynamic>,
    );
  }

  Future<KidsRoom> updateRoom(
    String roomId, {
    String? name,
    int? capacity,
    String? description,
    int? minAgeMonths,
    int? maxAgeMonths,
    bool? isActive,
  }) async {
    final response = await _dio.patch(
      '/kids/rooms/$roomId',
      data: {
        'name': ?name,
        'capacity': ?capacity,
        'description': ?description,
        'minAgeMonths': ?minAgeMonths,
        'maxAgeMonths': ?maxAgeMonths,
        'isActive': ?isActive,
      },
    );
    return KidsRoom.fromJson(
      (response.data as Map<String, dynamic>)['room'] as Map<String, dynamic>,
    );
  }

  Future<void> deactivateRoom(String roomId) =>
      _dio.delete('/kids/rooms/$roomId');

  Future<KidsRoom> setTeachers(
    String roomId,
    List<({String userId, String role})> teachers,
  ) async {
    final response = await _dio.put(
      '/kids/rooms/$roomId/teachers',
      data: {
        'teachers': [
          for (final t in teachers) {'userId': t.userId, 'role': t.role},
        ],
      },
    );
    return KidsRoom.fromJson(
      (response.data as Map<String, dynamic>)['room'] as Map<String, dynamic>,
    );
  }

  // ── Sessões ───────────────────────────────────────────────────────────────

  /// Abre a aula. Se já houver sessão aberta na sala, o backend devolve a
  /// existente em vez de erro — dois professores tocando "abrir" é rotina.
  Future<KidsSession> openSession(
    String roomId, {
    required String serviceName,
    String? lesson,
  }) async {
    final response = await _dio.post(
      '/kids/rooms/$roomId/sessions',
      data: {
        'serviceName': serviceName,
        if (lesson != null && lesson.isNotEmpty) 'lesson': lesson,
      },
    );
    return KidsSession.fromJson(
      (response.data as Map<String, dynamic>)['session']
          as Map<String, dynamic>,
    );
  }

  Future<
    ({KidsSession session, List<KidsCheckin> checkins, List<KidsNote> notes})
  >
  getSession(String sessionId) async {
    final response = await _dio.get('/kids/sessions/$sessionId');
    final data = response.data as Map<String, dynamic>;
    return (
      session: KidsSession.fromJson(data['session'] as Map<String, dynamic>),
      checkins: (data['checkins'] as List? ?? [])
          .map((e) => KidsCheckin.fromJson(e as Map<String, dynamic>))
          .toList(),
      notes: (data['notes'] as List? ?? [])
          .map((e) => KidsNote.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<KidsSession>> listSessions({String? roomId, int? limit}) async {
    final response = await _dio.get(
      '/kids/sessions',
      queryParameters: {'roomId': ?roomId, 'limit': ?limit},
    );
    final list =
        (response.data as Map<String, dynamic>)['sessions'] as List? ?? [];
    return list
        .map((e) => KidsSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<KidsSession> updateSession(String sessionId, {String? lesson}) async {
    final response = await _dio.patch(
      '/kids/sessions/$sessionId',
      data: {'lesson': lesson},
    );
    return KidsSession.fromJson(
      (response.data as Map<String, dynamic>)['session']
          as Map<String, dynamic>,
    );
  }

  /// Fecha a sala. Falha com 409 e a lista de pendentes quando ainda há
  /// criança dentro — quem chama deve mostrar essa lista.
  Future<KidsSession> closeSession(String sessionId) async {
    final response = await _dio.post('/kids/sessions/$sessionId/close');
    return KidsSession.fromJson(
      (response.data as Map<String, dynamic>)['session']
          as Map<String, dynamic>,
    );
  }

  // ── Crianças ──────────────────────────────────────────────────────────────

  Future<List<KidsChild>> searchChildren(String query) async {
    final response = await _dio.get(
      '/kids/children/search',
      queryParameters: {'q': query},
    );
    final list =
        (response.data as Map<String, dynamic>)['children'] as List? ?? [];
    return list
        .map((e) => KidsChild.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<KidsChild> quickRegister({
    required String name,
    DateTime? birthDate,
    String? gender,
    String? allergies,
    String? medications,
    String? disabilities,
    String? authorizedPickup,
    required List<Map<String, dynamic>> guardians,
  }) async {
    final response = await _dio.post(
      '/kids/children/quick',
      data: {
        'name': name,
        if (birthDate != null) 'birthDate': birthDate.toIso8601String(),
        'gender': ?gender,
        if (allergies != null && allergies.isNotEmpty) 'allergies': allergies,
        if (medications != null && medications.isNotEmpty)
          'medications': medications,
        if (disabilities != null && disabilities.isNotEmpty)
          'disabilities': disabilities,
        if (authorizedPickup != null && authorizedPickup.isNotEmpty)
          'authorizedPickup': authorizedPickup,
        'guardians': guardians,
      },
    );
    return KidsChild.fromJson(
      (response.data as Map<String, dynamic>)['child'] as Map<String, dynamic>,
    );
  }

  Future<KidsChild> getChild(String childId) async {
    final response = await _dio.get('/kids/children/$childId');
    return KidsChild.fromJson(
      (response.data as Map<String, dynamic>)['child'] as Map<String, dynamic>,
    );
  }

  Future<List<KidsCheckin>> childHistory(String childId) async {
    final response = await _dio.get('/kids/children/$childId/history');
    final list =
        (response.data as Map<String, dynamic>)['history'] as List? ?? [];
    return list
        .map((e) => KidsCheckin.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<KidsNote>> childNotes(String childId) async {
    final response = await _dio.get('/kids/children/$childId/notes');
    final list =
        (response.data as Map<String, dynamic>)['notes'] as List? ?? [];
    return list
        .map((e) => KidsNote.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Check-in / check-out ──────────────────────────────────────────────────

  /// Consome o QR do responsável e devolve os filhos elegíveis. O token só
  /// pode ser lido uma vez — repetir a chamada com o mesmo QR falha.
  Future<List<KidsChild>> resolveQr(String qrToken) async {
    final response = await _dio.post(
      '/kids/checkins/resolve-qr',
      data: {'qrToken': qrToken},
    );
    final list =
        (response.data as Map<String, dynamic>)['children'] as List? ?? [];
    return list
        .map((e) => KidsChild.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<({List<KidsCheckinResult> checkins, int current, int capacity})>
  checkIn({
    required String sessionId,
    required List<String> childIds,
    String method = 'MANUAL',
    String? guardianId,
    bool force = false,
  }) async {
    final response = await _dio.post(
      '/kids/checkins',
      data: {
        'sessionId': sessionId,
        'childIds': childIds,
        'method': method,
        'guardianId': ?guardianId,
        if (force) 'force': true,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final occupancy = data['roomOccupancy'] as Map<String, dynamic>? ?? {};
    return (
      checkins: (data['checkins'] as List? ?? [])
          .map((e) => KidsCheckinResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      current: (occupancy['current'] as num?)?.toInt() ?? 0,
      capacity: (occupancy['capacity'] as num?)?.toInt() ?? 0,
    );
  }

  Future<KidsCheckin> checkOut(
    String checkinId, {
    String? qrToken,
    String? pickupCode,
    String? guardianName,
    String? reason,
  }) async {
    final response = await _dio.post(
      '/kids/checkins/$checkinId/checkout',
      data: {
        'qrToken': ?qrToken,
        'pickupCode': ?pickupCode,
        'guardianName': ?guardianName,
        'reason': ?reason,
      },
    );
    return KidsCheckin.fromJson(
      (response.data as Map<String, dynamic>)['checkin']
          as Map<String, dynamic>,
    );
  }

  /// Gera outra senha e invalida a anterior — para quando o pai perde o papel.
  Future<String> regenerateCode(String checkinId) async {
    final response = await _dio.post(
      '/kids/checkins/$checkinId/regenerate-code',
    );
    return (response.data as Map<String, dynamic>)['pickupCode'] as String;
  }

  // ── Anotações ─────────────────────────────────────────────────────────────

  Future<KidsNote> createNote({
    required String sessionId,
    required String kind,
    String? childId,
    String? checkinId,
    required String body,
    bool visibleToGuardian = true,
  }) async {
    final response = await _dio.post(
      '/kids/sessions/$sessionId/notes',
      data: {
        'kind': kind,
        'childId': ?childId,
        'checkinId': ?checkinId,
        'body': body,
        'visibleToGuardian': visibleToGuardian,
      },
    );
    return KidsNote.fromJson(
      (response.data as Map<String, dynamic>)['note'] as Map<String, dynamic>,
    );
  }

  // ── Alertas ───────────────────────────────────────────────────────────────

  Future<KidsAlert> createAlert({
    required String checkinId,
    required KidsAlertLevel level,
    required String message,
  }) async {
    final response = await _dio.post(
      '/kids/checkins/$checkinId/alerts',
      data: {'level': level.wire, 'message': message},
    );
    return KidsAlert.fromJson(
      (response.data as Map<String, dynamic>)['alert'] as Map<String, dynamic>,
    );
  }

  Future<List<KidsAlert>> listAlerts({
    String? status,
    String? sessionId,
  }) async {
    final response = await _dio.get(
      '/kids/alerts',
      queryParameters: {'status': ?status, 'sessionId': ?sessionId},
    );
    final list =
        (response.data as Map<String, dynamic>)['alerts'] as List? ?? [];
    return list
        .map((e) => KidsAlert.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<KidsAlert> resolveAlert(String alertId) async {
    final response = await _dio.post('/kids/alerts/$alertId/resolve');
    return KidsAlert.fromJson(
      (response.data as Map<String, dynamic>)['alert'] as Map<String, dynamic>,
    );
  }

  Future<KidsAlert> acknowledgeAlert(String alertId) async {
    final response = await _dio.post('/kids/alerts/$alertId/acknowledge');
    return KidsAlert.fromJson(
      (response.data as Map<String, dynamic>)['alert'] as Map<String, dynamic>,
    );
  }

  /// Registra que o professor discou — a entrega por telefone só existe quando
  /// alguém realmente ligou.
  Future<KidsAlert> registerCall(String alertId) async {
    final response = await _dio.post('/kids/alerts/$alertId/deliveries/call');
    return KidsAlert.fromJson(
      (response.data as Map<String, dynamic>)['alert'] as Map<String, dynamic>,
    );
  }

  // ── Responsável ───────────────────────────────────────────────────────────

  Future<({String token, int expiresIn})> myQr() async {
    final response = await _dio.get('/kids/my-qr');
    final data = response.data as Map<String, dynamic>;
    return (
      token: data['token'] as String,
      expiresIn: (data['expiresIn'] as num?)?.toInt() ?? 60,
    );
  }

  Future<List<KidsChild>> myChildren() async {
    final response = await _dio.get('/kids/my-children');
    final list =
        (response.data as Map<String, dynamic>)['children'] as List? ?? [];
    return list
        .map((e) => KidsChild.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<KidsAlert>> myAlerts() async {
    final response = await _dio.get('/kids/my-alerts');
    final list =
        (response.data as Map<String, dynamic>)['alerts'] as List? ?? [];
    return list
        .map((e) => KidsAlert.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Relatórios ────────────────────────────────────────────────────────────

  Future<KidsOverview> overview({DateTime? from, DateTime? to}) async {
    final response = await _dio.get(
      '/kids/reports/overview',
      queryParameters: {
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
      },
    );
    return KidsOverview.fromJson(
      (response.data as Map<String, dynamic>)['report'] as Map<String, dynamic>,
    );
  }
}
