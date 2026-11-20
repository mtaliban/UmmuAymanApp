import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';
import '../utils/format.dart';

final _grey = PdfColor.fromInt(0xFF6B7280);
final _blue = PdfColor.fromInt(0xFF0369A1);

pw.Widget _t(String s, {bool b = false, double size = 10, PdfColor? c, pw.TextAlign a = pw.TextAlign.left}) =>
    pw.Text(s, textAlign: a, style: pw.TextStyle(fontSize: size, fontWeight: b ? pw.FontWeight.bold : pw.FontWeight.normal, color: c));

/// Risiti rasmi (A5)
Future<Uint8List> receiptPdf(Receipt r, Shop shop) async {
  final doc = pw.Document();
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a5,
    margin: const pw.EdgeInsets.all(28),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      _t(shop.name, b: true, size: 16),
      _t('${shop.phone}  ·  ${shop.email}', c: _grey, size: 9),
      pw.SizedBox(height: 10),
      pw.Divider(thickness: 1.2),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_t('Mteja', c: _grey), _t(r.customerName, b: true), if (r.customerPhone.isNotEmpty) _t(r.customerPhone)])),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [_t('Na. ${r.number}', c: _grey), _t(dateShort(r.createdAt))]),
      ]),
      pw.SizedBox(height: 12),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: .6))),
        child: pw.Row(children: [
          pw.Expanded(flex: 10, child: _t('BIDHAA', b: true, c: _grey, size: 8)),
          pw.Expanded(flex: 3, child: _t('IDADI', b: true, c: _grey, size: 8, a: pw.TextAlign.center)),
          pw.Expanded(flex: 5, child: _t('BEI', b: true, c: _grey, size: 8, a: pw.TextAlign.right)),
          pw.Expanded(flex: 5, child: _t('KIASI', b: true, c: _grey, size: 8, a: pw.TextAlign.right)),
        ]),
      ),
      for (final it in r.items)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: .5))),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
                flex: 10,
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  _t(it.name, b: true),
                  if (it.discount > 0) _t('punguzo ${money(it.discount)} kila moja', c: _grey, size: 8),
                ])),
            pw.Expanded(flex: 3, child: _t('${it.qty}', a: pw.TextAlign.center)),
            pw.Expanded(flex: 5, child: _t(money(it.price - it.discount), a: pw.TextAlign.right)),
            pw.Expanded(flex: 5, child: _t(money(it.amount), b: true, a: pw.TextAlign.right)),
          ]),
        ),
      pw.SizedBox(height: 10),
      pw.Row(children: [
        pw.Spacer(flex: 9),
        pw.Expanded(
          flex: 11,
          child: pw.Column(children: [
            pw.Row(children: [pw.Expanded(child: _t('Jumla', c: _grey)), _t(money(r.gross), c: _grey)]),
            if (r.discountTotal > 0) pw.Row(children: [pw.Expanded(child: _t('Punguzo', c: _grey)), _t('- ${money(r.discountTotal)}', c: _grey)]),
            pw.Divider(thickness: 1.2),
            pw.Row(children: [pw.Expanded(child: _t('Imelipwa', b: true, size: 12)), _t('TSh ${money(r.paid)}', b: true, size: 12)]),
          ]),
        ),
      ]),
      pw.Spacer(),
      pw.Divider(color: PdfColors.grey300),
      pw.Center(child: _t('Asante kwa kununua', c: _grey)),
    ]),
  ));
  return doc.save();
}

/// Mauzo ya siku (A4) — PDF ya "Pakua PDF" na "Shiriki" kwenye Mauzo ya leo.
/// Kichwa cha duka -> bidhaa (IDADI · SELLING · BUYING · FAIDA) -> gharama -> hesabu ya leo.
Future<Uint8List> dailyPdf({
  required Shop shop,
  required DateTime date,
  required List<SaleLine> lines,
  required List<Expense> expenses,
}) async {
  final doc = pw.Document();
  final qty = lines.fold<int>(0, (a, l) => a + l.qty);
  final sales = lines.fold<int>(0, (a, l) => a + l.sales);
  final capital = lines.fold<int>(0, (a, l) => a + l.capital);
  final exp = expenses.fold<int>(0, (a, e) => a + e.amount);
  final profit = sales - capital;
  final net = profit - exp;

  pw.Widget sec(String s) => pw.Padding(padding: const pw.EdgeInsets.only(top: 18, bottom: 5), child: _t(s, b: true, size: 8, c: _blue));
  pw.Widget th(String s, {pw.TextAlign a = pw.TextAlign.left}) => _t(s, b: true, size: 7.5, c: _blue, a: a);
  pw.Widget td(String s, {pw.TextAlign a = pw.TextAlign.left, bool b = false, PdfColor? c, double size = 8.8}) =>
      _t(s, b: b, size: size, a: a, c: c);
  pw.Widget kv(String l, int v, {bool b = false, PdfColor? c}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: .5))),
        child: pw.Row(children: [pw.Expanded(child: _t(l, b: b, size: 9, c: c)), _t(money(v), b: b, size: 9, c: c)]),
      );

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(34, 34, 34, 26),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _t(shop.name, b: true, size: 13, c: _blue),
            pw.SizedBox(height: 2),
            _t('${shop.phone}  ·  ${shop.email}', c: _grey, size: 8),
          ]),
        ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          _t('MAUZO YA SIKU', b: true, size: 10),
          pw.SizedBox(height: 2),
          _t(dateLong(date), c: _grey, size: 8.5),
        ]),
      ]),
      sec('BIDHAA ZILIZOUZWA'),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: .8))),
        child: pw.Row(children: [
          pw.Expanded(flex: 1, child: th('#')),
          pw.Expanded(flex: 8, child: th('BIDHAA')),
          pw.Expanded(flex: 3, child: th('IDADI', a: pw.TextAlign.right)),
          pw.Expanded(flex: 4, child: th('SELLING', a: pw.TextAlign.right)),
          pw.Expanded(flex: 3, child: th('BUYING', a: pw.TextAlign.right)),
          pw.Expanded(flex: 3, child: th('FAIDA', a: pw.TextAlign.right)),
        ]),
      ),
      for (final (i, l) in lines.indexed)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5.5),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: .5))),
          child: pw.Row(children: [
            pw.Expanded(flex: 1, child: td('${i + 1}', c: _grey, size: 8)),
            pw.Expanded(flex: 8, child: td(l.variantId.isEmpty ? '${l.name} *' : l.name)),
            pw.Expanded(flex: 3, child: td('${l.qty}', a: pw.TextAlign.right)),
            pw.Expanded(flex: 4, child: td(money(l.selling), a: pw.TextAlign.right)),
            pw.Expanded(flex: 3, child: td(money(l.buying), a: pw.TextAlign.right)),
            pw.Expanded(flex: 3, child: td(money(l.profit), a: pw.TextAlign.right)),
          ]),
        ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey700, width: .8))),
        child: pw.Row(children: [
          pw.Expanded(flex: 1, child: td('Jumla', b: true, size: 8)),
          pw.Expanded(flex: 8, child: td('')),
          pw.Expanded(flex: 3, child: td('$qty', b: true, a: pw.TextAlign.right, size: 8)),
          pw.Expanded(flex: 4, child: td('Mauzo ${money(sales)}', b: true, a: pw.TextAlign.right, size: 8)),
          pw.Expanded(flex: 3, child: td('')),
          pw.Expanded(flex: 3, child: td(money(profit), b: true, c: _blue, a: pw.TextAlign.right, size: 8)),
        ]),
      ),
      sec('GHARAMA'),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: .6))),
        child: pw.Row(children: [pw.Expanded(child: th('JINA')), th('KIASI')]),
      ),
      if (expenses.isEmpty)
        pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6), child: td('Bado hakuna gharama', c: _grey))
      else
        for (final e in expenses)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 5.5),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: .5))),
            child: pw.Row(children: [pw.Expanded(child: td(e.name)), td(money(e.amount), a: pw.TextAlign.right)]),
          ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey700, width: .8))),
        child: pw.Row(children: [pw.Expanded(child: td('Jumla', b: true)), td(money(exp), b: true, a: pw.TextAlign.right)]),
      ),
      pw.SizedBox(height: 6),
      _t('* nje ya stock', c: _grey, size: 7.5),
      sec('HESABU YA LEO'),
      kv('Mauzo', sales),
      kv('Mtaji wa vilivyouzwa', capital),
      kv('Faida ya bidhaa', profit, b: true),
      kv('Gharama', exp),
      kv('Faida halisi ya leo', net, b: true, c: _blue),
      pw.Spacer(),
      pw.Divider(color: PdfColors.grey300),
      pw.Row(children: [
        _t('Imetengenezwa na Ummu Ayman app', c: _grey, size: 7),
        pw.Spacer(),
        _t('Ukurasa 1 / 1', c: _grey, size: 7),
      ]),
    ]),
  ));
  return doc.save();
}
