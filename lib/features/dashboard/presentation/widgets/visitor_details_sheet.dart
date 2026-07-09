import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../design_system/design_system.dart';
import '../widgets/detail_row.dart';
import '../widgets/visitor_widgets.dart';

/// SRP: responsável apenas por exibir os detalhes completos de um visitante.
class VisitorDetailsSheet extends StatelessWidget {
  const VisitorDetailsSheet({
    super.key,
    required this.visitor,
    this.panel = false,
  });

  final Map<String, dynamic> visitor;

  /// Quando true, renderiza como painel lateral fixo (desktop) em vez de
  /// bottom-sheet arrastável.
  final bool panel;

  static String _textOrDash(Object? v) {
    final value = (v ?? '').toString().trim();
    return value.isEmpty ? 'Não informado' : value;
  }

  static String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Não informado';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return 'Data inválida';
    }
  }

  static int? _calculateAge(String? birthDateStr) {
    if (birthDateStr == null || birthDateStr.isEmpty) return null;
    try {
      final birthDate = DateTime.parse(birthDateStr);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _textOrDash(visitor['name']);
    final status = _textOrDash(visitor['status']);
    final createdAt = DateTime.tryParse(
      (visitor['createdAt'] as String?) ?? '',
    );
    final age = _calculateAge(visitor['birthDate'] as String?);

    String relativeTime() {
      if (createdAt == null) return 'Sem data';
      final diff = DateTime.now().difference(createdAt);
      if (diff.inDays == 0) return 'hoje';
      if (diff.inDays == 1) return 'há 1 dia';
      if (diff.inDays < 7) return 'há ${diff.inDays} dias';
      if (diff.inDays < 14) return 'há 1 sem.';
      return 'há ${(diff.inDays / 7).round()} sem.';
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppAvatar(
              initials: name.split(' ').map((e) => e[0]).take(2).join(),
              size: 56,
            ),
            const SizedBox(width: AppSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTypography.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  VisitorStatusBadge(status: status),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── Informações Básicas ─────────────────────────
        Text('Informações Básicas', style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              DetailRow(
                icon: Icons.phone_outlined,
                label: 'Telefone',
                value: _textOrDash(visitor['phone']),
              ),
              const Divider(height: 1),
              DetailRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _textOrDash(visitor['email']),
              ),
              const Divider(height: 1),
              DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Endereço',
                value: _textOrDash(visitor['address']),
              ),
              const Divider(height: 1),
              DetailRow(
                icon: Icons.access_time_outlined,
                label: 'Cadastrado',
                value: relativeTime(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── Informações Pessoais ────────────────────────
        Text('Informações Pessoais', style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              DetailRow(
                icon: Icons.cake_outlined,
                label: 'Data de Nascimento',
                value: _formatDate(visitor['birthDate'] as String?),
              ),
              if (age != null) ...[
                const Divider(height: 1),
                DetailRow(
                  icon: Icons.person_outline,
                  label: 'Idade',
                  value: '$age anos',
                ),
              ],
              const Divider(height: 1),
              DetailRow(
                icon: Icons.favorite_outline,
                label: 'Estado Civil',
                value: _textOrDash(visitor['maritalStatus']),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── Informações Espirituais ─────────────────────
        Text('Informações Espirituais', style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              DetailRow(
                icon: Icons.check_outlined,
                label: 'Batizado',
                value: (visitor['isBaptized'] as bool?) == true ? 'Sim' : 'Não',
              ),
              const Divider(height: 1),
              DetailRow(
                icon: Icons.group_outlined,
                label: 'Frequenta Célula',
                value: visitor['cellId'] != null ? 'Sim' : 'Não',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── Informações Adicionais ──────────────────────
        if (_textOrDash(visitor['knownPersonName']).isNotEmpty ||
            _textOrDash(visitor['originChurch']).isNotEmpty ||
            (visitor['interests'] as List?)?.isNotEmpty == true) ...[
          Text('Informações Adicionais', style: AppTypography.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (_textOrDash(visitor['originChurch']).isNotEmpty) ...[
                  DetailRow(
                    icon: Icons.church_outlined,
                    label: 'Igreja de Origem',
                    value: _textOrDash(visitor['originChurch']),
                  ),
                  const Divider(height: 1),
                ],
                if (_textOrDash(visitor['knownPersonName']).isNotEmpty) ...[
                  DetailRow(
                    icon: Icons.person_add_outlined,
                    label: 'Conhecido Por',
                    value: _textOrDash(visitor['knownPersonName']),
                  ),
                  const Divider(height: 1),
                ],
                if ((visitor['interests'] as List?)?.isNotEmpty == true)
                  DetailRow(
                    icon: Icons.star_outline,
                    label: 'Interesses',
                    value: (visitor['interests'] as List).cast<String>().join(
                      ', ',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        // ── Alterar Status ──────────────────────────────
        Text('Alterar status', style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        const Wrap(
          spacing: AppSpacing.sm,
          children: [
            VisitorStatusChip(label: 'Novo'),
            VisitorStatusChip(label: 'Em acompanhamento'),
            VisitorStatusChip(label: 'Integrado'),
            VisitorStatusChip(label: 'Inativo'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Ações ───────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: AppSpacing.buttonHeightMd,
          child: FilledButton.icon(
            onPressed: () => _openWhatsApp(visitor['phone'] as String?),
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: const Text('Enviar WhatsApp'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.whatsapp,
              foregroundColor: AppColors.white,
              textStyle: AppTypography.buttonLabel,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.base),
      ],
    );

    if (panel) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        child: content,
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            content,
          ],
        ),
      ),
    );
  }

  static Future<void> _openWhatsApp(String? phone) async {
    final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final normalized = digits.startsWith('55') ? digits : '55$digits';
    await launchUrl(
      Uri.parse('https://wa.me/$normalized'),
      mode: LaunchMode.externalApplication,
    );
  }
}
