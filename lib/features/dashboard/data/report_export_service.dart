import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'download_stub.dart' if (dart.library.html) 'download_web.dart';

/// Service responsible for generating and exporting PDF and Excel reports.
class ReportExportService {
  const ReportExportService();

  // ── PDF ───────────────────────────────────────────────────────────────────

  /// Builds the PDF bytes for the dashboard report and triggers the
  /// platform-specific share/print dialog.
  Future<void> exportPdf({
    required Map<String, dynamic> stats,
    required List<Map<String, dynamic>> months,
  }) async {
    final bytes = await _buildPdfBytes(stats: stats, months: months);
    final now = DateFormat('dd-MM-yyyy').format(DateTime.now());
    await Printing.sharePdf(bytes: bytes, filename: 'relatorio-$now.pdf');
  }

  Future<Uint8List> _buildPdfBytes({
    required Map<String, dynamic> stats,
    required List<Map<String, dynamic>> months,
  }) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.notoSansRegular(),
        bold: await PdfGoogleFonts.notoSansBold(),
      ),
    );

    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final totalVisitors = stats['totalVisitors'] as int? ?? 0;
    final integrated = stats['integratedVisitors'] as int? ?? 0;
    final forwarded = stats['forwardedVisitors'] as int? ?? 0;
    final leaders = stats['totalLeaders'] as int? ?? 0;
    final totalCells = stats['totalCells'] as int? ?? 0;
    final newThisMonth = stats['newVisitorsThisMonth'] as int? ?? 0;
    final avgAttendance = stats['averageAttendanceRate'] as num? ?? 0;
    final integrationRate = totalVisitors == 0
        ? '0%'
        : '${(integrated / totalVisitors * 100).toStringAsFixed(1)}%';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Relatório da Igreja',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#1A56DB'),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Sistema de Recepção e Integração',
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColor.fromHex('#6B7280'),
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  now,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromHex('#6B7280'),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(color: PdfColor.fromHex('#1A56DB'), thickness: 2),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Sistema Igreja — Relatório Gerado em $now',
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColor.fromHex('#9CA3AF'),
              ),
            ),
            pw.Text(
              'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColor.fromHex('#9CA3AF'),
              ),
            ),
          ],
        ),
        build: (ctx) => [
          // ── KPI Cards ─────────────────────────────────────────────
          pw.Text(
            'Resumo Geral',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#111827'),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _pdfKpiCard('Visitantes', '$totalVisitors', '#1A56DB'),
              pw.SizedBox(width: 8),
              _pdfKpiCard('Integrados', '$integrated', '#057A55'),
              pw.SizedBox(width: 8),
              _pdfKpiCard('Encaminhados', '$forwarded', '#9061F9'),
              pw.SizedBox(width: 8),
              _pdfKpiCard('Taxa Integração', integrationRate, '#057A55'),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _pdfKpiCard('Líderes', '$leaders', '#1A56DB'),
              pw.SizedBox(width: 8),
              _pdfKpiCard('Células', '$totalCells', '#9061F9'),
              pw.SizedBox(width: 8),
              _pdfKpiCard('Novos (mês)', '$newThisMonth', '#E3A008'),
              pw.SizedBox(width: 8),
              _pdfKpiCard(
                'Freq. Média',
                '${avgAttendance.toStringAsFixed(1)}%',
                '#E3A008',
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          // ── Monthly Table ─────────────────────────────────────────
          pw.Text(
            'Visitantes por Mês',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#111827'),
            ),
          ),
          pw.SizedBox(height: 10),
          if (months.isEmpty)
            pw.Text(
              'Sem dados de visitantes ainda.',
              style: pw.TextStyle(
                fontSize: 11,
                color: PdfColor.fromHex('#6B7280'),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 10,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1A56DB'),
              ),
              cellStyle: pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
              },
              rowDecoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: PdfColor.fromHex('#E5E7EB'),
                    width: 0.5,
                  ),
                ),
              ),
              headers: ['Mês', 'Total Visitantes', 'Integrados', 'Taxa'],
              data: months.map((m) {
                final total = (m['total'] as num?)?.toInt() ?? 0;
                final integ = (m['integrated'] as num?)?.toInt() ?? 0;
                final rate = total == 0
                    ? '0%'
                    : '${(integ / total * 100).toStringAsFixed(1)}%';
                return [m['month'] as String? ?? '', '$total', '$integ', rate];
              }).toList(),
            ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfKpiCard(String label, String value, String hexColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB'), width: 1),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          color: PdfColor.fromHex('#F9FAFB'),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex(hexColor),
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromHex('#6B7280'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Excel ─────────────────────────────────────────────────────────────────

  /// Builds an Excel workbook and triggers a browser download on web,
  /// or saves to device and opens it on native platforms.
  Future<void> exportExcel({
    required Map<String, dynamic> stats,
    required List<Map<String, dynamic>> months,
  }) async {
    final excel = Excel.createExcel();

    // ── Sheet 1: Resumo ──────────────────────────────────────────────
    final resumoName = 'Resumo';
    final resumo = excel[resumoName];
    excel.setDefaultSheet(resumoName);

    _xlsHeader(resumo, ['Indicador', 'Valor'], row: 0);
    final totalVisitors = stats['totalVisitors'] as int? ?? 0;
    final integrated = stats['integratedVisitors'] as int? ?? 0;
    final integrationRate = totalVisitors == 0
        ? '0%'
        : '${(integrated / totalVisitors * 100).toStringAsFixed(1)}%';

    final summaryRows = [
      ['Total de Visitantes', '${stats['totalVisitors'] ?? 0}'],
      ['Visitantes Integrados', '${stats['integratedVisitors'] ?? 0}'],
      ['Encaminhamentos', '${stats['forwardedVisitors'] ?? 0}'],
      ['Novos este mês', '${stats['newVisitorsThisMonth'] ?? 0}'],
      ['Líderes Ativos', '${stats['totalLeaders'] ?? 0}'],
      ['Total de Células', '${stats['totalCells'] ?? 0}'],
      ['Taxa de Integração', integrationRate],
      [
        'Frequência Média',
        '${(stats['averageAttendanceRate'] as num? ?? 0).toStringAsFixed(1)}%',
      ],
    ];
    for (var i = 0; i < summaryRows.length; i++) {
      _xlsRow(resumo, summaryRows[i], row: i + 1);
    }

    // ── Sheet 2: Visitantes por Mês ──────────────────────────────────
    final monthlyName = 'Visitantes por Mes';
    final monthly = excel[monthlyName];
    _xlsHeader(monthly, ['Mês', 'Total', 'Integrados', 'Taxa (%)'], row: 0);
    for (var i = 0; i < months.length; i++) {
      final m = months[i];
      final total = (m['total'] as num?)?.toInt() ?? 0;
      final integ = (m['integrated'] as num?)?.toInt() ?? 0;
      final rate = total == 0 ? '0' : (integ / total * 100).toStringAsFixed(1);
      _xlsRow(monthly, [
        m['month'] as String? ?? '',
        '$total',
        '$integ',
        rate,
      ], row: i + 1);
    }

    // Remove default blank sheet
    excel.delete('Sheet1');

    final rawBytes = excel.save();
    if (rawBytes == null) return;
    final data = Uint8List.fromList(rawBytes);
    final now = DateFormat('dd-MM-yyyy').format(DateTime.now());
    if (kIsWeb) {
      downloadFileWeb(data, 'relatorio-$now.xlsx');
    }
  }

  void _xlsHeader(Sheet sheet, List<String> headers, {required int row}) {
    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      );
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1A56DB'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }
  }

  void _xlsRow(Sheet sheet, List<String> values, {required int row}) {
    for (var col = 0; col < values.length; col++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
          .value = TextCellValue(
        values[col],
      );
    }
  }
}
