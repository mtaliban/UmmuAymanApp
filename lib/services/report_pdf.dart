import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../utils/format.dart';

/// PDF ya RIPOTI (B4): A4, font Inter, kichwa + kisanduku cha safu 4,
/// jedwali la bidhaa (siku) au faida kila kipindi + top/low/unsold,
/// chini "Imetolewa …" na "Ukurasa 1 / N".
final _blue = PdfColor.fromInt(0xFF0369A1);
final _grey = PdfColor.fromInt(0xFF6B7280);
final _line = PdfColor.fromInt(0xFFE5E7EB);

Future<pw.ThemeData> _interTheme() async => pw.ThemeData.withFont(
      base: pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf')),
      bold: pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf')),
    );

pw.Widget _t(String s, {bool b = false, double size = 10, PdfColor? c, pw.TextAlign a = pw.TextAlign.left}) =>
    pw.Text(s, textAlign: a, style: pw.TextStyle(fontSize: size, fontWeight: b ? pw.FontWeight.bold : pw.FontWeight.normal, color: c));

pw.Widget _cell(String s, {bool right = true, bool bold = false, PdfColor? color, double size = 10.5}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: _t(s, b: bold, size: size, c: color, a: right ? pw.TextAlign.right : pw.TextAlign.left),
    );

pw.Widget _head(String s, {bool right = true}) => _cell(s, right: right, bold: true, color: _blue, size: 8.5);

/// "siku" / "wiki" / "mwezi" / "mwaka"
String _unit(String period) => const {'day': 'siku', 'week': 'wiki', 'month': 'mwezi', 'year': 'mwaka'}[period] ?? period;

/// Ripoti-siku-20-Nov-2026.pdf · Ripoti-wiki-15-21-Nov-2026.pdf
/// Ripoti-mwezi-Nov-2026.pdf · Ripoti-mwaka-2026.pdf
String reportFileName(Report r) {
  if (r.period == 'day') return 'Ripoti-siku-${fileDate(r.date ?? todayIso())}.pdf';
  if (r.period == 'week') {
    final a = DateTime.tryParse(r.start ?? '');
    final b = DateTime.tryParse(r.end ?? '');
    if (a == null || b == null) return 'Ripoti-wiki.pdf';
    return 'Ripoti-wiki-${a.day}-${b.day}-${monthsShort[b.month - 1]}-${b.year}.pdf';
  }
  if (r.period == 'month') {
    final a = DateTime.tryParse(r.start ?? '');
    if (a == null) return 'Ripoti-mwezi.pdf';
    return 'Ripoti-mwezi-${monthsShort[a.month - 1]}-${a.year}.pdf';
  }
  return 'Ripoti-mwaka-${(r.start ?? r.label).split('-').first}.pdf';
}

Future<Uint8List> reportPdfBytes(Report r, Shop shop) async {
  final doc = pw.Document(theme: await _interTheme());
  final s = r.summary;

  pw.Widget sec(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 4),
        child: pw.Text(t, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, letterSpacing: .8)),
      );

  pw.Widget simpleTable(List<String> head, List<List<String>> rows, {List<String>? total, int? blueCol}) {
    final n = head.length;
    return pw.Table(
      border: pw.TableBorder(horizontalInside: pw.BorderSide(color: _line)),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.5))),
          children: [for (var i = 0; i < n; i++) _head(head[i], right: i > 0)],
        ),
        for (final row in rows)
          pw.TableRow(children: [for (var i = 0; i < n; i++) _cell(row[i], right: i > 0, bold: i == blueCol, color: i == blueCol ? _blue : null)]),
        if (total != null)
          pw.TableRow(
            decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1.5))),
            children: [for (var i = 0; i < n; i++) _cell(total[i], right: i > 0, bold: i == 0 || i == blueCol, color: i == blueCol ? _blue : null)],
          ),
      ],
    );
  }

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(40),
    footer: (ctx) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10),
      child: pw.Column(children: [
        pw.Divider(color: _line, height: 1),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Expanded(child: _t('Imetolewa ${dateTimeShort(DateTime.now())}', size: 8.5, c: _grey)),
          _t('Ukurasa ${ctx.pageNumber} / ${ctx.pagesCount}', size: 8.5, c: _grey),
        ]),
      ]),
    ),
    build: (_) => [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _t(shop.name.toUpperCase(), b: true, size: 18, c: _blue),
            _t('${shop.phone} · ${shop.email}', size: 10, c: _grey),
          ]),
        ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          _t('RIPOTI YA ${_unit(r.period).toUpperCase()}', b: true, size: 13),
          _t(r.label, size: 10, c: _grey),
        ]),
      ]),
      pw.SizedBox(height: 16),
      pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _line), borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Row(children: [
          for (final (i, x) in [('Mauzo', s.sales), ('Mtaji', s.capital), ('Gharama', s.expenses), ('Faida halisi', s.net)].indexed)
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: i == 0 ? null : pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: _line))),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  _t(x.$1, size: 9, c: _grey),
                  _t(money(x.$2), b: true, size: i == 3 ? 12 : 12, c: i == 3 ? _blue : null),
                ]),
              ),
            ),
        ]),
      ),
      if (r.isDay) ...[
        if (r.products.isEmpty)
          pw.Padding(padding: const pw.EdgeInsets.only(top: 18), child: _t('Hakuna mauzo siku hii', size: 10, c: _grey))
        else ...[
          sec('BIDHAA ZILIZOUZWA'),
          simpleTable(
            const ['BIDHAA', 'IDADI', 'MAUZO', 'FAIDA'],
            [for (final p in r.products) [p.name, '${p.qty}', money(p.sales), money(p.profit)]],
            total: ['Jumla', '${r.totalQty}', money(s.sales), money(s.productProfit)],
            blueCol: 3,
          ),
        ],
      ] else ...[
        sec('FAIDA KILA ${_unit(r.period).toUpperCase()}'),
        simpleTable(
          const ['KIPINDI', 'FAIDA'],
          [for (final b in r.bars) [b.label, b.net == null ? '—' : money(b.net!)]],
          blueCol: 1,
        ),
        if (r.top.isNotEmpty) ...[
          sec('ZILIZOUZIKA ZAIDI'),
          simpleTable(const ['BIDHAA', 'IDADI', 'FAIDA'], [for (final p in r.top) [p.name, '${p.qty}', money(p.profit)]], blueCol: 2),
        ],
        if (r.low.isNotEmpty) ...[
          sec('ZILIZOUZWA KIDOGO'),
          simpleTable(const ['BIDHAA', 'IDADI', 'FAIDA'], [for (final p in r.low) [p.name, '${p.qty}', money(p.profit)]], blueCol: 2),
        ],
        if (r.unsold.isNotEmpty) ...[
          sec('HAZIJAUZIKA KABISA'),
          simpleTable(const ['BIDHAA', 'ZIPO', 'MTAJI'], [for (final u in r.unsold) [u.name, '${u.qty}', money(u.capital)]]),
        ],
      ],
    ],
  ));
  return doc.save();
}

/// Hifadhi faili (mf. Ripoti-siku-20-Nov-2026.pdf)
Future<File> reportPdfFile(Report r, Shop shop) async {
  final bytes = await reportPdfBytes(r, shop);
  Directory? dir;
  if (Platform.isAndroid) dir = await getExternalStorageDirectory();
  dir ??= await getApplicationDocumentsDirectory();
  final f = File('${dir.path}/${reportFileName(r)}');
  await f.writeAsBytes(bytes, flush: true);
  return f;
}

/// Pakua PDF -> inahifadhiwa na kufunguka.
Future<void> downloadReportPdf(Report r, Shop shop) async => OpenFilex.open((await reportPdfFile(r, shop)).path);

/// Shiriki PDF (WhatsApp, Facebook...).
Future<void> shareReportPdf(Report r, Shop shop) async {
  final f = await reportPdfFile(r, shop);
  await Share.shareXFiles([XFile(f.path, mimeType: 'application/pdf')], text: 'Ripoti ya ${_unit(r.period)} · ${r.shortLabel}');
}
