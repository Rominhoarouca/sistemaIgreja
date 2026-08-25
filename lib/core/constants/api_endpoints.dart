/// Catálogo único das rotas da API.
///
/// Regra da arquitetura: nenhum literal de endpoint fora deste arquivo.
/// Datasources montam URLs exclusivamente daqui. Paths relativos assumem o
/// baseUrl do Dio (`AppConstants.baseUrl`, já com `/v1`).
abstract class ApiEndpoints {
  // ── Auth ──────────────────────────────────────────────────────────────
  static const String authLogin = '/auth/login';
  static const String authRegister = '/auth/register';
  static const String authRefresh = '/auth/refresh';
  static const String authMe = '/auth/me';

  // ── Users ─────────────────────────────────────────────────────────────
  static const String usersMe = '/users/me';
  static const String usersLeaders = '/users/leaders';
  static const String usersSupervisors = '/users/supervisors';

  /// Grafia "coordinadores" é typo consolidado do backend — não corrigir só
  /// de um lado.
  static const String usersCoordinators = '/users/coordinadores';
  static const String usersMyLeaders = '/users/my-leaders';
  static const String usersMySupervisors = '/users/my-supervisors';
  static const String usersSearch = '/users/search';
  static const String usersCreate = '/users/create';
  static String userPassword(String userId) => '/users/$userId/password';
  static String leaderSupervisor(String leaderId) =>
      '/users/leaders/$leaderId/supervisor';
  static String leaderPromote(String leaderId) =>
      '/users/leaders/$leaderId/promote';
  static String leaderById(String leaderId) => '/users/leaders/$leaderId';
  static String supervisorCoordenacao(String supervisorId) =>
      '/users/supervisors/$supervisorId/coordenacao';

  // ── Cells ─────────────────────────────────────────────────────────────
  static const String cells = '/cells';
  static const String myCell = '/cells/my-cell';
  static String cellById(String id) => '/cells/$id';
  static String cellMembers(String cellId) => '/cells/$cellId/members';

  // ── Cell types ────────────────────────────────────────────────────────
  static const String cellTypes = '/cell-types';
  static String cellTypeById(String id) => '/cell-types/$id';

  // ── Visitors ──────────────────────────────────────────────────────────
  static const String visitors = '/visitors';
  static const String visitorSelfRegister = '/visitors/self-register';
  static String visitorById(String id) => '/visitors/$id';

  // ── Attendance ────────────────────────────────────────────────────────
  static const String attendance = '/attendance';
  static String cellMeetings(String cellId) =>
      '/attendance/cell/$cellId/meetings';
  static String cellAttendees(String cellId) =>
      '/attendance/cell/$cellId/attendees';
  static String meetingPhoto(String cellId, String meetingDateIso) =>
      '/attendance/cell/$cellId/meetings/${Uri.encodeComponent(meetingDateIso)}/photo';

  // ── Spiritual history ─────────────────────────────────────────────────
  static const String spiritualHistory = '/spiritual-history';
  static String spiritualHistoryByCell(String cellId) =>
      '/spiritual-history/cell/$cellId';

  // ── Materials ─────────────────────────────────────────────────────────
  static const String materials = '/materials';
  static String materialById(String id) => '/materials/$id';
  static String materialDownloadUrl(String id) => '/materials/$id/download-url';

  // ── Notifications ─────────────────────────────────────────────────────
  static const String notifications = '/notifications';
  static const String notificationsAdmin = '/notifications/admin';
  static const String notificationsReadAll = '/notifications/read-all';
  static String notificationById(String id) => '/notifications/$id';
  static String notificationAdminById(String id) => '/notifications/admin/$id';
  static String notificationRead(String id) => '/notifications/$id/read';

  // ── Coordenações ──────────────────────────────────────────────────────
  static const String coordenacoes = '/coordenacoes';
  static String coordenacaoById(String id) => '/coordenacoes/$id';

  // ── Location ──────────────────────────────────────────────────────────
  static const String locationEstados = '/location/estados';
  static String locationCidades(String estadoId) =>
      '/location/estados/$estadoId/cidades';
  static String locationCidadeById(String cidadeId) =>
      '/location/cidades/$cidadeId';
  static String locationBairros(String cidadeId) =>
      '/location/cidades/$cidadeId/bairros';
  static String locationBairroById(String bairroId) =>
      '/location/bairros/$bairroId';

  // ── Dashboard ─────────────────────────────────────────────────────────
  static const String dashboardStats = '/dashboard/stats';
  static const String dashboardMonthlyStats = '/dashboard/monthly-stats';
  static const String dashboardDemographics = '/dashboard/demographics';
  static const String dashboardAttendanceByCell = '/dashboard/attendance-by-cell';

  // ── SaaS: church / planos / billing ───────────────────────────────────
  static const String churchMe = '/church/me';
  static const String churchLogo = '/church/me/logo';
  static String churchPublic(String slug) => '/church/public/$slug';
  static const String signupChurch = '/signup/church';
  static const String publicPlans = '/public/plans';
  static const String plans = '/plans';
  static const String billingCheckout = '/billing/checkout';

  // ── SaaS: super-admin ─────────────────────────────────────────────────
  static const String adminChurches = '/admin/churches';
  static String adminChurchActive(String churchId) =>
      '/admin/churches/$churchId/active';
  static const String adminPlans = '/admin/plans';
  static const String adminFeatures = '/admin/features';
  static const String adminUsage = '/admin/usage';
  static const String adminSubscriptionsAssign = '/admin/subscriptions/assign';

  // ── Serviços externos (Dio próprio, sem auth) ─────────────────────────
  static String viaCep(String cleanedCep) =>
      'https://viacep.com.br/ws/$cleanedCep/json/';
  static const String nominatimSearch =
      'https://nominatim.openstreetmap.org/search';
}
