import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../design_system/design_system.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../routing/role_home.dart';

class _MoreItem {
  const _MoreItem(this.icon, this.label, this.route, {this.subtitle});

  final IconData icon;
  final String label;
  final String route;
  final String? subtitle;
}

/// Aba "Mais" do bottom-nav mobile — atalhos para as demais telas admin.
class MoreMenuTab extends StatelessWidget {
  const MoreMenuTab({super.key});

  static const _people = [
    _MoreItem(
      Icons.record_voice_over_outlined,
      'Líderes',
      AppRoutes.adminLeaders,
    ),
    _MoreItem(
      Icons.supervisor_account_outlined,
      'Supervisores',
      AppRoutes.adminSupervisors,
    ),
    _MoreItem(Icons.hub_outlined, 'Coordenações', AppRoutes.adminCoordenacoes),
    _MoreItem(
      Icons.person_add_alt_outlined,
      'Novo Cadastro',
      AppRoutes.adminUsersRegister,
      subtitle: 'Líder, supervisor, coordenador ou professor',
    ),
    _MoreItem(
      Icons.manage_accounts_outlined,
      'Perfis dos usuários',
      AppRoutes.adminUserRoles,
      subtitle: 'Adicionar ou remover perfis',
    ),
    _MoreItem(
      Icons.qr_code_2_outlined,
      'QR Code de cadastro',
      AppRoutes.adminQrCode,
    ),
    _MoreItem(
      Icons.link_off_outlined,
      'Vínculos pendentes',
      AppRoutes.adminPendingLinks,
      subtitle: 'Células sem líder e líderes sem célula',
    ),
  ];

  static const _system = [
    _MoreItem(
      Icons.category_outlined,
      'Tipos de Célula',
      AppRoutes.adminCellTypes,
    ),
    _MoreItem(Icons.folder_open_rounded, 'Materiais', AppRoutes.adminMaterials),
    _MoreItem(
      Icons.photo_library_outlined,
      'Álbuns',
      AppRoutes.albums,
      subtitle: 'Fotos dos encontros por dia',
    ),
    // Salas do ministério infantil: a rota já existia e a sidebar do desktop
    // já a listava, mas no mobile não havia como chegar nela.
    _MoreItem(
      Icons.child_care_outlined,
      'Salas do Kids',
      AppRoutes.adminKidsRooms,
      subtitle: 'Ministério infantil',
    ),
    _MoreItem(Icons.chat_outlined, 'WhatsApp', AppRoutes.adminWhatsapp),
    _MoreItem(
      Icons.location_city_outlined,
      'Cidades e Bairros',
      AppRoutes.adminLocation,
    ),
    // A tela existia e a sidebar do desktop já a listava, mas no mobile o
    // admin não tinha como chegar nas configurações da própria igreja.
    _MoreItem(
      Icons.church_outlined,
      'Igreja',
      AppRoutes.adminChurch,
      subtitle: 'Plano, cor do menu, logo e redes sociais',
    ),
  ];

  /// Lista as áreas dos papéis que o usuário acumula e navega para a
  /// escolhida.
  void _showRoleSwitcher(BuildContext context, UserEntity user) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            Text('Trocar de perfil', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final role in orderedRoles(user))
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(role.label),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.go(homeRouteForRole(role));
                },
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePaddingH,
        AppSpacing.pagePaddingH,
        AppSpacing.pagePaddingH,
        100,
      ),
      children: [
        _sectionLabel(context, 'Pessoas'),
        _menuCard(context, _people),
        const SizedBox(height: AppSpacing.sectionGap),
        _sectionLabel(context, 'Sistema'),
        _menuCard(context, _system),
        const SizedBox(height: AppSpacing.sectionGap),
        _sectionLabel(context, 'Configurações'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: Icon(
                  isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                ),
                title: Text('Modo escuro', style: AppTypography.bodyLarge),
                value: ThemeController.instance.isDark(context),
                onChanged: (_) => ThemeController.instance.toggle(context),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text('Perfil', style: AppTypography.bodyLarge),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => context.push('/profile'),
              ),
              // Só aparece para quem acumula papéis — o usuário de um papel só
              // não tem para onde trocar.
              if (user != null && user.hasMultipleRoles) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: Text('Trocar de perfil', style: AppTypography.bodyLarge),
                  subtitle: Text(
                    orderedRoles(user).map((r) => r.label).join(' · '),
                    style: AppTypography.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _showRoleSwitcher(context, user),
                ),
              ],
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text('Sobre', style: AppTypography.bodyLarge),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => context.push('/about'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                ),
                title: Text(
                  'Sair',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.error,
                  ),
                ),
                onTap: () =>
                    context.read<AuthBloc>().add(const AuthLogoutRequested()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: AppSpacing.xs),
    child: Text(
      label.toUpperCase(),
      style: AppTypography.sectionLabel.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _menuCard(BuildContext context, List<_MoreItem> items) => Card(
    child: Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(),
          ListTile(
            minTileHeight: AppSpacing.minTouchTarget + 8,
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(
                items[i].icon,
                size: 20,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.linkDark
                    : AppColors.primary,
              ),
            ),
            title: Text(items[i].label, style: AppTypography.bodyLarge),
            subtitle: items[i].subtitle != null
                ? Text(items[i].subtitle!, style: AppTypography.bodySmall)
                : null,
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.push(items[i].route),
          ),
        ],
      ],
    ),
  );
}
