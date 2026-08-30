import 'package:flutter/material.dart';
import '../../../../design_system/design_system.dart';

/// Pessoa que frequenta a célula — membro ou visitante na mesma lista, como
/// vem de `GET /attendance/cell/:cellId/attendees`.
class CellAttendee {
  const CellAttendee({
    required this.id,
    required this.kind,
    required this.name,
    required this.phone,
    required this.email,
    required this.birthDate,
    required this.gender,
    required this.maritalStatus,
    required this.address,
    required this.neighborhood,
    required this.city,
    required this.status,
    required this.isBaptized,
    required this.meetingsCount,
    required this.presentCount,
    required this.attendanceRate,
    required this.createdAt,
    this.roleInCell = 'MEMBRO',
    this.photoUrl,
    this.lastPresentDate,
    this.absentStreak = 0,
  });

  factory CellAttendee.fromJson(Map<String, dynamic> json) => CellAttendee(
    id: json['id'] as String,
    kind: json['kind'] as String? ?? 'MEMBER',
    name: json['name'] as String? ?? 'Sem nome',
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    birthDate: DateTime.tryParse(json['birthDate'] as String? ?? ''),
    gender: json['gender'] as String?,
    maritalStatus: json['maritalStatus'] as String?,
    address: json['address'] as String?,
    neighborhood: json['neighborhood'] as String?,
    city: json['city'] as String?,
    status: json['status'] as String?,
    isBaptized: json['isBaptized'] as bool?,
    meetingsCount: (json['meetingsCount'] as num?)?.toInt() ?? 0,
    presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
    attendanceRate: (json['attendanceRate'] as num?)?.toDouble() ?? 0,
    lastPresentDate: json['lastPresentDate'] == null
        ? null
        : parseMeetingDate(json['lastPresentDate'] as String?),
    absentStreak: (json['absentStreak'] as num?)?.toInt() ?? 0,
    roleInCell: json['roleInCell'] as String? ?? 'MEMBRO',
    photoUrl: json['photoUrl'] as String?,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  final String id;

  /// `MEMBER` ou `VISITOR`.
  final String kind;
  final String name;
  final String? phone;
  final String? email;
  final DateTime? birthDate;
  final String? gender;
  final String? maritalStatus;
  final String? address;
  final String? neighborhood;
  final String? city;

  /// Só visitantes têm status de acompanhamento.
  final String? status;
  final bool? isBaptized;
  final int meetingsCount;
  final int presentCount;
  final double attendanceRate;
  final DateTime createdAt;

  /// Último encontro em que esteve presente — `null` se nunca veio.
  final DateTime? lastPresentDate;

  /// Faltas seguidas mais recentes. Ver `absentStreak` no repositório da API.
  final int absentStreak;

  /// Papel na célula: `MEMBRO`, `VICE_LIDER`, `ANFITRIAO` ou `VISITANTE`.
  final String roleInCell;

  /// Foto de perfil (URL assinada), quando cadastrada.
  final String? photoUrl;

  bool get isMember => kind == 'MEMBER';

  /// Membro com função na célula — o que o badge destaca.
  bool get hasCellRole =>
      roleInCell == 'VICE_LIDER' || roleInCell == 'ANFITRIAO';

  /// Parou de frequentar: faltou nos últimos [kInactiveAbsentStreak] encontros
  /// em que a presença dela foi registrada. Duas faltas seguidas ainda é vida
  /// normal (viagem, trabalho); três já é o líder ir atrás.
  bool get isInactive => absentStreak >= kInactiveAbsentStreak;

  /// Aniversário no mês informado (1–12). Compara em UTC porque `birth_date`
  /// chega como meia-noite UTC — ver [parseMeetingDate].
  bool birthdayInMonth(int month) => birthDate?.toUtc().month == month;

  /// Dia do aniversário, em UTC pelo mesmo motivo de [birthdayInMonth].
  int? get birthDay => birthDate?.toUtc().day;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.map((p) => p[0].toUpperCase()).take(2).join();
  }
}

/// Faltas seguidas a partir das quais alguém entra na lista de ausentes.
const kInactiveAbsentStreak = 3;

/// Filtro da lista de frequentadores.
enum AttendeeFilter {
  all('Todos'),
  members('Membros'),
  visitors('Visitantes');

  const AttendeeFilter(this.label);

  final String label;

  bool matches(CellAttendee attendee) => switch (this) {
    AttendeeFilter.all => true,
    AttendeeFilter.members => attendee.isMember,
    AttendeeFilter.visitors => !attendee.isMember,
  };
}

/// Encontro da célula, de `GET /attendance/cell/:cellId/meetings`.
class CellMeetingSummary {
  const CellMeetingSummary({
    required this.meetingDate,
    required this.present,
    required this.membersPresent,
    required this.visitorsPresent,
    required this.lesson,
    required this.ministrante,
    required this.isRecorded,
    this.materialId,
    this.materialTitle,
  });

  factory CellMeetingSummary.fromJson(Map<String, dynamic> json) =>
      CellMeetingSummary(
        meetingDate: parseMeetingDate(json['meetingDate'] as String?),
        present: (json['present'] as num?)?.toInt() ?? 0,
        membersPresent: (json['membersPresent'] as num?)?.toInt() ?? 0,
        visitorsPresent: (json['visitorsPresent'] as num?)?.toInt() ?? 0,
        lesson: json['lesson'] as String?,
        ministrante: json['ministrante'] as String?,
        isRecorded: json['isRecorded'] as bool? ?? false,
        materialId: json['materialId'] as String?,
        materialTitle: json['materialTitle'] as String?,
      );

  final DateTime meetingDate;
  final int present;
  final int membersPresent;
  final int visitorsPresent;
  final String? lesson;
  final String? ministrante;
  final bool isRecorded;

  /// Material do acervo usado como lição, quando houver.
  final String? materialId;
  final String? materialTitle;

  /// O que exibir como lição: o material tem prioridade sobre o texto livre.
  String? get lessonLabel =>
      (materialTitle?.isNotEmpty ?? false) ? materialTitle : lesson;
}

/// Data de encontro vinda da API.
///
/// `meeting_date` é `date` no Postgres, então chega como meia-noite **UTC**
/// ("2026-07-06T00:00:00.000Z"). Converter com `toLocal()` em fuso negativo
/// joga o dia para trás (05/07 21:00). O certo é ler os componentes em UTC e
/// montar a data local equivalente — o que também dá uma chave estável para
/// comparar dias no calendário.
DateTime parseMeetingDate(String? iso) {
  final parsed = DateTime.tryParse(iso ?? '');
  if (parsed == null) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
  final utc = parsed.toUtc();
  return DateTime(utc.year, utc.month, utc.day);
}

/// pt-BR: 91.4 → "91,4%".
String formatPercentBr(double value) =>
    '${value.toStringAsFixed(1).replaceAll('.', ',')}%';

/// dd/MM/yyyy.
String formatDateBr(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}

const _monthNamesBr = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

/// Nome do mês em pt-BR (1 = Janeiro).
String monthNameBr(int month) => _monthNamesBr[month - 1];

/// dd/MM — aniversário não precisa do ano.
String formatDayMonthBr(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m';
}

/// Estágios de frequência individual.
///
/// É uma escala de **status** (quanto aquela pessoa precisa de atenção
/// pastoral), não um conjunto de categorias — por isso passos vizinhos são
/// parecidos de propósito: é o que faz ler como escala, e não como cinco
/// rótulos sem relação. Como o matiz sozinho não separa vizinhos, cada estágio
/// carrega o próprio nome em texto; a cor reforça, nunca decide.
///
/// Vermelho fica reservado para abaixo de 30%: acima disso a leitura é
/// "precisa de atenção", não "crítico".
///
/// Os valores foram medidos nas duas superfícies (clara e escura) para
/// luminosidade e contraste. Trocar um hex exige remedir o conjunto.
enum AttendanceStage {
  excellent('Excelente', Color(0xFF047857), Color(0xFF0E9F6E)),
  good('Boa', Color(0xFF0E9F6E), Color(0xFF12B886)),
  fair('Regular', Color(0xFFE8A33D), Color(0xFFC2851C)),
  low('Baixa', Color(0xFFEA580C), Color(0xFFD2570A)),
  critical('Crítica', Color(0xFFD92D20), Color(0xFFDC4A3D));

  const AttendanceStage(this.label, this._light, this._dark);

  final String label;
  final Color _light;
  final Color _dark;

  Color color({required bool isDark}) => isDark ? _dark : _light;

  static AttendanceStage of(double rate) {
    if (rate >= 90) return excellent;
    if (rate >= 75) return good;
    if (rate >= 50) return fair;
    if (rate >= 30) return low;
    return critical;
  }
}

/// Card de um frequentador: identificação + contato resumido + frequência.
/// O restante das informações abre ao toque.
class AttendeeCard extends StatelessWidget {
  const AttendeeCard({
    super.key,
    required this.attendee,
    required this.onTap,
    this.onFrequencyTap,
  });

  final CellAttendee attendee;
  final VoidCallback onTap;

  /// Toque na faixa de frequência — abre o calendário de presenças. Quando
  /// `null` a faixa continua sendo só leitura e o toque cai no card inteiro.
  final VoidCallback? onFrequencyTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(
                initials: attendee.initials,
                imageUrl: attendee.photoUrl,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attendee.name,
                      style: AppTypography.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _ContactLine(attendee: attendee, color: mutedColor),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _KindBadge(attendee: attendee),
                  const SizedBox(height: AppSpacing.xs),
                  Icon(Icons.chevron_right, size: 20, color: mutedColor),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _FrequencyStrip(
            attendee: attendee,
            isDark: isDark,
            onTap: onFrequencyTap,
          ),
        ],
      ),
    );
  }
}

/// Aniversário · telefone · e-mail. Quebra em várias linhas em telas estreitas.
class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.attendee, required this.color});

  final CellAttendee attendee;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.bodySmall.copyWith(color: color);
    final items = <(IconData, String)>[
      if (attendee.birthDate != null)
        (Icons.cake_outlined, formatDayMonthBr(attendee.birthDate!)),
      if (attendee.phone != null && attendee.phone!.isNotEmpty)
        (Icons.phone_outlined, attendee.phone!),
      if (attendee.email != null && attendee.email!.isNotEmpty)
        (Icons.email_outlined, attendee.email!),
    ];

    if (items.isEmpty) {
      return Text('Sem contato cadastrado', style: style);
    }

    // Dentro de um Wrap os filhos recebem largura ilimitada, então um e-mail
    // longo estouraria o card. O LayoutBuilder devolve o teto para cada item.
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          for (final (icon, text) in items)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      text,
                      style: style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.attendee});

  final CellAttendee attendee;

  @override
  Widget build(BuildContext context) {
    if (attendee.isMember) {
      // Vice-líder e anfitrião substituem "Membro": é a informação que o líder
      // procura na lista.
      return switch (attendee.roleInCell) {
        'VICE_LIDER' => const AppBadge(
          label: 'Vice-líder',
          variant: AppBadgeVariant.info,
          size: AppBadgeSize.sm,
        ),
        'ANFITRIAO' => const AppBadge(
          label: 'Anfitrião',
          variant: AppBadgeVariant.primary,
          size: AppBadgeSize.sm,
        ),
        _ => const AppBadge(
          label: 'Membro',
          variant: AppBadgeVariant.success,
          size: AppBadgeSize.sm,
        ),
      };
    }
    // Para visitantes o status de acompanhamento diz mais que "Visitante".
    return AppBadge(
      label: switch (attendee.status) {
        'novo' => 'Novo',
        'em_acompanhamento' => 'Em acompanhamento',
        'integrado' => 'Integrado',
        'inativo' => 'Não retornou',
        _ => 'Visitante',
      },
      variant: switch (attendee.status) {
        'novo' => AppBadgeVariant.info,
        'em_acompanhamento' => AppBadgeVariant.warning,
        'integrado' => AppBadgeVariant.success,
        'inativo' => AppBadgeVariant.neutral,
        _ => AppBadgeVariant.info,
      },
      size: AppBadgeSize.sm,
    );
  }
}

/// Faixa com a frequência individual: estágio nomeado, percentual e barra.
///
/// O texto usa tokens de tinta, não a cor do estágio: parte da escala (o âmbar,
/// por exemplo) fica em 2,1:1 sobre fundo claro e seria ilegível como texto. A
/// cor vive na barra e no ponto ao lado do nome.
class _FrequencyStrip extends StatelessWidget {
  const _FrequencyStrip({
    required this.attendee,
    required this.isDark,
    this.onTap,
  });

  final CellAttendee attendee;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;
    final inkColor = isDark ? AppColors.textDark : AppColors.textPrimary;
    final hasData = attendee.meetingsCount > 0;

    final stage = hasData ? AttendanceStage.of(attendee.attendanceRate) : null;
    final barColor =
        stage?.color(isDark: isDark) ??
        (isDark ? AppColors.mutedDark : AppColors.grey400);

    final strip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.grey50,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: barColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  stage?.label ?? 'Sem registro',
                  style: AppTypography.labelMedium.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasData) ...[
                Text(
                  formatPercentBr(attendee.attendanceRate),
                  style: AppTypography.labelLarge.copyWith(
                    color: inkColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '(${attendee.presentCount}/${attendee.meetingsCount})',
                  style: AppTypography.bodySmall.copyWith(color: mutedColor),
                ),
              ],
              // O calendário é a única pista de que a faixa abre outra coisa —
              // sem ele o toque duplo (card x faixa) fica invisível.
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.calendar_month_outlined,
                  size: 16,
                  color: isDark ? AppColors.linkDark : AppColors.primary,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: Container(
              height: 6,
              color: isDark ? AppColors.dividerDark : AppColors.grey200,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (attendee.attendanceRate / 100).clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return strip;

    return Semantics(
      button: true,
      label: 'Ver calendário de frequência de ${attendee.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: strip,
      ),
    );
  }
}

/// Card "Últimas reuniões": data, se a presença já foi registrada, lição,
/// ministrante e quantos membros/visitantes estiveram presentes.
class LastMeetingsCard extends StatefulWidget {
  const LastMeetingsCard({
    super.key,
    required this.meetings,
    required this.onSeeAll,
    this.maxItems = 3,
  });

  final List<CellMeetingSummary> meetings;
  final VoidCallback onSeeAll;
  final int maxItems;

  @override
  State<LastMeetingsCard> createState() => _LastMeetingsCardState();
}

class _LastMeetingsCardState extends State<LastMeetingsCard> {
  /// Recolhível: na tela de célula esta lista fica embaixo dos frequentadores
  /// e empurra o resto para longe.
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;
    final shown = widget.meetings.take(widget.maxItems).toList();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: AppSpacing.iconSm,
                  color: isDark ? AppColors.linkDark : AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Últimas reuniões',
                    style: AppTypography.titleSmall,
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: mutedColor,
                  ),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
          const SizedBox(height: AppSpacing.md),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
              child: Text(
                'Nenhum encontro registrado ainda.',
                style: AppTypography.bodySmall.copyWith(color: mutedColor),
              ),
            )
          else
            for (final meeting in shown) ...[
              _MeetingTile(meeting: meeting, isDark: isDark),
              const SizedBox(height: AppSpacing.sm),
            ],
          AppButton(
            label: 'Mais reuniões',
            variant: AppButtonVariant.outline,
            size: AppButtonSize.sm,
            onPressed: widget.onSeeAll,
          ),
          ],
        ],
      ),
    );
  }
}

class _MeetingTile extends StatelessWidget {
  const _MeetingTile({required this.meeting, required this.isDark});

  final CellMeetingSummary meeting;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;
    final labelStyle = AppTypography.bodySmall.copyWith(color: mutedColor);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.grey50,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatDateBr(meeting.meetingDate),
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AppBadge(
                label: meeting.isRecorded ? 'Realizada' : 'Pendente',
                variant: meeting.isRecorded
                    ? AppBadgeVariant.success
                    : AppBadgeVariant.warning,
                size: AppBadgeSize.sm,
              ),
            ],
          ),
          if (meeting.lesson != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _IconLine(
              icon: Icons.menu_book_outlined,
              color: mutedColor,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Lição: ', style: labelStyle),
                    TextSpan(
                      text: meeting.lesson,
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (meeting.ministrante != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _IconLine(
              icon: Icons.person_outline,
              color: mutedColor,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Ministrante: ', style: labelStyle),
                    TextSpan(
                      text: meeting.ministrante,
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          // Wrap, não Row: em coluna estreita os dois contadores quebram de
          // linha em vez de estourar o card.
          Wrap(
            spacing: AppSpacing.base,
            runSpacing: AppSpacing.xs,
            children: [
              _CountLine(
                icon: Icons.groups_outlined,
                label: 'Presentes: ${meeting.membersPresent}',
                color: mutedColor,
                style: labelStyle,
              ),
              _CountLine(
                icon: Icons.person_add_alt_outlined,
                label: 'Visitantes: ${meeting.visitorsPresent}',
                color: mutedColor,
                style: labelStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountLine extends StatelessWidget {
  const _CountLine({
    required this.icon,
    required this.label,
    required this.color,
    required this.style,
  });

  final IconData icon;
  final String label;
  final Color color;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: style),
      ],
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({
    required this.icon,
    required this.color,
    required this.child,
  });

  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: child),
      ],
    );
  }
}
