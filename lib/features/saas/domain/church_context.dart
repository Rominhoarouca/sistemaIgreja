import 'package:flutter/material.dart';

/// Dados da igreja (tenant) do usuário logado.
class ChurchInfo {
  final String id;
  final String name;
  final String slug;
  final String? address;
  final String? site;
  final String? instagram;
  final String? youtube;
  final String? tiktok;
  final String? logoUrl;
  final String menuColorHex;
  final bool isActive;

  const ChurchInfo({
    required this.id,
    required this.name,
    required this.slug,
    required this.menuColorHex,
    required this.isActive,
    this.address,
    this.site,
    this.instagram,
    this.youtube,
    this.tiktok,
    this.logoUrl,
  });

  Color get menuColor => _hexToColor(menuColorHex);

  factory ChurchInfo.fromJson(Map<String, dynamic> json) => ChurchInfo(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    address: json['address'] as String?,
    site: json['site'] as String?,
    instagram: json['instagram'] as String?,
    youtube: json['youtube'] as String?,
    tiktok: json['tiktok'] as String?,
    logoUrl: json['logoUrl'] as String?,
    menuColorHex: json['menuColor'] as String? ?? '#3F51B5',
    isActive: json['isActive'] as bool? ?? true,
  );
}

class PlanInfo {
  final String id;
  final String tier;
  final String name;
  final String? description;
  final int priceMonth; // centavos
  final int priceYear; // centavos
  final List<String> features;

  const PlanInfo({
    required this.id,
    required this.tier,
    required this.name,
    required this.priceMonth,
    required this.priceYear,
    required this.features,
    this.description,
  });

  factory PlanInfo.fromJson(Map<String, dynamic> json) => PlanInfo(
    id: json['id'] as String,
    tier: json['tier'] as String,
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    priceMonth: (json['priceMonth'] as num?)?.toInt() ?? 0,
    priceYear: (json['priceYear'] as num?)?.toInt() ?? 0,
    features: (json['features'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList(),
  );

  String get priceMonthLabel => priceMonth == 0
      ? 'Grátis'
      : 'R\$ ${(priceMonth / 100).toStringAsFixed(2)}/mês';
}

/// Contexto multi-tenant: igreja + plano + features ativas.
class ChurchContext {
  final ChurchInfo church;
  final PlanInfo? plan;
  final String? subscriptionStatus;
  final List<String> features;

  const ChurchContext({
    required this.church,
    required this.features,
    this.plan,
    this.subscriptionStatus,
  });

  factory ChurchContext.fromJson(Map<String, dynamic> json) => ChurchContext(
    church: ChurchInfo.fromJson(json['church'] as Map<String, dynamic>),
    plan: json['plan'] != null
        ? PlanInfo.fromJson(json['plan'] as Map<String, dynamic>)
        : null,
    subscriptionStatus: json['subscriptionStatus'] as String?,
    features: (json['features'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList(),
  );
}

/// Item do catálogo de features (chave + rótulo amigável) vindo do backend.
class FeatureCatalogItem {
  final String key;
  final String label;
  final String description;

  const FeatureCatalogItem({
    required this.key,
    required this.label,
    required this.description,
  });

  factory FeatureCatalogItem.fromJson(Map<String, dynamic> json) =>
      FeatureCatalogItem(
        key: json['key'] as String,
        label: json['label'] as String? ?? json['key'] as String,
        description: json['description'] as String? ?? '',
      );
}

/// Chaves de feature (espelham o backend `shared/plans/features.ts`).
abstract final class AppFeatures {
  static const spiritualHistory = 'spiritual_history';
  static const coordenacao = 'coordenacao';
  static const materials = 'materials';
  static const mapGeolocation = 'map_geolocation';
  static const advancedDashboard = 'advanced_dashboard';
  static const whatsapp = 'whatsapp';
  static const kids = 'kids';
}

Color _hexToColor(String hex) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final value = int.tryParse(h, radix: 16) ?? 0xFF3F51B5;
  return Color(value);
}
