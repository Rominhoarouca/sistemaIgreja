import 'package:flutter_map/flutter_map.dart';

/// Identificador enviado no `User-Agent` das requisições de tile.
///
/// Tem que ser o bundle id real do app: a política de uso dos tiles do
/// OpenStreetMap exige um User-Agent que identifique a aplicação, e o
/// placeholder `com.example.app` que estava espalhado pelas telas é
/// justamente o que faz o servidor responder "Access blocked — app is not
/// following the tile usage policy" (o mapa vinha em branco no iOS).
const String kMapUserAgentPackageName = 'br.com.multiplicado';

/// Camada de tiles padrão do app. Use sempre esta função em vez de montar um
/// [TileLayer] na mão, para o User-Agent não voltar a divergir entre telas.
TileLayer appTileLayer() => TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: kMapUserAgentPackageName,
  // O OSM não publica tiles acima de z19.
  maxNativeZoom: 19,
);
