import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/auth_storage.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../saas/domain/church_context.dart';
import '../../../saas/presentation/church_context_controller.dart';
import '../../../saas/presentation/widgets/feature_locked_dialog.dart';

/// Item de navegação da sidebar.
class _SidebarItem {
  const _SidebarItem(
    this.icon,
    this.label,
    this.location, {
    this.badge,
    this.lockedFeature,
  });

  final IconData icon;
  final String label;

  /// Location completa (path + query) usada com `context.go`.
  final String location;

  /// Contador opcional (ex.: visitantes novos).
  final int? badge;

  /// Chave da feature (catálogo de planos) quando o item está bloqueado
  /// pelo plano atual da igreja — null quando liberado.
  final String? lockedFeature;

  _SidebarItem withBadge(int? value) => _SidebarItem(
    icon,
    label,
    location,
    badge: value,
    lockedFeature: lockedFeature,
  );

  _SidebarItem withLock(String? feature) =>
      _SidebarItem(icon, label, location, badge: badge, lockedFeature: feature);
}

class _SidebarGroup {
  const _SidebarGroup(this.label, this.items);

  final String label;
  final List<_SidebarItem> items;
}

/// Sidebar 252px com gradiente navy — shell web/desktop do admin.
/// Grupos: Início / Pessoas / Células / Sistema. Item ativo com fundo
/// dourado translúcido. Card do usuário no rodapé.
class AdminSidebar extends StatefulWidget {
  const AdminSidebar({super.key});

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar> {
  /// Contador exibido no item "Visitantes" (visitantes com status "novo").
  int? visitorBadge;

  @override
  void initState() {
    super.initState();
    _loadVisitorBadge();
    // Rebuild quando o contexto da igreja (features/plano) carregar/mudar.
    ChurchContextController.instance.addListener(_onChurchContext);
  }

  @override
  void dispose() {
    ChurchContextController.instance.removeListener(_onChurchContext);
    super.dispose();
  }

  void _onChurchContext() {
    if (mounted) setState(() {});
  }

  /// Marca itens de recursos não incluídos no plano da igreja como
  /// bloqueados (ficam visíveis, porém desabilitados — clique abre o
  /// dialog de upgrade em vez de navegar).
  List<_SidebarGroup> _applyGating(List<_SidebarGroup> groups) {
    const gated = <String, String>{
      AppRoutes.adminMaterials: AppFeatures.materials,
      AppRoutes.adminCoordenacoes: AppFeatures.coordenacao,
      AppRoutes.adminWhatsapp: AppFeatures.whatsapp,
    };
    final ctrl = ChurchContextController.instance;
    // Sem contexto carregado ainda: não bloqueia nada (evita flicker).
    if (ctrl.context == null) return groups;
    return groups
        .map(
          (g) => _SidebarGroup(
            g.label,
            g.items.map((it) {
              final feature = gated[it.location];
              final locked = feature != null && !ctrl.hasFeature(feature);
              return locked ? it.withLock(feature) : it;
            }).toList(),
          ),
        )
        .toList();
  }

  /// Logo da igreja (tenant), com fallback pro logo padrão do app quando a
  /// igreja ainda não enviou uma logo própria ou o download falha.
  Widget _brandLogo() {
    final logoUrl = ChurchContextController.instance.church?.logoUrl;
    const fallback = Image(
      image: AssetImage('assets/images/logo.png'),
      width: 36,
      height: 36,
      fit: BoxFit.cover,
    );
    if (logoUrl == null || logoUrl.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: logoUrl,
      width: 36,
      height: 36,
      fit: BoxFit.cover,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }

  Future<void> _loadVisitorBadge() async {
    try {
      final dio = DioClient(AuthStorage()).dio;
      final resp = await dio.get('/visitors');
      final data = ((resp.data as Map<String, dynamic>)['data'] as List)
          .cast<Map<String, dynamic>>();
      final novos = data
          .where((v) => (v['status'] as String? ?? 'novo') == 'novo')
          .length;
      if (mounted) setState(() => visitorBadge = novos);
    } catch (_) {
      // Badge é opcional — silencia falha de rede.
    }
  }

  List<_SidebarGroup> _groups() => [
    _SidebarGroup('Início', [
      const _SidebarItem(
        Icons.grid_view_rounded,
        'Visão geral',
        '${AppRoutes.adminDashboard}?tab=0',
      ),
      const _SidebarItem(
        Icons.insert_chart_outlined_rounded,
        'Relatórios',
        '${AppRoutes.adminDashboard}?tab=3',
      ),
      const _SidebarItem(
        Icons.notifications_none_rounded,
        'Notificações',
        '/notifications',
      ),
      const _SidebarItem(
        Icons.folder_open_rounded,
        'Materiais',
        AppRoutes.adminMaterials,
      ),
    ]),
    _SidebarGroup('Pessoas', [
      _SidebarItem(
        Icons.people_alt_outlined,
        'Visitantes',
        '${AppRoutes.adminDashboard}?tab=1',
        badge: visitorBadge,
      ),
      const _SidebarItem(
        Icons.record_voice_over_outlined,
        'Líderes',
        AppRoutes.adminLeaders,
      ),
      const _SidebarItem(
        Icons.supervisor_account_outlined,
        'Supervisores',
        AppRoutes.adminSupervisors,
      ),
      const _SidebarItem(
        Icons.person_add_alt_outlined,
        'Novo Cadastro',
        AppRoutes.adminUsersRegister,
      ),
      const _SidebarItem(
        Icons.qr_code_2_outlined,
        'QR Code de cadastro',
        AppRoutes.adminQrCode,
      ),
    ]),
    _SidebarGroup('Células', [
      const _SidebarItem(
        Icons.groups_2_outlined,
        'Células',
        '${AppRoutes.adminDashboard}?tab=2',
      ),
      const _SidebarItem(
        Icons.category_outlined,
        'Tipos de Célula',
        AppRoutes.adminCellTypes,
      ),
      const _SidebarItem(
        Icons.hub_outlined,
        'Coordenações',
        AppRoutes.adminCoordenacoes,
      ),
    ]),
    _SidebarGroup('Sistema', [
      const _SidebarItem(
        Icons.chat_outlined,
        'WhatsApp',
        AppRoutes.adminWhatsapp,
      ),
      const _SidebarItem(
        Icons.location_city_outlined,
        'Cidades e Bairros',
        AppRoutes.adminLocation,
      ),
      const _SidebarItem(
        Icons.church_outlined,
        'Igreja',
        AppRoutes.adminChurch,
      ),
      const _SidebarItem(Icons.settings_outlined, 'Configurações', '/profile'),
    ]),
  ];

  bool _isActive(BuildContext context, _SidebarItem item) {
    final uri = GoRouterState.of(context).uri;
    final itemUri = Uri.parse(item.location);
    if (uri.path != itemUri.path) return false;
    if (itemUri.path == AppRoutes.adminDashboard) {
      final current = uri.queryParameters['tab'] ?? '0';
      final target = itemUri.queryParameters['tab'] ?? '0';
      return current == target;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.sidebarWidth,
      decoration: const BoxDecoration(gradient: AppColors.sidebarGradient),
      child: Column(
        children: [
          // ── Marca ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: _brandLogo(),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Sistema Igreja',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // ── Navegação ─────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final group in _applyGating(_groups())) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
                    child: Text(
                      group.label.toUpperCase(),
                      style: AppTypography.sectionLabel.copyWith(
                        color: AppColors.white.withValues(alpha: .45),
                      ),
                    ),
                  ),
                  for (final item in group.items)
                    _SidebarTile(
                      item: item,
                      active: _isActive(context, item),
                      onTap: item.lockedFeature != null
                          ? () => showFeatureLockedDialog(
                              context,
                              item.lockedFeature!,
                            )
                          : () => context.go(item.location),
                    ),
                ],
              ],
            ),
          ),
          // ── Card do usuário ───────────────────────────────────────────
          const _SidebarUserCard(),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _SidebarItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = item.lockedFeature != null;
    final fg = locked
        ? AppColors.white.withValues(alpha: .38)
        : active
        ? AppColors.gold
        : AppColors.white.withValues(alpha: .78);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: active && !locked
            ? AppColors.sidebarActiveBg
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          hoverColor: AppColors.white.withValues(alpha: .06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: fg),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTypography.labelLarge.copyWith(
                      color: locked
                          ? AppColors.white.withValues(alpha: .38)
                          : active
                          ? AppColors.white
                          : fg,
                      fontWeight: active && !locked
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (locked)
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 15,
                    color: AppColors.white.withValues(alpha: .38),
                  )
                else if (item.badge != null && item.badge! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                    ),
                    child: Text(
                      '${item.badge}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.navy900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarUserCard extends StatelessWidget {
  const _SidebarUserCard();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;
        final name = user?.name ?? '—';
        final initials = name.trim().isEmpty
            ? '?'
            : name
                  .trim()
                  .split(RegExp(r'\s+'))
                  .take(2)
                  .map((p) => p[0].toUpperCase())
                  .join();
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.white.withValues(alpha: .08)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.gold,
                child: Text(
                  initials,
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.navy900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Administrador',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.white.withValues(alpha: .55),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sair',
                icon: Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: AppColors.white.withValues(alpha: .7),
                ),
                onPressed: () =>
                    context.read<AuthBloc>().add(const AuthLogoutRequested()),
              ),
            ],
          ),
        );
      },
    );
  }
}
