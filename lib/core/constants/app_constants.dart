import 'package:flutter/foundation.dart' show kIsWeb;

/// App-wide string constants
abstract final class AppConstants {
  // ── API ──────────────────────────────────────────────────────────────────
  // iOS Simulator: 127.0.0.1:3000  |  Android Emulator: 10.0.2.2:3000
  // Produção: passe --dart-define=API_BASE_URL=https://seu-dominio.com/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.0.190/v1',
    //defaultValue: 'http://127.0.0.1:3000/v1',
  );

  /// Origem pública do app (sem `/v1`), usada para montar os links dos QR
  /// Codes de cadastro. No web usa a origem real da página aberta; fora dele
  /// deriva de [baseUrl], que aponta para `<origem>/v1`.
  static String get publicAppOrigin {
    if (kIsWeb) return Uri.base.origin;
    final api = Uri.parse(baseUrl);
    return '${api.scheme}://${api.authority}';
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ── Storage keys ─────────────────────────────────────────────────────────
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'auth_refresh_token';
  static const String userProfileKey = 'user_profile';
  static const String themeKey = 'app_theme';

  // ── Pagination ────────────────────────────────────────────────────────────
  static const int defaultPageSize = 20;

  // ── User roles ────────────────────────────────────────────────────────────
  static const String roleAdmin = 'ADMIN';
  static const String roleLeader = 'LIDER';
  static const String roleSupervisor = 'SUPERVISOR';
  static const String roleVisitor = 'VISITANTE';

  // ── Visitor statuses ──────────────────────────────────────────────────────
  static const String statusNew = 'novo';
  static const String statusFollowing = 'em_acompanhamento';
  static const String statusIntegrated = 'integrado';
  static const String statusInactive = 'inativo';

  // ── Referral statuses ─────────────────────────────────────────────────────
  static const String referralPending = 'pendente';
  static const String referralContacted = 'contatado';
  static const String referralIntegrated = 'integrado';

  // ── Geolocation ───────────────────────────────────────────────────────────
  static const double searchRadiusKm = 10.0;

  // ── File upload ───────────────────────────────────────────────────────────
  static const List<String> allowedMaterialExtensions = [
    'pdf',
    'docx',
    'ppt',
    'pptx',
    'mp4',
    'mov',
  ];
  static const int maxFileSizeMb = 50;
}

/// Route name constants
abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';

  // Visitor
  static const String visitorRegister = '/visitor/register';
  static const String visitorSelfRegister = '/cadastro';
  static const String nearbyCells = '/visitor/cells';
  static const String cellDetail = '/cells/:id';

  // Leader
  static const String leaderHome = '/leader';
  static const String leaderVisitors = '/leader/visitors';
  static const String visitorDetail = '/leader/visitors/:id';
  static const String attendance = '/leader/attendance';
  static const String materials = '/leader/materials';

  // Supervisor
  static const String supervisorHome = '/supervisor';

  // Coordenador
  static const String coordinatorHome = '/coordinator';

  // Admin
  static const String adminDashboard = '/admin';
  static const String adminVisitors = '/admin/visitors';
  static const String adminCells = '/admin/cells';
  static const String adminLeaders = '/admin/leaders';
  static const String adminSupervisors = '/admin/supervisors';
  static const String adminCoordenacoes = '/admin/coordenacoes';
  static const String adminLocation = '/admin/location';
  static const String adminReports = '/admin/reports';
  static const String adminMaterials = '/admin/materials';
  static const String adminCellTypes = '/admin/cell-types';
  static const String adminWhatsapp = '/admin/whatsapp';
  static const String adminUsersRegister = '/admin/users/register';
  static const String adminChurch = '/admin/church';
  static const String adminQrCode = '/admin/qrcode';

  // Líder — sob /leader para herdar o guard de papel do router.
  static const String leaderQrCode = '/leader/qrcode';

  // Kids — equipe do ministério infantil (professor e admin).
  static const String kidsHome = '/kids';
  static const String kidsScan = '/kids/scan';
  static const String kidsSession = '/kids/sessions/:id';
  static const String kidsChild = '/kids/children/:id';
  static const String adminKidsRooms = '/admin/kids/rooms';
  static const String adminKidsReports = '/admin/kids/reports';

  // Kids — responsável (app do pai).
  static const String guardianHome = '/meus-filhos';
  static const String guardianQrCode = '/meus-filhos/qrcode';
  static const String guardianAlerts = '/meus-filhos/alertas';

  // SaaS
  static const String signup = '/signup';
  static const String superAdmin = '/superadmin';
  static const String superAdminPlans = '/superadmin/plans';
}
