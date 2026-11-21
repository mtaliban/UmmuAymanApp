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

/// PDF ya "Mauzo ya siku" (M14): A4, font Inter, hakuna alama za risiti.
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

Future<Uint8List> dayPdfBytes(DailySheet d, Shop shop) async {
  final doc = pw.Document(theme: await _interTheme());
  final s = d.totals;
  final all = d.all;

  pw.Widget sec(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 18, bottom: 4),
        child: pw.Text(t, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, letterSpacing: .8)),
      );

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(40),
    // Mguu upo kwenye kila ukurasa: tarehe ya kutolewa + "Ukurasa N / M".
    footer: (ctx) => pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
      pw.Divider(color: _line, height: 12),
      pw.Row(children: [
        pw.Expanded(child: _t('Imetolewa ${dateTimeShort(DateTime.now())}', size: 8.5, c: _grey)),
        _t('Ukurasa ${ctx.pageNumber} / ${ctx.pagesCount}', size: 8.5, c: _grey),
      ]),
    ]),
    build: (_) => [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _t(shop.name.toUpperCase(), b: true, size: 18, c: _blue),
            _t('${shop.phone} · ${shop.email}', size: 10, c: _grey),
          ]),
        ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          _t('MAUZO YA SIKU', b: true, size: 13),
          _t(dateLong(d.date), size: 10, c: _grey),
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
                  _t(money(x.$2), b: true, size: 13, c: i == 3 ? _blue : null),
                ]),
              ),
            ),
        ]),
      ),
      sec('BIDHAA'),
      pw.Table(
        columnWidths: {0: const pw.FixedColumnWidth(20), 1: const pw.FlexColumnWidth(3)},
        border: pw.TableBorder(horizontalInside: pw.BorderSide(color: _line)),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.5))),
            children: [
              _head('#', right: false),
              _head('BIDHAA', right: false),
              _head('IDADI'),
              _head('SELLING'),
              _head('BUYING'),
              _head('MAUZO'),
              _head('FAIDA'),
            ],
          ),
          for (final (i, l) in all.indexed)
            pw.TableRow(children: [
              _cell('${i + 1}', right: false),
              _cell(l.name, right: false),
              _cell('${l.qty}'),
              _cell(money(l.selling)),
              _cell(money(l.buying)),
              _cell(money(l.sales)),
              _cell(money(l.profit), bold: true),
            ]),
          pw.TableRow(
            decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1.5))),
            children: [
              _cell(''),
              _cell('Jumla', right: false, bold: true),
              _cell('${d.qty}', bold: true),
              _cell(''),
              _cell(''),
              _cell(money(s.sales), bold: true),
              _cell(money(s.productProfit), bold: true, color: _blue),
            ],
          ),
        ],
      ),
      if (d.expenses.isNotEmpty) ...[
        sec('GHARAMA'),
        pw.Table(
          border: pw.TableBorder(horizontalInside: pw.BorderSide(color: _line)),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.5))),
              children: [_head('JINA', right: false), _head('KIASI')],
            ),
            for (final e in d.expenses) pw.TableRow(children: [_cell(e.name, right: false), _cell(money(e.amount))]),
            pw.TableRow(children: [_cell('Jumla', right: false, bold: true), _cell(money(s.expenses), bold: true)]),
          ],
        ),
      ],
      sec('HESABU YA SIKU'),
      pw.Table(
        border: pw.TableBorder(horizontalInside: pw.BorderSide(color: _line)),
        children: [
          for (final (a, v, b) in [
            ('Mauzo', s.sales, 0),
            ('Mtaji wa vilivyouzwa', s.capital, 0),
            ('Faida ya bidhaa', s.productProfit, 1),
            ('Gharama', s.expenses, 0),
            ('Faida halisi', s.net, 2),
          ])
            pw.TableRow(children: [
              _cell(a, right: false, bold: b > 0),
              _cell(money(v), bold: b > 0, color: b == 2 ? _blue : null),
            ]),
        ],
      ),
      pw.SizedBox(height: 26),
    ],
  ));
  return doc.save();
}

/// Hifadhi faili Mauzo-20-Nov-2026.pdf
Future<File> dayPdfFile(DailySheet d, Shop shop) async {
  final bytes = await dayPdfBytes(d, shop);
  Directory? dir;
  if (Platform.isAndroid) dir = await getExternalStorageDirectory();
  dir ??= await getApplicationDocumentsDirectory();
  final f = File('${dir.path}/Mauzo-${fileDate(iso(d.date))}.pdf');
  await f.writeAsBytes(bytes, flush: true);
  return f;
}

/// Pakua PDF -> inahifadhiwa na kufunguka.
Future<void> downloadDayPdf(DailySheet d, Shop shop) async => OpenFilex.open((await dayPdfFile(d, shop)).path);

/// Shiriki PDF (WhatsApp, Facebook...).
Future<void> shareDayPdf(DailySheet d, Shop shop) async {
  final f = await dayPdfFile(d, shop);
  await Share.shareXFiles([XFile(f.path, mimeType: 'application/pdf')], text: 'Mauzo ya ${dateLong(d.date)}');
}
