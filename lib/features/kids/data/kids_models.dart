/// Modelos do módulo Kids — espelham os payloads de `/v1/kids/*`.
///
/// Datas de sessão chegam como `date` do Postgres (meia-noite UTC); por isso a
/// leitura usa os componentes UTC, senão o dia volta um em fuso negativo.
library;

DateTime? _parseDateTime(String? iso) =>
    iso == null ? null : DateTime.tryParse(iso)?.toLocal();

DateTime _parseDayOnly(String? iso) {
  final parsed = DateTime.tryParse(iso ?? '');
  if (parsed == null) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
  final utc = parsed.toUtc();
  return DateTime(utc.year, utc.month, utc.day);
}

/// Situação de uma criança dentro da sala.
enum KidsCheckinStatus {
  checkedIn('CHECKED_IN', 'Na sala'),
  checkedOut('CHECKED_OUT', 'Retirada'),
  noShow('NO_SHOW', 'Não veio');

  const KidsCheckinStatus(this.wire, this.label);

  final String wire;
  final String label;

  static KidsCheckinStatus fromWire(String? value) => switch (value) {
    'CHECKED_OUT' => checkedOut,
    'NO_SHOW' => noShow,
    _ => checkedIn,
  };
}

/// Nível do alerta ao responsável. A escala é de urgência, e o nome sempre
/// acompanha a cor — cor sozinha não distingue "urgente" de "emergência".
enum KidsAlertLevel {
  info('INFO', 'Aviso'),
  urgent('URGENT', 'Urgente'),
  emergency('EMERGENCY', 'Emergência');

  const KidsAlertLevel(this.wire, this.label);

  final String wire;
  final String label;

  static KidsAlertLevel fromWire(String? value) => switch (value) {
    'URGENT' => urgent,
    'EMERGENCY' => emergency,
    _ => info,
  };
}

enum KidsAlertStatus {
  open('OPEN', 'Aberto'),
  acknowledged('ACKNOWLEDGED', 'Confirmado'),
  resolved('RESOLVED', 'Resolvido');

  const KidsAlertStatus(this.wire, this.label);

  final String wire;
  final String label;

  static KidsAlertStatus fromWire(String? value) => switch (value) {
    'ACKNOWLEDGED' => acknowledged,
    'RESOLVED' => resolved,
    _ => open,
  };
}

class KidsTeacher {
  const KidsTeacher({
    required this.userId,
    required this.name,
    required this.role,
  });

  factory KidsTeacher.fromJson(Map<String, dynamic> json) => KidsTeacher(
    userId: json['userId'] as String,
    name: json['name'] as String? ?? 'Sem nome',
    role: json['role'] as String? ?? 'AUXILIAR',
  );

  final String userId;
  final String name;
  final String role;

  bool get isTitular => role == 'TITULAR';
}

class KidsSession {
  const KidsSession({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.serviceDate,
    required this.serviceName,
    required this.status,
    required this.lesson,
    required this.capacity,
    required this.presentCount,
    required this.totalCheckins,
    required this.openAlerts,
    required this.openedAt,
    required this.closedAt,
  });

  factory KidsSession.fromJson(Map<String, dynamic> json) => KidsSession(
    id: json['id'] as String,
    roomId: json['roomId'] as String,
    roomName: json['roomName'] as String? ?? '',
    serviceDate: _parseDayOnly(json['serviceDate'] as String?),
    serviceName: json['serviceName'] as String? ?? 'Culto',
    status: json['status'] as String? ?? 'OPEN',
    lesson: json['lesson'] as String?,
    capacity: (json['capacity'] as num?)?.toInt() ?? 0,
    presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
    totalCheckins: (json['totalCheckins'] as num?)?.toInt() ?? 0,
    openAlerts: (json['openAlerts'] as num?)?.toInt() ?? 0,
    openedAt: _parseDateTime(json['openedAt'] as String?) ?? DateTime.now(),
    closedAt: _parseDateTime(json['closedAt'] as String?),
  );

  final String id;
  final String roomId;
  final String roomName;
  final DateTime serviceDate;
  final String serviceName;
  final String status;
  final String? lesson;
  final int capacity;
  final int presentCount;
  final int totalCheckins;
  final int openAlerts;
  final DateTime openedAt;
  final DateTime? closedAt;

  bool get isOpen => status == 'OPEN';

  double get occupancy => capacity == 0 ? 0 : presentCount / capacity;
}

class KidsRoom {
  const KidsRoom({
    required this.id,
    required this.name,
    required this.description,
    required this.capacity,
    required this.minAgeMonths,
    required this.maxAgeMonths,
    required this.color,
    required this.isActive,
    required this.teachers,
    required this.openSession,
  });

  factory KidsRoom.fromJson(Map<String, dynamic> json) => KidsRoom(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Sala',
    description: json['description'] as String?,
    capacity: (json['capacity'] as num?)?.toInt() ?? 0,
    minAgeMonths: (json['minAgeMonths'] as num?)?.toInt(),
    maxAgeMonths: (json['maxAgeMonths'] as num?)?.toInt(),
    color: json['color'] as String? ?? '#3F51B5',
    isActive: json['isActive'] as bool? ?? true,
    teachers: (json['teachers'] as List? ?? [])
        .map((e) => KidsTeacher.fromJson(e as Map<String, dynamic>))
        .toList(),
    openSession: json['openSession'] == null
        ? null
        : KidsSession.fromJson(json['openSession'] as Map<String, dynamic>),
  );

  final String id;
  final String name;
  final String? description;
  final int capacity;
  final int? minAgeMonths;
  final int? maxAgeMonths;
  final String color;
  final bool isActive;
  final List<KidsTeacher> teachers;
  final KidsSession? openSession;

  /// "4 a 6 anos" / "a partir de 6 meses" — vazio quando a sala não restringe.
  String get ageRangeLabel {
    String fmt(int months) =>
        months < 24 ? '$months meses' : '${(months / 12).floor()} anos';
    if (minAgeMonths == null && maxAgeMonths == null) return '';
    if (minAgeMonths != null && maxAgeMonths != null) {
      return '${fmt(minAgeMonths!)} a ${fmt(maxAgeMonths!)}';
    }
    if (minAgeMonths != null) return 'a partir de ${fmt(minAgeMonths!)}';
    return 'até ${fmt(maxAgeMonths!)}';
  }
}

/// Dados sensíveis da criança. Só chegam para quem tem a sala — a tela some
/// com eles ao fazer check-out.
class ChildHealth {
  const ChildHealth({
    this.allergies,
    this.medications,
    this.disabilities,
    this.medicalNotes,
  });

  factory ChildHealth.fromJson(Map<String, dynamic>? json) => ChildHealth(
    allergies: json?['allergies'] as String?,
    medications: json?['medications'] as String?,
    disabilities: json?['disabilities'] as String?,
    medicalNotes: json?['medicalNotes'] as String?,
  );

  final String? allergies;
  final String? medications;
  final String? disabilities;
  final String? medicalNotes;

  bool get isEmpty =>
      (allergies ?? '').isEmpty &&
      (medications ?? '').isEmpty &&
      (disabilities ?? '').isEmpty &&
      (medicalNotes ?? '').isEmpty;
}

class KidsGuardian {
  const KidsGuardian({
    required this.id,
    required this.name,
    required this.phone,
    required this.hasWhatsapp,
    required this.relation,
    required this.isPrimary,
    required this.canPickup,
    required this.userId,
  });

  factory KidsGuardian.fromJson(Map<String, dynamic> json) => KidsGuardian(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Responsável',
    phone: json['phone'] as String? ?? '',
    hasWhatsapp: json['hasWhatsapp'] as bool? ?? false,
    relation: json['relation'] as String? ?? 'RESPONSAVEL_LEGAL',
    isPrimary: json['isPrimary'] as bool? ?? false,
    canPickup: json['canPickup'] as bool? ?? true,
    userId: json['userId'] as String?,
  );

  final String id;
  final String name;
  final String phone;
  final bool hasWhatsapp;
  final String relation;
  final bool isPrimary;
  final bool canPickup;
  final String? userId;

  bool get hasApp => userId != null;

  String get relationLabel => switch (relation) {
    'PAI' => 'Pai',
    'MAE' => 'Mãe',
    'AVO' => 'Avô/avó',
    'TIO' => 'Tio/tia',
    'OUTRO' => 'Outro',
    _ => 'Responsável',
  };
}

class KidsChild {
  const KidsChild({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.authorizedPickup,
    required this.health,
    required this.guardians,
    required this.openCheckin,
  });

  factory KidsChild.fromJson(Map<String, dynamic> json) => KidsChild(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Sem nome',
    birthDate: _parseDateTime(json['birthDate'] as String?),
    gender: json['gender'] as String?,
    authorizedPickup: json['authorizedPickup'] as String?,
    health: ChildHealth.fromJson(json['health'] as Map<String, dynamic>?),
    guardians: (json['guardians'] as List? ?? [])
        .map((e) => KidsGuardian.fromJson(e as Map<String, dynamic>))
        .toList(),
    openCheckin: json['openCheckin'] == null
        ? null
        : KidsCheckin.fromJson(json['openCheckin'] as Map<String, dynamic>),
  );

  final String id;
  final String name;
  final DateTime? birthDate;
  final String? gender;
  final String? authorizedPickup;
  final ChildHealth health;
  final List<KidsGuardian> guardians;

  /// Check-in em aberto — indica em qual sala a criança está agora.
  final KidsCheckin? openCheckin;

  bool get isInRoom => openCheckin != null;

  KidsGuardian? get primaryGuardian {
    for (final g in guardians) {
      if (g.isPrimary) return g;
    }
    return guardians.isEmpty ? null : guardians.first;
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.map((p) => p[0].toUpperCase()).take(2).join();
  }

  /// "3 anos" ou "8 meses" — bebê precisa da idade em meses.
  String get ageLabel {
    if (birthDate == null) return 'Idade não informada';
    final now = DateTime.now();
    var months =
        (now.year - birthDate!.year) * 12 + now.month - birthDate!.month;
    if (now.day < birthDate!.day) months -= 1;
    if (months < 24) return '$months meses';
    return '${(months / 12).floor()} anos';
  }
}

class KidsCheckin {
  const KidsCheckin({
    required this.id,
    required this.sessionId,
    required this.childId,
    required this.childName,
    required this.status,
    required this.badgeCode,
    required this.checkinAt,
    required this.checkinMethod,
    required this.checkinGuardianName,
    required this.pickupCodeLast2,
    required this.hasPickupCode,
    required this.checkoutAt,
    required this.checkoutMethod,
    required this.checkoutGuardianName,
    required this.health,
    required this.openAlerts,
  });

  factory KidsCheckin.fromJson(Map<String, dynamic> json) => KidsCheckin(
    id: json['id'] as String,
    sessionId: json['sessionId'] as String? ?? '',
    childId: json['childId'] as String? ?? '',
    childName: json['childName'] as String? ?? 'Criança',
    status: KidsCheckinStatus.fromWire(json['status'] as String?),
    badgeCode: json['badgeCode'] as String? ?? '',
    checkinAt: _parseDateTime(json['checkinAt'] as String?) ?? DateTime.now(),
    checkinMethod: json['checkinMethod'] as String? ?? 'MANUAL',
    checkinGuardianName: json['checkinGuardianName'] as String?,
    pickupCodeLast2: json['pickupCodeLast2'] as String?,
    hasPickupCode: json['hasPickupCode'] as bool? ?? false,
    checkoutAt: _parseDateTime(json['checkoutAt'] as String?),
    checkoutMethod: json['checkoutMethod'] as String?,
    checkoutGuardianName: json['checkoutGuardianName'] as String?,
    health: ChildHealth.fromJson(json['health'] as Map<String, dynamic>?),
    openAlerts: (json['openAlerts'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String sessionId;
  final String childId;
  final String childName;
  final KidsCheckinStatus status;
  final String badgeCode;
  final DateTime checkinAt;
  final String checkinMethod;
  final String? checkinGuardianName;
  final String? pickupCodeLast2;
  final bool hasPickupCode;
  final DateTime? checkoutAt;
  final String? checkoutMethod;
  final String? checkoutGuardianName;
  final ChildHealth health;
  final int openAlerts;

  bool get isPresent => status == KidsCheckinStatus.checkedIn;
}

/// Resultado de um check-in — a senha vem aqui e em nenhum outro lugar.
class KidsCheckinResult {
  const KidsCheckinResult({
    required this.id,
    required this.childId,
    required this.childName,
    required this.badgeCode,
    required this.pickupCode,
    required this.healthFlags,
  });

  factory KidsCheckinResult.fromJson(Map<String, dynamic> json) =>
      KidsCheckinResult(
        id: json['id'] as String,
        childId: json['childId'] as String? ?? '',
        childName: json['childName'] as String? ?? '',
        badgeCode: json['badgeCode'] as String? ?? '',
        pickupCode: json['pickupCode'] as String?,
        healthFlags: (json['healthFlags'] as List? ?? []).cast<String>(),
      );

  final String id;
  final String childId;
  final String childName;
  final String badgeCode;

  /// `null` quando o responsável tem app: a retirada é pelo QR.
  final String? pickupCode;
  final List<String> healthFlags;
}

class KidsNote {
  const KidsNote({
    required this.id,
    required this.kind,
    required this.childId,
    required this.childName,
    required this.body,
    required this.visibleToGuardian,
    required this.authorName,
    required this.createdAt,
  });

  factory KidsNote.fromJson(Map<String, dynamic> json) => KidsNote(
    id: json['id'] as String,
    kind: json['kind'] as String? ?? 'CLASS',
    childId: json['childId'] as String?,
    childName: json['childName'] as String?,
    body: json['body'] as String? ?? '',
    visibleToGuardian: json['visibleToGuardian'] as bool? ?? true,
    authorName: json['authorName'] as String? ?? '',
    createdAt: _parseDateTime(json['createdAt'] as String?) ?? DateTime.now(),
  );

  final String id;
  final String kind;
  final String? childId;
  final String? childName;
  final String body;
  final bool visibleToGuardian;
  final String authorName;
  final DateTime createdAt;

  bool get isClassNote => kind == 'CLASS';
}

class KidsAlertDelivery {
  const KidsAlertDelivery({
    required this.channel,
    required this.status,
    required this.guardianName,
    required this.error,
  });

  factory KidsAlertDelivery.fromJson(Map<String, dynamic> json) =>
      KidsAlertDelivery(
        channel: json['channel'] as String? ?? '',
        status: json['status'] as String? ?? '',
        guardianName: json['guardianName'] as String?,
        error: json['error'] as String?,
      );

  final String channel;
  final String status;
  final String? guardianName;
  final String? error;

  String get channelLabel => switch (channel) {
    'PUSH' => 'Notificação',
    'CRITICAL_PUSH' => 'Notificação crítica',
    'WHATSAPP' => 'WhatsApp',
    'SMS' => 'SMS',
    'CALL' => 'Ligação',
    _ => channel,
  };

  String get statusLabel => switch (status) {
    'QUEUED' => 'Pendente',
    'SENT' => 'Enviado',
    'DELIVERED' => 'Entregue',
    'READ' => 'Lido',
    'FAILED' => 'Falhou',
    _ => status,
  };

  bool get isPendingCall => channel == 'CALL' && status == 'QUEUED';
}

class KidsAlert {
  const KidsAlert({
    required this.id,
    required this.roomName,
    required this.sessionClosed,
    required this.serviceDate,
    required this.childId,
    required this.childName,
    required this.checkinId,
    required this.level,
    required this.status,
    required this.message,
    required this.createdByName,
    required this.createdAt,
    required this.acknowledgedAt,
    required this.deliveries,
    required this.guardianPhones,
  });

  factory KidsAlert.fromJson(Map<String, dynamic> json) => KidsAlert(
    id: json['id'] as String,
    roomName: json['roomName'] as String? ?? '',
    sessionClosed: (json['sessionStatus'] as String?) == 'CLOSED',
    // `_parseDayOnly` e não `_parseDateTime`: `service_date` é `date` no banco
    // e chega como meia-noite UTC. Convertido para o fuso local vira 21h do dia
    // anterior, e o histórico agrupava o culto no sábado.
    serviceDate: json['serviceDate'] == null
        ? null
        : _parseDayOnly(json['serviceDate'] as String?),
    childId: json['childId'] as String? ?? '',
    childName: json['childName'] as String? ?? '',
    checkinId: json['checkinId'] as String?,
    level: KidsAlertLevel.fromWire(json['level'] as String?),
    status: KidsAlertStatus.fromWire(json['status'] as String?),
    message: json['message'] as String? ?? '',
    createdByName: json['createdByName'] as String? ?? '',
    createdAt: _parseDateTime(json['createdAt'] as String?) ?? DateTime.now(),
    acknowledgedAt: _parseDateTime(json['acknowledgedAt'] as String?),
    deliveries: (json['deliveries'] as List? ?? [])
        .map((e) => KidsAlertDelivery.fromJson(e as Map<String, dynamic>))
        .toList(),
    guardianPhones: (json['guardianPhones'] as List? ?? []).cast<String>(),
  );

  final String id;
  final String roomName;

  /// Sala já encerrada: o aviso é histórico, não pede mais ação do responsável.
  final bool sessionClosed;

  /// Dia do culto. Vem nulo em respostas antigas — use [day].
  final DateTime? serviceDate;

  final String childId;
  final String childName;
  final String? checkinId;
  final KidsAlertLevel level;
  final KidsAlertStatus status;
  final String message;
  final String createdByName;
  final DateTime createdAt;
  final DateTime? acknowledgedAt;
  final List<KidsAlertDelivery> deliveries;

  /// Telefones na ordem do backend: responsável primário primeiro.
  final List<String> guardianPhones;

  bool get needsCall => deliveries.any((d) => d.isPendingCall);

  /// Dia a que o aviso pertence, para agrupar o histórico.
  DateTime get day => serviceDate ?? createdAt;

  /// Ainda pede atenção: sala aberta e aviso não resolvido. É o que fica na
  /// home; todo o resto vive no histórico.
  bool get isLive => !sessionClosed && status != KidsAlertStatus.resolved;
}

/// Relatório do ministério — a igreja que assina só o Kids não tem o dashboard
/// da suíte, então este é o painel dela.
class KidsOverview {
  const KidsOverview({
    required this.sessions,
    required this.checkins,
    required this.uniqueChildren,
    required this.averagePerSession,
    required this.alerts,
    required this.rooms,
  });

  factory KidsOverview.fromJson(Map<String, dynamic> json) => KidsOverview(
    sessions: (json['sessions'] as num?)?.toInt() ?? 0,
    checkins: (json['checkins'] as num?)?.toInt() ?? 0,
    uniqueChildren: (json['uniqueChildren'] as num?)?.toInt() ?? 0,
    averagePerSession: (json['averagePerSession'] as num?)?.toDouble() ?? 0,
    alerts: {
      for (final a in (json['alerts'] as List? ?? []))
        KidsAlertLevel.fromWire(
          (a as Map<String, dynamic>)['level'] as String?,
        ): (a['count'] as num?)?.toInt() ?? 0,
    },
    rooms: (json['rooms'] as List? ?? [])
        .map((e) => KidsRoomStat.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final int sessions;
  final int checkins;
  final int uniqueChildren;
  final double averagePerSession;
  final Map<KidsAlertLevel, int> alerts;
  final List<KidsRoomStat> rooms;
}

class KidsRoomStat {
  const KidsRoomStat({
    required this.roomId,
    required this.roomName,
    required this.capacity,
    required this.sessions,
    required this.checkins,
    required this.averageOccupancy,
  });

  factory KidsRoomStat.fromJson(Map<String, dynamic> json) => KidsRoomStat(
    roomId: json['roomId'] as String,
    roomName: json['roomName'] as String? ?? '',
    capacity: (json['capacity'] as num?)?.toInt() ?? 0,
    sessions: (json['sessions'] as num?)?.toInt() ?? 0,
    checkins: (json['checkins'] as num?)?.toInt() ?? 0,
    averageOccupancy: (json['averageOccupancy'] as num?)?.toDouble() ?? 0,
  );

  final String roomId;
  final String roomName;
  final int capacity;
  final int sessions;
  final int checkins;
  final double averageOccupancy;
}
