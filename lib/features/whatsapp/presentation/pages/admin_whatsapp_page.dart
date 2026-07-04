import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/auth_storage.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class _MessageTemplate {
  _MessageTemplate({
    required this.id,
    required this.name,
    required this.body,
    this.category = 'Geral',
  });

  final String id;
  String name;
  String body;
  String category;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'body': body,
    'category': category,
  };

  factory _MessageTemplate.fromJson(Map<String, dynamic> j) => _MessageTemplate(
    id: j['id'] as String,
    name: j['name'] as String,
    body: j['body'] as String,
    category: j['category'] as String? ?? 'Geral',
  );
}

class _Recipient {
  _Recipient({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.extra = '',
  });

  final String id;
  final String name;
  final String phone;
  final String role; // 'LIDER' | 'SUPERVISOR' | 'VISITANTE'
  final String extra; // e.g. cell name, coordenação
  bool selected = false;

  String get initials => name
      .trim()
      .split(' ')
      .where((e) => e.isNotEmpty)
      .map((e) => e[0].toUpperCase())
      .take(2)
      .join();
}

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kTemplatesKey = 'whatsapp_templates_v1';

const _kVariableHints = [
  '{nome}',
  '{celula}',
  '{data}',
  '{horario}',
  '{bairro}',
  '{lider}',
];

const _kTemplateCategories = [
  'Geral',
  'Convite',
  'Acompanhamento',
  'Aviso',
  'Parabéns',
];

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class AdminWhatsappPage extends StatefulWidget {
  const AdminWhatsappPage({super.key});

  @override
  State<AdminWhatsappPage> createState() => _AdminWhatsappPageState();
}

class _AdminWhatsappPageState extends State<AdminWhatsappPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final Dio _dio;

  /// Template escolhido via "Usar" na aba Templates — consumido pela aba
  /// de envio.
  final _templateToUse = ValueNotifier<_MessageTemplate?>(null);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _dio = DioClient(AuthStorage()).dio;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _templateToUse.dispose();
    super.dispose();
  }

  void _useTemplate(_MessageTemplate t) {
    _templateToUse.value = t;
    _tabController.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('WhatsApp'),
            Text(
              'Mensagens em lote e individuais',
              style: AppTypography.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.send_outlined), text: 'Enviar'),
            Tab(icon: Icon(Icons.description_outlined), text: 'Templates'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SendTab(dio: _dio, templateToUse: _templateToUse),
          _TemplatesTab(dio: _dio, onUse: _useTemplate),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Templates
// ─────────────────────────────────────────────────────────────────────────────

class _TemplatesTab extends StatefulWidget {
  const _TemplatesTab({required this.dio, required this.onUse});

  final Dio dio;

  /// Chamado quando o usuário toca em "Usar" — leva o template ao composer.
  final void Function(_MessageTemplate) onUse;

  @override
  State<_TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<_TemplatesTab> {
  List<_MessageTemplate> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kTemplatesKey) ?? [];
    if (!mounted) return;
    setState(() {
      _templates = raw
          .map(
            (e) => _MessageTemplate.fromJson(
              jsonDecode(e) as Map<String, dynamic>,
            ),
          )
          .toList();
      _loading = false;
    });
  }

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kTemplatesKey,
      _templates.map((t) => jsonEncode(t.toJson())).toList(),
    );
  }

  void _openForm({_MessageTemplate? template}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplateFormSheet(
        existing: template,
        onSave: (saved) {
          setState(() {
            if (template == null) {
              _templates.add(saved);
            } else {
              final idx = _templates.indexWhere((t) => t.id == saved.id);
              if (idx != -1) _templates[idx] = saved;
            }
          });
          _saveTemplates();
        },
      ),
    );
  }

  Future<void> _deleteTemplate(_MessageTemplate t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir template'),
        content: Text(
          'Deseja excluir o template "${t.name}"? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _templates.removeWhere((e) => e.id == t.id));
      await _saveTemplates();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo Template'),
      ),
      body: _templates.isEmpty
          ? _EmptyState(
              icon: Icons.description_outlined,
              title: 'Nenhum template criado',
              subtitle:
                  'Crie templates de mensagem para agilizar o envio em lote.',
              actionLabel: 'Criar primeiro template',
              onAction: () => _openForm(),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.base,
                AppSpacing.base,
                100,
              ),
              itemCount: _templates.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => _TemplateCard(
                template: _templates[i],
                onUse: () => widget.onUse(_templates[i]),
                onEdit: () => _openForm(template: _templates[i]),
                onDelete: () => _deleteTemplate(_templates[i]),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Template Card
// ─────────────────────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onUse,
    required this.onEdit,
    required this.onDelete,
  });

  final _MessageTemplate template;
  final VoidCallback onUse;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      template.category,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onUse,
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: const Text('Usar'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: AppColors.grey500,
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Editar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: AppColors.error,
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Excluir',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                template.name,
                style: AppTypography.titleMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                template.body,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (_hasVariables(template.body)) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: _extractVariables(template.body)
                      .map(
                        (v) => Chip(
                          label: Text(v),
                          labelStyle: AppTypography.labelSmall.copyWith(
                            color: AppColors.accent,
                          ),
                          backgroundColor: const Color(0xFFEEF2FF),
                          side: BorderSide.none,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _hasVariables(String body) => body.contains(RegExp(r'\{[^}]+\}'));

  List<String> _extractVariables(String body) {
    final matches = RegExp(r'\{[^}]+\}').allMatches(body);
    return matches.map((m) => m.group(0)!).toSet().toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Template Form Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _TemplateFormSheet extends StatefulWidget {
  const _TemplateFormSheet({required this.onSave, this.existing});

  final _MessageTemplate? existing;
  final void Function(_MessageTemplate) onSave;

  @override
  State<_TemplateFormSheet> createState() => _TemplateFormSheetState();
}

class _TemplateFormSheetState extends State<_TemplateFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bodyCtrl;
  late String _category;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _bodyCtrl = TextEditingController(text: widget.existing?.body ?? '');
    _category = widget.existing?.category ?? 'Geral';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _insertVariable(String variable) {
    final ctrl = _bodyCtrl;
    final selection = ctrl.selection;
    final text = ctrl.text;
    final newText = text.replaceRange(
      selection.start < 0 ? text.length : selection.start,
      selection.end < 0 ? text.length : selection.end,
      variable,
    );
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset:
            (selection.start < 0 ? text.length : selection.start) +
            variable.length,
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final t = _MessageTemplate(
      id:
          widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      category: _category,
    );
    widget.onSave(t);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.md,
                AppSpacing.base,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    widget.existing == null
                        ? 'Novo Template'
                        : 'Editar Template',
                    style: AppTypography.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.base,
                  AppSpacing.base,
                  AppSpacing.base,
                  bottom + AppSpacing.base,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome do template',
                          hintText: 'Ex: Convite célula semana',
                          prefixIcon: Icon(Icons.label_outline),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Informe um nome'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.base),
                      // Category
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          prefixIcon: Icon(Icons.folder_open_outlined),
                        ),
                        items: _kTemplateCategories
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _category = v ?? 'Geral'),
                      ),
                      const SizedBox(height: AppSpacing.base),
                      // Variable chips
                      Text(
                        'Inserir variável',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: _kVariableHints
                            .map(
                              (v) => ActionChip(
                                label: Text(v),
                                labelStyle: AppTypography.labelSmall.copyWith(
                                  color: AppColors.accent,
                                ),
                                backgroundColor: const Color(0xFFEEF2FF),
                                side: BorderSide.none,
                                onPressed: () => _insertVariable(v),
                                avatar: const Icon(
                                  Icons.add,
                                  size: 14,
                                  color: AppColors.accent,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Mensagem + preview ao vivo
                      TextFormField(
                        controller: _bodyCtrl,
                        maxLines: 8,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Mensagem',
                          hintText:
                              'Olá {nome}, você está convidado para nossa célula {celula}...',
                          alignLabelWithHint: true,
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(bottom: 112),
                            child: Icon(Icons.chat_outlined),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Informe a mensagem'
                            : null,
                      ),
                      if (_bodyCtrl.text.trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.base),
                        _MessagePreviewBubble(
                          message: _bodyCtrl.text,
                          sampleName: 'João Silva',
                          sampleCelula: 'Célula Esperança',
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.check),
                          label: const Text('Salvar Template'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Send
// ─────────────────────────────────────────────────────────────────────────────

enum _SendStep { selectRecipients, composeMessage, confirm }

enum _SendMode { batch, individual }

class _SendTab extends StatefulWidget {
  const _SendTab({required this.dio, required this.templateToUse});

  final Dio dio;

  /// Template vindo da aba Templates via "Usar".
  final ValueNotifier<_MessageTemplate?> templateToUse;

  @override
  State<_SendTab> createState() => _SendTabState();
}

class _SendTabState extends State<_SendTab> {
  // Mode
  _SendMode _mode = _SendMode.batch;

  // Step (apenas para batch)
  _SendStep _step = _SendStep.selectRecipients;

  // Recipients
  bool _loadingRecipients = false;
  String? _recipientsError;
  List<_Recipient> _allRecipients = [];
  final Set<String> _selectedRoles = {'LIDER'};
  String _recipientSearch = '';

  // Compose
  List<_MessageTemplate> _templates = [];
  _MessageTemplate? _selectedTemplate;
  final _customMsgCtrl = TextEditingController();
  bool _useTemplate = true;

  // Sending
  bool _sending = false;
  int _sentCount = 0;

  // Individual send
  _Recipient? _selectedRecipientIndividual;
  final _individualMsgCtrl = TextEditingController();
  bool _individualUseTemplate = true;
  _MessageTemplate? _individualSelectedTemplate;

  List<_Recipient> get _filteredRecipients {
    final q = _recipientSearch.toLowerCase();
    return _allRecipients.where((r) {
      if (!_selectedRoles.contains(r.role)) return false;
      if (q.isNotEmpty) {
        return r.name.toLowerCase().contains(q) ||
            r.phone.contains(q) ||
            r.extra.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  List<_Recipient> get _selectedRecipients =>
      _filteredRecipients.where((r) => r.selected).toList();

  String get _currentMessage => _useTemplate && _selectedTemplate != null
      ? _selectedTemplate!.body
      : _customMsgCtrl.text;

  @override
  void initState() {
    super.initState();
    _loadRecipients();
    _loadTemplates();
    widget.templateToUse.addListener(_applyIncomingTemplate);
  }

  @override
  void dispose() {
    widget.templateToUse.removeListener(_applyIncomingTemplate);
    _customMsgCtrl.dispose();
    _individualMsgCtrl.dispose();
    super.dispose();
  }

  /// Aplica template escolhido via "Usar" na aba Templates ao composer.
  void _applyIncomingTemplate() {
    final t = widget.templateToUse.value;
    if (t == null) return;
    setState(() {
      _useTemplate = true;
      _selectedTemplate = t;
      _customMsgCtrl.text = t.body;
      _individualUseTemplate = true;
      _individualSelectedTemplate = t;
      _individualMsgCtrl.text = t.body;
    });
    _loadTemplates();
    widget.templateToUse.value = null;
  }

  Future<void> _loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kTemplatesKey) ?? [];
    if (!mounted) return;
    setState(() {
      _templates = raw
          .map(
            (e) => _MessageTemplate.fromJson(
              jsonDecode(e) as Map<String, dynamic>,
            ),
          )
          .toList();
    });
  }

  Future<void> _loadRecipients() async {
    setState(() {
      _loadingRecipients = true;
      _recipientsError = null;
    });
    try {
      final results = await Future.wait([
        widget.dio.get<dynamic>('/users/leaders'),
        widget.dio.get<dynamic>('/users/supervisors'),
        widget.dio.get<dynamic>('/visitors'),
      ]);

      final leaders =
          ((results[0].data as Map<String, dynamic>)['leaders'] as List? ?? [])
              .cast<Map<String, dynamic>>()
              .map(
                (j) => _Recipient(
                  id: j['id'] as String,
                  name: j['name'] as String? ?? '',
                  phone: j['phone'] as String? ?? '',
                  role: 'LIDER',
                  extra:
                      (j['cells'] as List?)
                          ?.cast<Map<String, dynamic>>()
                          .map((c) => c['name'] as String? ?? '')
                          .join(', ') ??
                      '',
                ),
              )
              .toList();

      final supervisors =
          ((results[1].data as Map<String, dynamic>)['supervisors'] as List? ??
                  [])
              .cast<Map<String, dynamic>>()
              .map(
                (j) => _Recipient(
                  id: j['id'] as String,
                  name: j['name'] as String? ?? '',
                  phone: j['phone'] as String? ?? '',
                  role: 'SUPERVISOR',
                  extra: j['coordenacaoName'] as String? ?? '',
                ),
              )
              .toList();

      final visitors =
          ((results[2].data as Map<String, dynamic>)['visitors'] as List? ?? [])
              .cast<Map<String, dynamic>>()
              .map(
                (j) => _Recipient(
                  id: j['id'] as String,
                  name: j['name'] as String? ?? '',
                  phone: j['phone'] as String? ?? '',
                  role: 'VISITANTE',
                  extra: j['status'] as String? ?? '',
                ),
              )
              .toList();

      if (!mounted) return;
      setState(() {
        _allRecipients = [...leaders, ...supervisors, ...visitors];
        _loadingRecipients = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recipientsError = 'Não foi possível carregar os contatos.';
        _loadingRecipients = false;
      });
    }
  }

  void _toggleRole(String role) {
    setState(() {
      if (_selectedRoles.contains(role)) {
        if (_selectedRoles.length > 1) _selectedRoles.remove(role);
      } else {
        _selectedRoles.add(role);
      }
    });
  }

  void _toggleSelectAll(bool val) {
    setState(() {
      for (final r in _filteredRecipients) {
        r.selected = val;
      }
    });
  }

  Future<void> _sendMessages() async {
    final recipients = _selectedRecipients;
    final message = _currentMessage;
    if (recipients.isEmpty || message.trim().isEmpty) return;

    setState(() {
      _sending = true;
      _sentCount = 0;
    });

    for (final recipient in recipients) {
      final personalised = _personaliseMessage(message, recipient);
      final phone = _normalisePhone(recipient.phone);
      if (phone.isEmpty) continue;

      final uri = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(personalised)}',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // Small gap so WhatsApp can process between opens
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
      if (!mounted) return;
      setState(() => _sentCount++);
    }

    if (!mounted) return;
    setState(() => _sending = false);
    _showSendResult(recipients.length);
  }

  String _personaliseMessage(String message, _Recipient r) => message
      .replaceAll('{nome}', r.name.split(' ').first)
      .replaceAll('{celula}', r.extra.isNotEmpty ? r.extra : 'sua célula')
      .replaceAll('{lider}', r.name);

  String _normalisePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '';
    // Ensure country code 55 for Brazil
    if (digits.startsWith('55') && digits.length >= 12) return digits;
    if (digits.length == 11 || digits.length == 10) return '55$digits';
    return digits;
  }

  void _showSendResult(int total) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_sentCount de $total mensagens enviadas via WhatsApp.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
    setState(() {
      _step = _SendStep.selectRecipients;
      for (final r in _allRecipients) {
        r.selected = false;
      }
      _selectedTemplate = null;
      _customMsgCtrl.clear();
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Mode selector
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: 'Em Lote',
                  icon: Icons.groups_outlined,
                  selected: _mode == _SendMode.batch,
                  onTap: () => setState(() => _mode = _SendMode.batch),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ModeButton(
                  label: 'Individual',
                  icon: Icons.person_outlined,
                  selected: _mode == _SendMode.individual,
                  onTap: () => setState(() => _mode = _SendMode.individual),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _mode == _SendMode.batch
                ? _buildBatchMode()
                : _buildIndividualMode(),
          ),
        ),
      ],
    );
  }

  // ── Batch Mode ──────────────────────────────────────────────────────────

  Widget _buildBatchMode() {
    return Column(
      key: const ValueKey('batch'),
      children: [
        _StepIndicator(current: _step),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (_step) {
              _SendStep.selectRecipients => _buildRecipientsStep(),
              _SendStep.composeMessage => _buildComposeStep(),
              _SendStep.confirm => _buildConfirmStep(),
            },
          ),
        ),
      ],
    );
  }

  // ── Individual Mode ─────────────────────────────────────────────────────

  Widget _buildIndividualMode() {
    final allRecipients = _allRecipients;
    final filtered = allRecipients
        .where(
          (r) =>
              _recipientSearch.isEmpty ||
              r.name.toLowerCase().contains(_recipientSearch.toLowerCase()) ||
              r.phone.contains(_recipientSearch),
        )
        .toList();

    final individualMessage =
        _individualUseTemplate && _individualSelectedTemplate != null
        ? _individualSelectedTemplate!.body
        : _individualMsgCtrl.text;

    return Column(
      key: const ValueKey('individual'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recipient selector
                _SectionHeader(title: 'Destinatário'),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  initialValue: _recipientSearch,
                  decoration: InputDecoration(
                    hintText: 'Procurar por nome ou telefone…',
                    prefixIcon: const Icon(Icons.search_outlined),
                    suffixIcon: _recipientSearch.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setState(() => _recipientSearch = ''),
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _recipientSearch = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_loadingRecipients)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.base),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filtered.isEmpty)
                  _EmptyState(
                    icon: Icons.people_outline,
                    title: 'Nenhum contato encontrado',
                    subtitle: 'Busque por nome ou telefone.',
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = filtered[i];
                        final selected =
                            _selectedRecipientIndividual?.id == r.id;
                        return ListTile(
                          leading: _Avatar(initials: r.initials, role: r.role),
                          title: Text(r.name),
                          subtitle: Text(r.phone),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.primary,
                                )
                              : null,
                          selected: selected,
                          onTap: () =>
                              setState(() => _selectedRecipientIndividual = r),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                // Message type
                if (_selectedRecipientIndividual != null) ...[
                  _SectionHeader(
                    title: 'Mensagem',
                    trailing: Row(
                      children: [
                        _ToggleOption(
                          label: 'Template',
                          selected: _individualUseTemplate,
                          onTap: () =>
                              setState(() => _individualUseTemplate = true),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _ToggleOption(
                          label: 'Personalizada',
                          selected: !_individualUseTemplate,
                          onTap: () =>
                              setState(() => _individualUseTemplate = false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  if (_individualUseTemplate)
                    DropdownButtonFormField<_MessageTemplate>(
                      value: _individualSelectedTemplate,
                      decoration: const InputDecoration(
                        labelText: 'Selecionar template',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      hint: const Text('Escolha um template…'),
                      items: _templates
                          .map(
                            (t) =>
                                DropdownMenuItem(value: t, child: Text(t.name)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _individualSelectedTemplate = v),
                    )
                  else
                    TextFormField(
                      controller: _individualMsgCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Mensagem',
                        hintText: 'Digite sua mensagem…',
                        alignLabelWithHint: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  if (individualMessage.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.base),
                    _MessagePreviewBubble(
                      message: individualMessage,
                      sampleName: _selectedRecipientIndividual!.name
                          .split(' ')
                          .first,
                      sampleCelula:
                          _selectedRecipientIndividual!.extra.isNotEmpty
                          ? _selectedRecipientIndividual!.extra
                          : 'Célula Esperança',
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        _BottomBar(
          child: _sending
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      height: 4,
                      child: LinearProgressIndicator(
                        backgroundColor: AppColors.grey200,
                        valueColor: AlwaysStoppedAnimation(AppColors.success),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Abrindo WhatsApp…',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                )
              : FilledButton.icon(
                  onPressed:
                      _selectedRecipientIndividual == null ||
                          individualMessage.trim().isEmpty
                      ? null
                      : _sendIndividualMessage,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Enviar via WhatsApp'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    disabledBackgroundColor: AppColors.grey200,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _sendIndividualMessage() async {
    final r = _selectedRecipientIndividual;
    final message =
        _individualUseTemplate && _individualSelectedTemplate != null
        ? _individualSelectedTemplate!.body
        : _individualMsgCtrl.text;

    if (r == null || message.trim().isEmpty) return;

    setState(() => _sending = true);

    final personalised = _personaliseMessage(message, r);
    final phone = _normalisePhone(r.phone);

    if (phone.isNotEmpty) {
      final uri = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(personalised)}',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    if (!mounted) return;
    setState(() => _sending = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mensagem aberta no WhatsApp para ${r.name}'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );

    setState(() {
      _selectedRecipientIndividual = null;
      _individualMsgCtrl.clear();
      _individualSelectedTemplate = null;
      _recipientSearch = '';
    });
  }

  // ── Step 1: Recipients ──────────────────────────────────────────────────

  Widget _buildRecipientsStep() {
    final filtered = _filteredRecipients;
    final allSelected =
        filtered.isNotEmpty && filtered.every((r) => r.selected);
    final selectedCount = filtered.where((r) => r.selected).length;

    return Column(
      key: const ValueKey('step1'),
      children: [
        // Filters bar
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.sm,
            AppSpacing.base,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Role filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _RoleChip(
                      label: 'Líderes',
                      icon: Icons.person_outlined,
                      color: AppColors.primary,
                      selected: _selectedRoles.contains('LIDER'),
                      onTap: () => _toggleRole('LIDER'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _RoleChip(
                      label: 'Supervisores',
                      icon: Icons.manage_accounts_outlined,
                      color: AppColors.secondary,
                      selected: _selectedRoles.contains('SUPERVISOR'),
                      onTap: () => _toggleRole('SUPERVISOR'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _RoleChip(
                      label: 'Visitantes',
                      icon: Icons.group_outlined,
                      color: AppColors.accent,
                      selected: _selectedRoles.contains('VISITANTE'),
                      onTap: () => _toggleRole('VISITANTE'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Search
              SizedBox(
                height: 44,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome, telefone ou célula…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    filled: true,
                    fillColor: AppColors.grey100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _recipientSearch = v),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Select all row
              Row(
                children: [
                  Checkbox(
                    value: allSelected,
                    onChanged: (_loadingRecipients || filtered.isEmpty)
                        ? null
                        : (v) => _toggleSelectAll(v ?? false),
                    tristate: false,
                  ),
                  Text(
                    allSelected ? 'Desmarcar todos' : 'Selecionar todos',
                    style: AppTypography.bodySmall,
                  ),
                  const Spacer(),
                  if (selectedCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusFull,
                        ),
                      ),
                      child: Text(
                        '$selectedCount selecionado${selectedCount == 1 ? '' : 's'}',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // List
        Expanded(
          child: _loadingRecipients
              ? const Center(child: CircularProgressIndicator())
              : _recipientsError != null
              ? _ErrorState(
                  message: _recipientsError!,
                  onRetry: _loadRecipients,
                )
              : filtered.isEmpty
              ? _EmptyState(
                  icon: Icons.people_outline,
                  title: 'Nenhum contato encontrado',
                  subtitle: 'Ajuste os filtros ou a busca.',
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (_, i) {
                    final r = filtered[i];
                    return _RecipientTile(
                      recipient: r,
                      onToggle: (v) => setState(() => r.selected = v),
                    );
                  },
                ),
        ),
        // Bottom action bar
        _BottomBar(
          child: FilledButton.icon(
            onPressed: selectedCount == 0
                ? null
                : () => setState(() => _step = _SendStep.composeMessage),
            icon: const Icon(Icons.arrow_forward),
            label: Text(
              'Continuar com $selectedCount contato${selectedCount == 1 ? '' : 's'}',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.grey200,
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 2: Compose ─────────────────────────────────────────────────────

  Widget _buildComposeStep() {
    final message = _currentMessage;

    return Column(
      key: const ValueKey('step2'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toggle template / custom
                _SectionHeader(
                  title: 'Tipo de mensagem',
                  trailing: Row(
                    children: [
                      _ToggleOption(
                        label: 'Template',
                        selected: _useTemplate,
                        onTap: () => setState(() => _useTemplate = true),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _ToggleOption(
                        label: 'Personalizada',
                        selected: !_useTemplate,
                        onTap: () => setState(() => _useTemplate = false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                if (_useTemplate) ...[
                  if (_templates.isEmpty)
                    _InfoBanner(
                      message:
                          'Nenhum template criado. Vá até a aba Templates para criar um.',
                      icon: Icons.info_outline,
                    )
                  else
                    DropdownButtonFormField<_MessageTemplate>(
                      initialValue: _selectedTemplate,
                      decoration: const InputDecoration(
                        labelText: 'Selecionar template',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      hint: const Text('Escolha um template…'),
                      items: _templates
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                t.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedTemplate = v),
                    ),
                ] else ...[
                  TextFormField(
                    controller: _customMsgCtrl,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Mensagem',
                      hintText: 'Digite sua mensagem aqui…',
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                if (message.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _SectionHeader(title: 'Pré-visualização'),
                  const SizedBox(height: AppSpacing.sm),
                  _MessagePreviewBubble(
                    message: message,
                    sampleName: _selectedRecipients.isNotEmpty
                        ? _selectedRecipients.first.name.split(' ').first
                        : 'João',
                    sampleCelula:
                        _selectedRecipients.isNotEmpty &&
                            _selectedRecipients.first.extra.isNotEmpty
                        ? _selectedRecipients.first.extra
                        : 'Célula Esperança',
                  ),
                ],
              ],
            ),
          ),
        ),
        _BottomBar(
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _step = _SendStep.selectRecipients),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Voltar'),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: message.trim().isEmpty
                      ? null
                      : () => setState(() => _step = _SendStep.confirm),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Revisar envio'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.grey200,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 3: Confirm ──────────────────────────────────────────────────────

  Widget _buildConfirmStep() {
    final selected = _selectedRecipients;
    final message = _currentMessage;

    return Column(
      key: const ValueKey('step3'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary card
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.base),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${selected.length} destinatário${selected.length == 1 ? '' : 's'}',
                            style: AppTypography.titleLarge.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            'Mensagem será aberta no WhatsApp',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _SectionHeader(title: 'Destinatários'),
                const SizedBox(height: AppSpacing.sm),
                ...selected
                    .take(5)
                    .map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          children: [
                            _Avatar(initials: r.initials, role: r.role),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.name,
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    r.phone,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (selected.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      '+ ${selected.length - 5} outros destinatários',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                _SectionHeader(title: 'Mensagem'),
                const SizedBox(height: AppSpacing.sm),
                _MessagePreviewBubble(
                  message: message,
                  sampleName: selected.isNotEmpty
                      ? selected.first.name.split(' ').first
                      : 'João',
                  sampleCelula:
                      selected.isNotEmpty && selected.first.extra.isNotEmpty
                      ? selected.first.extra
                      : 'Célula Esperança',
                ),
                const SizedBox(height: AppSpacing.base),
                _InfoBanner(
                  icon: Icons.info_outline,
                  message:
                      'O WhatsApp será aberto para cada destinatário individualmente. '
                      'Confirme o envio em cada janela.',
                ),
              ],
            ),
          ),
        ),
        _BottomBar(
          child: _sending
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: _sentCount / selected.length,
                      backgroundColor: AppColors.grey200,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.success,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Enviando $_sentCount de ${selected.length}…',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                )
              : Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _step = _SendStep.composeMessage),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Voltar'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _sendMessages,
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Enviar via WhatsApp'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared private widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.grey100,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});

  final _SendStep current;

  @override
  Widget build(BuildContext context) {
    const steps = ['Destinatários', 'Mensagem', 'Confirmar'];
    final currentIdx = _SendStep.values.indexOf(current);

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepIdx = i ~/ 2;
            return Expanded(
              child: Divider(
                color: stepIdx < currentIdx
                    ? AppColors.primary
                    : AppColors.grey300,
                thickness: 2,
              ),
            );
          }
          final stepIdx = i ~/ 2;
          final done = stepIdx < currentIdx;
          final active = stepIdx == currentIdx;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: done || active ? AppColors.primary : AppColors.grey200,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: done
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '${stepIdx + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: active ? Colors.white : AppColors.grey500,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                steps[stepIdx],
                style: AppTypography.labelSmall.copyWith(
                  color: active ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _RecipientTile extends StatelessWidget {
  const _RecipientTile({required this.recipient, required this.onToggle});

  final _Recipient recipient;
  final void Function(bool) onToggle;

  Color _roleColor() => switch (recipient.role) {
    'LIDER' => AppColors.primary,
    'SUPERVISOR' => AppColors.secondary,
    _ => AppColors.accent,
  };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _Avatar(initials: recipient.initials, role: recipient.role),
      title: Text(
        recipient.name,
        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipient.phone,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (recipient.extra.isNotEmpty)
            Text(
              recipient.extra,
              style: AppTypography.bodySmall.copyWith(color: _roleColor()),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      isThreeLine: recipient.extra.isNotEmpty,
      trailing: Checkbox(
        value: recipient.selected,
        onChanged: (v) => onToggle(v ?? false),
        activeColor: AppColors.primary,
      ),
      onTap: () => onToggle(!recipient.selected),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.role});

  final String initials;
  final String role;

  Color get _bg => switch (role) {
    'LIDER' => AppColors.primarySurface,
    'SUPERVISOR' => AppColors.secondarySurface,
    _ => const Color(0xFFEEF2FF),
  };

  Color get _fg => switch (role) {
    'LIDER' => AppColors.primary,
    'SUPERVISOR' => AppColors.secondary,
    _ => AppColors.accent,
  };

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 22,
    backgroundColor: _bg,
    child: Text(
      initials,
      style: AppTypography.labelMedium.copyWith(
        color: _fg,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    avatar: Icon(icon, size: 16),
    selected: selected,
    onSelected: (_) => onTap(),
    selectedColor: color.withValues(alpha: 0.15),
    checkmarkColor: color,
    labelStyle: TextStyle(
      color: selected ? color : AppColors.textSecondary,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
    ),
    side: BorderSide(color: selected ? color : AppColors.grey300),
    backgroundColor: AppColors.surface,
  );
}

class _MessagePreviewBubble extends StatelessWidget {
  const _MessagePreviewBubble({
    required this.message,
    required this.sampleName,
    required this.sampleCelula,
  });

  final String message;
  final String sampleName;
  final String sampleCelula;

  String get _resolved {
    final now = DateTime.now();
    return message
        .replaceAll('{nome}', sampleName)
        .replaceAll('{celula}', sampleCelula)
        .replaceAll('{lider}', sampleName)
        .replaceAll('{data}', '${now.day}/${now.month}/${now.year}')
        .replaceAll('{horario}', '19:00')
        .replaceAll('{bairro}', 'Centro');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              size: 16,
              color: AppColors.grey500,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Preview — variáveis substituídas por valores de exemplo',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFDCF8C6),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.radiusLg),
                topRight: Radius.circular(AppSpacing.radiusLg),
                bottomLeft: Radius.circular(AppSpacing.radiusLg),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _resolved,
              style: AppTypography.bodyMedium.copyWith(height: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: AppTypography.titleSmall.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      if (trailing != null) ...[const Spacer(), trailing!],
    ],
  );
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.grey100,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.sm,
        AppSpacing.base,
        AppSpacing.base + MediaQuery.of(context).padding.bottom,
      ),
      child: child,
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.infoLight,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.info),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: AppTypography.bodySmall.copyWith(color: AppColors.info),
          ),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            ),
            child: Icon(icon, size: 36, color: AppColors.grey400),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            title,
            style: AppTypography.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.base),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          size: 48,
          color: AppColors.grey400,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(message, style: AppTypography.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
        ),
      ],
    ),
  );
}
