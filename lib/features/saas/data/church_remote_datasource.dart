import 'package:dio/dio.dart';
import '../domain/church_context.dart';

/// Acesso HTTP às rotas SaaS (igreja, planos, billing, signup, super-admin).
class ChurchRemoteDatasource {
  final Dio _dio;
  ChurchRemoteDatasource(this._dio);

  Future<ChurchContext> getContext() async {
    final res = await _dio.get('/church/me');
    return ChurchContext.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ChurchInfo> updateChurch(Map<String, dynamic> data) async {
    final res = await _dio.patch('/church/me', data: data);
    return ChurchInfo.fromJson(res.data['church'] as Map<String, dynamic>);
  }

  /// Envia a logo (bytes) e retorna a URL assinada.
  Future<String> uploadLogo({
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'logo': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post('/church/me/logo', data: form);
    return res.data['logoUrl'] as String;
  }

  Future<List<PlanInfo>> listActivePlans() async {
    final res = await _dio.get('/plans');
    return (res.data['plans'] as List<dynamic>)
        .map((e) => PlanInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Rota pública (sem auth): todos os planos ativos + catálogo de features
  /// com rótulos amigáveis. Usado pro gating de UI (sidebar) descobrir a
  /// partir de qual plano uma feature bloqueada fica disponível.
  Future<({List<PlanInfo> plans, List<FeatureCatalogItem> catalog})>
  getPlansCatalog() async {
    final res = await _dio.get('/public/plans');
    final data = res.data as Map<String, dynamic>;
    final plans = (data['plans'] as List<dynamic>)
        .map((e) => PlanInfo.fromJson(e as Map<String, dynamic>))
        .toList();
    final catalog = (data['catalog'] as List<dynamic>)
        .map((e) => FeatureCatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return (plans: plans, catalog: catalog);
  }

  Future<String> createCheckout({
    required String planTier,
    required String billingCycle,
    required String customerName,
    required String customerEmail,
    String? taxId,
  }) async {
    final res = await _dio.post('/billing/checkout', data: {
      'planTier': planTier,
      'billingCycle': billingCycle,
      'customer': {
        'name': customerName,
        'email': customerEmail,
        if (taxId != null && taxId.isNotEmpty) 'taxId': taxId,
      },
    });
    return res.data['checkoutUrl'] as String;
  }

  // ── Signup público ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> signupChurch({
    required String churchName,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
    String planTier = 'FREE',
  }) async {
    final res = await _dio.post('/signup/church', data: {
      'churchName': churchName,
      'admin': {'name': adminName, 'email': adminEmail, 'password': adminPassword},
      'planTier': planTier,
    });
    return res.data as Map<String, dynamic>;
  }

  // ── Super-admin ───────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> listChurches() async {
    final res = await _dio.get('/admin/churches');
    return (res.data['churches'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> createChurch({
    required String churchName,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
    String planTier = 'FREE',
  }) async {
    await _dio.post('/admin/churches', data: {
      'churchName': churchName,
      'admin': {'name': adminName, 'email': adminEmail, 'password': adminPassword},
      'planTier': planTier,
    });
  }

  Future<void> assignPlan({
    required String churchId,
    required String planTier,
    String billingCycle = 'MONTHLY',
  }) async {
    await _dio.post('/admin/subscriptions/assign', data: {
      'churchId': churchId,
      'planTier': planTier,
      'billingCycle': billingCycle,
    });
  }

  Future<void> setChurchActive({
    required String churchId,
    required bool isActive,
  }) async {
    await _dio.patch('/admin/churches/$churchId/active', data: {'isActive': isActive});
  }

  Future<Map<String, dynamic>> getUsage() async {
    final res = await _dio.get('/admin/usage');
    return res.data as Map<String, dynamic>;
  }

  // ── Planos (super-admin CRUD) ─────────────────────────────────────────────
  Future<List<PlanInfo>> listAllPlans() async {
    final res = await _dio.get('/admin/plans');
    return (res.data['plans'] as List<dynamic>)
        .map((e) => PlanInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Catálogo de features com rótulos: [{key,label,description}].
  Future<List<FeatureCatalogItem>> getFeatureCatalog() async {
    final res = await _dio.get('/admin/features');
    return (res.data['catalog'] as List<dynamic>)
        .map((e) => FeatureCatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PlanInfo> upsertPlan({
    required String tier,
    required String name,
    String? description,
    required int priceMonth,
    required int priceYear,
    required List<String> features,
    required bool isActive,
  }) async {
    final res = await _dio.put('/admin/plans', data: {
      'tier': tier,
      'name': name,
      'description': description,
      'priceMonth': priceMonth,
      'priceYear': priceYear,
      'features': features,
      'isActive': isActive,
    });
    return PlanInfo.fromJson(res.data['plan'] as Map<String, dynamic>);
  }
}
