import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'attendee_widgets.dart';

/// Situação de uma pessoa em um encontro da célula, de
/// `GET /attendance/cell/:cellId/attendees/:personId/history`.
class AttendeeMeetingHistory {
  const AttendeeMeetingHistory({
    required this.meetingDate,
    required this.isPresent,
    required this.lesson,
    required this.ministrante,
  });

  factory AttendeeMeetingHistory.fromJson(Map<String, dynamic> json) =>
      AttendeeMeetingHistory(
        meetingDate: parseMeetingDate(json['meetingDate'] as String?),
        isPresent: json['isPresent'] as bool?,
        lesson: json['lesson'] as String?,
        ministrante: json['ministrante'] as String?,
      );

  final DateTime meetingDate;

  /// `null` quando o encontro aconteceu mas a presença dessa pessoa nunca foi
  /// lançada — não é falta, é ausência de registro.
  final bool? isPresent;
  final String? lesson;
  final String? ministrante;

  /// Dia sem hora — chave de comparação no calendário.
  DateTime get day =>
      DateTime(meetingDate.year, meetingDate.month, meetingDate.day);
}

/// Como um dia de encontro aparece no calendário.
enum _DayMark {
  present('Presente', Icons.check, AttendanceStage.excellent),
  absent('Faltou', Icons.close, AttendanceStage.critical),
  unrecorded('Sem registro', Icons.remove, null);

  const _DayMark(this.label, this.icon, this._stage);

  final String label;
  final IconData icon;
  final AttendanceStage? _stage;

  static _DayMark of(bool? isPresent) => switch (isPresent) {
    true => _DayMark.present,
    false => _DayMark.absent,
    null => _DayMark.unrecorded,
  };

  /// "Sem registro" fica cinza de propósito: só presença e falta carregam cor.
  Color color({required bool isDark}) =>
      _stage?.color(isDark: isDark) ??
      (isDark ? AppColors.text3Dark : AppColors.grey400);
}

/// Domingo primeiro, como em calendário brasileiro.
const _weekdayLabels = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

/// Abre o calendário de frequência da pessoa: cada encontro da célula marcado
/// como presença, falta ou sem registro.
Future<void> showAttendanceCalendarDialog({
  required BuildContext context,
  required Dio dio,
  required String cellId,
  required CellAttendee attendee,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        AttendanceCalendarDialog(dio: dio, cellId: cellId, attendee: attendee),
  );
}

class AttendanceCalendarDialog extends StatefulWidget {
  const AttendanceCalendarDialog({
    super.key,
    required this.dio,
    required this.cellId,
    required this.attendee,
  });

  final Dio dio;
  final String cellId;
  final CellAttendee attendee;

  @override
  State<AttendanceCalendarDialog> createState() =>
      _AttendanceCalendarDialogState();
}

class _AttendanceCalendarDialogState extends State<AttendanceCalendarDialog> {
  bool _loading = true;
  String? _error;
  List<AttendeeMeetingHistory> _history = [];

  /// Chaveado por dia (sem hora) para o desenho do calendário.
  Map<DateTime, AttendeeMeetingHistory> _byDay = {};

  /// Mês exibido — sempre o primeiro dia dele.
  late DateTime _month = _monthOf(DateTime.now());
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.dio.get(
        '/attendance/cell/${widget.cellId}/attendees/${widget.attendee.id}/history',
        queryParameters: {'kind': widget.attendee.kind},
      );
      final rows =
          (response.data as Map<String, dynamic>)['history'] as List? ?? [];
      final history =
          rows
              .map(
                (e) =>
                    AttendeeMeetingHistory.fromJson(e as Map<String, dynamic>),
              )
              .toList()
            ..sort((a, b) => b.meetingDate.compareTo(a.meetingDate));

      if (!mounted) return;
      setState(() {
        _history = history;
        _byDay = {for (final h in history) h.day: h};
        // Abre no último encontro da célula — é o que interessa primeiro — e já
        // deixa esse dia selecionado para o detalhe aparecer sem um toque.
        _selectedDay = history.isNotEmpty ? history.first.day : null;
        _month = _monthOf(
          history.isNotEmpty ? history.first.day : DateTime.now(),
        );
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar a frequência';
        _loading = false;
      });
    }
  }

  /// Limites da navegação: não faz sentido passear por meses sem encontro.
  DateTime? get _firstMonth =>
      _history.isEmpty ? null : _monthOf(_history.last.day);
  DateTime? get _lastMonth =>
      _history.isEmpty ? null : _monthOf(_history.first.day);

  bool get _canGoBack {
    final first = _firstMonth;
    return first != null && _month.isAfter(first);
  }

  bool get _canGoForward {
    final last = _lastMonth;
    return last != null && _month.isBefore(last);
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  int get _presentCount => _history.where((h) => h.isPresent == true).length;
  int get _absentCount => _history.where((h) => h.isPresent == false).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.base),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(attendee: widget.attendee, isDark: isDark),
              const SizedBox(height: AppSpacing.md),
              Flexible(child: _body(isDark)),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: 'Fechar',
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.sm,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(bool isDark) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl2),
        child: Center(child: AppLoadingIndicator(size: 32)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
        child: AppErrorState(message: _error!, onRetry: _load),
      );
    }
    if (_history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.base),
        child: AppEmptyState(
          title: 'Nenhum encontro registrado',
          subtitle: 'Quando a célula tiver encontros, eles aparecem aqui.',
          icon: Icons.event_busy_outlined,
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryRow(
            presentCount: _presentCount,
            absentCount: _absentCount,
            total: _history.length,
            isDark: isDark,
          ),
          const SizedBox(height: AppSpacing.md),
          _MonthNav(
            month: _month,
            canGoBack: _canGoBack,
            canGoForward: _canGoForward,
            onBack: () => _shiftMonth(-1),
            onForward: () => _shiftMonth(1),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MonthGrid(
            month: _month,
            byDay: _byDay,
            selectedDay: _selectedDay,
            isDark: isDark,
            onSelectDay: (day) => setState(() => _selectedDay = day),
          ),
          const SizedBox(height: AppSpacing.md),
          _Legend(isDark: isDark),
          if (_selectedDay != null && _byDay[_selectedDay] != null) ...[
            const SizedBox(height: AppSpacing.md),
            _SelectedMeetingCard(entry: _byDay[_selectedDay]!, isDark: isDark),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.attendee, required this.isDark});

  final CellAttendee attendee;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;
    final hasData = attendee.meetingsCount > 0;
    final stage = hasData ? AttendanceStage.of(attendee.attendanceRate) : null;

    return Row(
      children: [
        AppAvatar(initials: attendee.initials),
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
              Text(
                hasData
                    ? 'Frequência ${formatPercentBr(attendee.attendanceRate)} · ${stage!.label}'
                    : 'Sem registro de frequência',
                style: AppTypography.bodySmall.copyWith(color: mutedColor),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.presentCount,
    required this.absentCount,
    required this.total,
    required this.isDark,
  });

  final int presentCount;
  final int absentCount;
  final int total;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            value: '$presentCount',
            label: 'Presenças',
            color: _DayMark.present.color(isDark: isDark),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SummaryTile(
            value: '$absentCount',
            label: 'Faltas',
            color: _DayMark.absent.color(isDark: isDark),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SummaryTile(
            value: '$total',
            label: 'Encontros',
            color: _DayMark.unrecorded.color(isDark: isDark),
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  final String value;
  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.grey50,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                value,
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(color: mutedColor),
          ),
        ],
      ),
    );
  }
}

class _MonthNav extends StatelessWidget {
  const _MonthNav({
    required this.month,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
  });

  final DateTime month;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: canGoBack ? onBack : null,
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Mês anterior',
        ),
        Expanded(
          child: Text(
            '${monthNameBr(month.month)} de ${month.year}',
            textAlign: TextAlign.center,
            style: AppTypography.labelLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          onPressed: canGoForward ? onForward : null,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Próximo mês',
        ),
      ],
    );
  }
}

/// Grade do mês. Dias sem encontro ficam apagados: o calendário existe para
/// mostrar os encontros, não o mês inteiro.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.byDay,
    required this.selectedDay,
    required this.isDark,
    required this.onSelectDay,
  });

  final DateTime month;
  final Map<DateTime, AttendeeMeetingHistory> byDay;
  final DateTime? selectedDay;
  final bool isDark;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday: 1 = segunda … 7 = domingo. A grade começa no domingo.
    final leading = DateTime(month.year, month.month, 1).weekday % 7;

    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        Builder(
          builder: (_) {
            final date = DateTime(month.year, month.month, day);
            final entry = byDay[date];
            return _DayCell(
              day: day,
              entry: entry,
              isSelected: selectedDay == date,
              isDark: isDark,
              onTap: entry == null ? null : () => onSelectDay(date),
            );
          },
        ),
    ];

    return Column(
      children: [
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: AppTypography.bodySmall.copyWith(
                      color: mutedColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.xs,
          crossAxisSpacing: AppSpacing.xs,
          children: cells,
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.entry,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final int day;
  final AttendeeMeetingHistory? entry;
  final bool isSelected;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;

    if (entry == null) {
      return Center(
        child: Text(
          '$day',
          style: AppTypography.bodySmall.copyWith(color: mutedColor),
        ),
      );
    }

    final mark = _DayMark.of(entry!.isPresent);
    final color = mark.color(isDark: isDark);
    // Presença/falta preenchem o círculo; "sem registro" fica só com contorno —
    // o dia teve encontro, mas nada foi lançado para essa pessoa.
    final filled = mark != _DayMark.unrecorded;

    return Semantics(
      label: '$day: ${mark.label}',
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : Colors.transparent,
            border: Border.all(
              color: color,
              width: isSelected ? 2.5 : (filled ? 0 : 1.5),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: AppTypography.bodySmall.copyWith(
                  color: filled ? Colors.white : color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(mark.icon, size: 10, color: filled ? Colors.white : color),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        for (final mark in _DayMark.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mark == _DayMark.unrecorded
                      ? Colors.transparent
                      : mark.color(isDark: isDark),
                  border: Border.all(color: mark.color(isDark: isDark)),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                mark.label,
                style: AppTypography.bodySmall.copyWith(color: mutedColor),
              ),
            ],
          ),
      ],
    );
  }
}

class _SelectedMeetingCard extends StatelessWidget {
  const _SelectedMeetingCard({required this.entry, required this.isDark});

  final AttendeeMeetingHistory entry;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;
    final mark = _DayMark.of(entry.isPresent);

    return Container(
      width: double.infinity,
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
                  'Encontro de ${formatDateBr(entry.meetingDate)}',
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AppBadge(
                label: mark.label,
                variant: switch (mark) {
                  _DayMark.present => AppBadgeVariant.success,
                  _DayMark.absent => AppBadgeVariant.error,
                  _DayMark.unrecorded => AppBadgeVariant.neutral,
                },
                size: AppBadgeSize.sm,
              ),
            ],
          ),
          if (entry.lesson != null && entry.lesson!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Lição: ${entry.lesson}',
              style: AppTypography.bodySmall.copyWith(color: mutedColor),
            ),
          ],
          if (entry.ministrante != null && entry.ministrante!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Ministrante: ${entry.ministrante}',
              style: AppTypography.bodySmall.copyWith(color: mutedColor),
            ),
          ],
        ],
      ),
    );
  }
}
