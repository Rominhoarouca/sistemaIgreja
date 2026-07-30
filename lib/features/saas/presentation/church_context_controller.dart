import 'dart:async';

import 'package:flutter/material.dart';
import '../data/church_remote_datasource.dart';
import '../domain/church_context.dart';

/// Estado global do tenant (igreja): dados, plano, features e cor do menu.
/// Singleton no estilo do [ThemeController] — dirige tema dinâmico + gating de UI.
class ChurchContextController extends ChangeNotifier {
  ChurchContextController._();
  static final ChurchContextController instance = ChurchContextController._();

  ChurchRemoteDatasource? _datasource;
  void attachDatasource(ChurchRemoteDatasource ds) => _datasource = ds;

  ChurchContext? _context;
  ChurchContext? get context => _context;

  bool _loading = false;
  bool get loading => _loading;

  ChurchInfo? get church => _context?.church;
  PlanInfo? get plan => _context?.plan;
  List<String> get features => _context?.features ?? const [];

  /// Cor do menu da igreja (fallback azul do design system).
  Color get menuColor => _context?.church.menuColor ?? const Color(0xFF3F51B5);

  bool hasFeature(String key) => features.contains(key);

  // ── Catálogo de planos (gating de UI) ───────────────────────────────────
  static const _tierOrder = ['FREE', 'STARTER', 'GROWTH', 'COMPLETE'];

  List<PlanInfo> _allPlans = const [];
  List<FeatureCatalogItem> _catalog = const [];

  /// Menor plano (por tier) que inclui [featureKey] — null se nenhum plano
  /// ativo a inclui ainda.
  PlanInfo? minPlanForFeature(String featureKey) {
    final candidates = _allPlans.where((p) => p.features.contains(featureKey)).toList()
      ..sort(
        (a, b) => _tierOrder.indexOf(a.tier).compareTo(_tierOrder.indexOf(b.tier)),
      );
    return candidates.isEmpty ? null : candidates.first;
  }

  FeatureCatalogItem? featureCatalogItem(String key) {
    for (final c in _catalog) {
      if (c.key == key) return c;
    }
    return null;
  }

  Future<void> _loadPlanCatalog() async {
    if (_datasource == null) return;
    try {
      final result = await _datasource!.getPlansCatalog();
      _allPlans = result.plans;
      _catalog = result.catalog;
      notifyListeners();
    } catch (_) {
      // Catálogo é auxiliar (só usado pro dialog de upgrade) — falha silenciosa.
    }
  }

  Future<void> load() async {
    if (_datasource == null) return;
    _loading = true;
    notifyListeners();
    try {
      _context = await _datasource!.getContext();
      // Rota pública, independe do contexto da igreja — carrega em paralelo.
      unawaited(_loadPlanCatalog());
    } catch (_) {
      // Mantém contexto anterior; falha silenciosa (ex.: superadmin sem igreja).
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Atualiza localmente após edição da igreja (evita novo round-trip).
  void updateChurchLocal(ChurchInfo church) {
    if (_context == null) {
      _context = ChurchContext(church: church, features: const []);
    } else {
      _context = ChurchContext(
        church: church,
        plan: _context!.plan,
        subscriptionStatus: _context!.subscriptionStatus,
        features: _context!.features,
      );
    }
    notifyListeners();
  }

  void reset() {
    _context = null;
    notifyListeners();
  }
}
