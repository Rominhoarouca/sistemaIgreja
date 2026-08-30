/// Nível do nó no álbum. Espelha a cadeia de gestão da igreja.
///
/// [lider] ocupa o mesmo degrau de [supervisao]: é o líder que responde direto
/// à coordenação, sem supervisor no meio.
enum AlbumLevel {
  coordenacao,
  supervisao,
  lider,
  celula;

  static AlbumLevel fromString(String value) => switch (value) {
    'COORDENACAO' => AlbumLevel.coordenacao,
    'SUPERVISAO' => AlbumLevel.supervisao,
    'LIDER' => AlbumLevel.lider,
    _ => AlbumLevel.celula,
  };

  String get label => switch (this) {
    AlbumLevel.coordenacao => 'Coordenação',
    AlbumLevel.supervisao => 'Supervisão',
    AlbumLevel.lider => 'Líder',
    AlbumLevel.celula => 'Célula',
  };

  String get plural => switch (this) {
    AlbumLevel.coordenacao => 'Coordenações',
    AlbumLevel.supervisao => 'Supervisões',
    AlbumLevel.lider => 'Líderes',
    AlbumLevel.celula => 'Células',
  };
}

class AlbumPhoto {
  const AlbumPhoto({
    required this.url,
    required this.cellId,
    required this.cellName,
    this.leaderName,
    this.lesson,
  });

  final String url;
  final String cellId;
  final String cellName;
  final String? leaderName;
  final String? lesson;

  factory AlbumPhoto.fromJson(Map<String, dynamic> j) => AlbumPhoto(
    url: j['url'] as String? ?? '',
    cellId: j['cellId'] as String? ?? '',
    cellName: j['cellName'] as String? ?? '',
    leaderName: j['leaderName'] as String?,
    lesson: j['lesson'] as String?,
  );
}

/// Um grupo do álbum (coordenação, supervisão ou célula).
///
/// `coverPhotos` alimenta a montagem; `children` é o carrossel do nível
/// seguinte. Quando não há filhos (nível célula), o carrossel são as próprias
/// [photos].
class AlbumNode {
  const AlbumNode({
    required this.id,
    required this.name,
    required this.level,
    required this.photoCount,
    required this.coverPhotos,
    required this.photos,
    required this.children,
    this.color,
  });

  final String id;
  final String name;
  final AlbumLevel level;
  final int photoCount;
  final List<String> coverPhotos;
  final List<AlbumPhoto> photos;
  final List<AlbumNode> children;
  final String? color;

  bool get hasChildren => children.isNotEmpty;

  factory AlbumNode.fromJson(Map<String, dynamic> j) => AlbumNode(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    level: AlbumLevel.fromString(j['level'] as String? ?? 'CELULA'),
    photoCount: (j['photoCount'] as num?)?.toInt() ?? 0,
    color: j['color'] as String?,
    coverPhotos: ((j['coverPhotos'] as List?) ?? const [])
        .map((e) => e as String)
        .toList(),
    photos: ((j['photos'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(AlbumPhoto.fromJson)
        .toList(),
    children: ((j['children'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(AlbumNode.fromJson)
        .toList(),
  );
}

class AlbumDay {
  const AlbumDay({
    required this.date,
    required this.photoCount,
    required this.coverPhotos,
  });

  /// `YYYY-MM-DD` — chave usada na rota do dia.
  final String date;
  final int photoCount;
  final List<String> coverPhotos;

  factory AlbumDay.fromJson(Map<String, dynamic> j) => AlbumDay(
    date: j['date'] as String? ?? '',
    photoCount: (j['photoCount'] as num?)?.toInt() ?? 0,
    coverPhotos: ((j['coverPhotos'] as List?) ?? const [])
        .map((e) => e as String)
        .toList(),
  );
}

class AlbumDayView {
  const AlbumDayView({
    required this.date,
    required this.rootLevel,
    required this.photoCount,
    required this.groups,
  });

  final String date;
  final AlbumLevel rootLevel;
  final int photoCount;
  final List<AlbumNode> groups;

  factory AlbumDayView.fromJson(Map<String, dynamic> j) => AlbumDayView(
    date: j['date'] as String? ?? '',
    rootLevel: AlbumLevel.fromString(j['rootLevel'] as String? ?? 'CELULA'),
    photoCount: (j['photoCount'] as num?)?.toInt() ?? 0,
    groups: ((j['groups'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(AlbumNode.fromJson)
        .toList(),
  );

  /// Todas as fotos do dia — usada na montagem do topo enquanto nenhum grupo
  /// foi aberto.
  List<String> get allCovers => [
    for (final g in groups) ...g.coverPhotos,
  ];
}
