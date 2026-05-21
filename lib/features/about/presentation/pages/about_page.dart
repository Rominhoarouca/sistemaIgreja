import 'package:flutter/material.dart';
import '../../../../design_system/design_system.dart';

/// About page — shows app version, team info, and links.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        title: const Text('Sobre o App'),
      ),
      body: ListView(
        children: [
          // ── Hero ──────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xl2,
              horizontal: AppSpacing.pagePaddingH,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Image.asset(
                        'assets/images/logo App.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  'Sistema Igreja',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Versão $_version',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    'Sistema de Recepção e Integração',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Description ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.base),

                Text(
                  'Sobre',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.grey700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Text(
                    'O Sistema Igreja conecta visitantes a células de forma eficiente, '
                    'permitindo acompanhamento espiritual, registro de presença, '
                    'e gestão de materiais de integração.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                Text(
                  'Funcionalidades',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.grey700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: const [
                      _FeatureTile(
                        icon: Icons.people_outline,
                        label: 'Cadastro e acompanhamento de visitantes',
                      ),
                      Divider(height: 1),
                      _FeatureTile(
                        icon: Icons.groups_2_outlined,
                        label: 'Gestão de células e líderes',
                      ),
                      Divider(height: 1),
                      _FeatureTile(
                        icon: Icons.check_circle_outline,
                        label: 'Registro de presença nos encontros',
                      ),
                      Divider(height: 1),
                      _FeatureTile(
                        icon: Icons.auto_stories_outlined,
                        label: 'Materiais de discipulado no MinIO',
                      ),
                      Divider(height: 1),
                      _FeatureTile(
                        icon: Icons.trending_up_outlined,
                        label: 'Histórico espiritual dos visitantes',
                      ),
                      Divider(height: 1),
                      _FeatureTile(
                        icon: Icons.dashboard_outlined,
                        label: 'Dashboard com métricas de integração',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                Text(
                  'Tecnologia',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.grey700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: const [
                      _InfoTile(label: 'Frontend', value: 'Flutter'),
                      Divider(height: 1),
                      _InfoTile(
                        label: 'Backend',
                        value: 'Node.js + TypeScript',
                      ),
                      Divider(height: 1),
                      _InfoTile(label: 'Banco de dados', value: 'PostgreSQL'),
                      Divider(height: 1),
                      _InfoTile(label: 'Armazenamento', value: 'MinIO (S3)'),
                      Divider(height: 1),
                      _InfoTile(label: 'Infraestrutura', value: 'Docker'),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: AppColors.primary, size: 20),
      title: Text(label, style: AppTypography.bodyMedium),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(
        label,
        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
      ),
      trailing: Text(
        value,
        style: AppTypography.titleSmall.copyWith(color: AppColors.primary),
      ),
    );
  }
}
