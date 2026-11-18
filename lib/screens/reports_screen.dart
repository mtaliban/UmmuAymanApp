import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../services/pdf.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';

/// RIPOTI — inaanzia WIKI (siku moja iko Nyumbani)
///  Wiki · Mwezi · Mwaka   + mishale ‹ ›
///  1. Faida halisi (kubwa) + hesabu kamili
///  2. Grafu ya faida halisi (kila siku / wiki / mwezi), thamani juu ya kila nguzo, bora = bluu nzito
///  3. Jedwali (Mauzo · Mtaji · Gharama · Faida) -> gusa siku = dirisha la siku; gusa wiki = wiki hiyo; gusa mwezi = mwezi huo
///  4. Bidhaa: zinazouzika zaidi / zimeuzwa kidogo / hazijauzwa
///  5. Stock: mtaji uliopo dukani, manunuzi ya kipindi
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Period _period = Period.week;
  DateTime _anchor = dayOnly(DateTime.now());
  late Future<Report> _f;
  Report? _last;

  @override
  void initState() {
    super.initState();
    _f = _fetch();
  }

  Future<Report> _fetch() async {
    final r = await Api.i.report(_period, _anchor);
    _last = r;
    return r;
  }

  void _load() => setState(() => _f = _fetch());

  void _setPeriod(Period p, [DateTime? anchor]) {
    _period = p;
    _anchor = anchor ?? dayOnly(DateTime.now());
    _load();
  }

  void _move(int d) {
    switch (_period) {
      case Period.week:
        _anchor = _anchor.add(Duration(days: 7 * d));
        break;
      case Period.month:
        _anchor = DateTime(_anchor.year, _anchor.month + d, 1);
        break;
      case Period.year:
        _anchor = DateTime(_anchor.year + d, 1, 1);
        break;
    }
    _load();
  }

  Future<void> _tapRow(ReportRow r) async {
    if (_period == Period.week) {
      await showCenterDialog(context, builder: (_) => _DayDialog(DateTime.parse(r.key)));
    } else if (_period == Period.month) {
      _setPeriod(Period.week, DateTime.parse(r.key));
    } else {
      final p = r.key.split('-');
      _setPeriod(Period.month, DateTime(int.parse(p[0]), int.parse(p[1]), 1));
    }
  }

  Future<void> _pdf() async {
    final r = _last;
    if (r == null) return;
    final shop = await Api.i.shop();
    final bytes = await reportPdf(r, shop);
    await Printing.sharePdf(bytes: bytes, filename: 'ripoti-${r.period.noun}-${iso(r.anchor)}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Ripoti', action: SmallButton('Pakua PDF', onTap: _pdf)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 30), children: [
        Segmented(items: Period.values.map((p) => p.label).toList(), index: _period.index, onChanged: (i) => _setPeriod(Period.values[i])),
        FutureBuilder<Report>(
          future: _f,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return const Loading();
            if (s.hasError) return ErrorView(s.error!, onRetry: _load);
            return _body(s.data!);
          },
        ),
      ]),
    );
  }

  Widget _body(Report r) {
    final best = r.bestIndex;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // tarehe
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          IconButton(onPressed: () => _move(-1), icon: const Icon(Icons.chevron_left_rounded, color: C.blue)),
          Expanded(child: Text(r.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          IconButton(onPressed: r.hasNext ? () => _move(1) : null, icon: Icon(Icons.chevron_right_rounded, color: r.hasNext ? C.blue : const Color(0xFFCBD5E1))),
        ]),
      ),
      // 1. faida halisi + hesabu
      Box(
        radius: 16,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Faida halisi', style: TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w600)),
          Text(money(r.summary.net), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: C.blue, fontFeatures: tabular)),
          const SizedBox(height: 10),
          StatRow('Mauzo', r.summary.sales, size: 14),
          StatRow('Mtaji wa vilivyouzwa', r.summary.capital, size: 14),
          StatRow('Faida ya bidhaa', r.summary.productProfit, bold: true, topLine: true, size: 14),
          StatRow('Gharama', r.summary.expenses, size: 14),
          StatRow('Faida halisi', r.summary.net, bold: true, topLine: true, blue: true, size: 14),
        ]),
      ),
      // 2. grafu
      SectionTitle(r.period.chartTitle),
      Box(
        radius: 16,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        child: Column(children: [
          Row(children: [
            Expanded(child: Text(r.period.chartTitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.text2))),
            if (best >= 0)
              Text.rich(TextSpan(children: [
                TextSpan(text: '${r.period.bestLabel}: ', style: const TextStyle(color: C.muted)),
                TextSpan(text: r.rows[best].best, style: const TextStyle(color: C.blue, fontWeight: FontWeight.w800)),
              ]), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          _Bars(rows: r.rows, best: best),
        ]),
      ),
      // 3. jedwali
      SectionTitle(r.period.byLabel),
      _table(r),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
        child: Text(
          r.period == Period.week
              ? 'Gusa siku kuona ilichouza'
              : r.period == Period.month
                  ? 'Gusa wiki kuona siku zake'
                  : 'M = milioni · k = elfu · gusa mwezi kuona wiki zake',
          style: const TextStyle(fontSize: 11.5, color: C.muted),
        ),
      ),
      // 4. bidhaa
      const SectionTitle('Bidhaa'),
      _list('ZINAZOUZIKA ZAIDI', r.top, 'IDADI'),
      const SizedBox(height: 10),
      _list('ZIMEUZWA KIDOGO', r.low, 'IDADI'),
      const SizedBox(height: 10),
      _list('HAZIJAUZWA', r.unsold, 'ZIPO', profit: false),
      // 5. stock
      const SectionTitle('Stock'),
      Box(
        child: IntrinsicHeight(
          child: Row(children: [
            Expanded(child: _top('Mtaji uliopo dukani', money(r.capitalInShop))),
            const VerticalDivider(width: 1, color: C.line),
            Expanded(child: _top('Manunuzi ya ${r.period.noun}', money(r.purchases))),
          ]),
        ),
      ),
    ]);
  }

  Widget _top(String l, String v) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: const TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(v, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, fontFeatures: tabular)),
        ]),
      );

  Widget _table(Report r) {
    final short = r.period == Period.year;
    String m(int v) => short ? moneyShort(v) : money(v);
    const w = <double?>[null, 70, 70, 62, 70];
    Widget n(double? wd, String t, {bool bold = false, Color? c}) =>
        tableCell(wd, Text(t, textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w400, color: c, fontFeatures: tabular)));
    return Column(children: [
      TableHead([r.period.colLabel, 'MAUZO', 'MTAJI', 'GHARAMA', 'FAIDA'], w),
      for (final x in r.rows)
        InkWell(
          onTap: () => _tapRow(x),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: x.label),
                    if (x.current) TextSpan(text: r.period == Period.week ? '  leo' : '  inaendelea', style: const TextStyle(fontSize: 10.5, color: C.muted, fontWeight: FontWeight.w600)),
                  ]), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  if (x.sub.isNotEmpty) Text(x.sub, style: const TextStyle(fontSize: 11, color: C.muted)),
                ]),
              ),
              n(w[1], m(x.s.sales)),
              n(w[2], m(x.s.capital), c: C.text2),
              n(w[3], m(x.s.expenses), c: C.text2),
              n(w[4], m(x.s.net), bold: true),
            ]),
          ),
        ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(children: [
          const Expanded(child: Text('Jumla', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800))),
          n(w[1], m(r.summary.sales), bold: true),
          n(w[2], m(r.summary.capital), bold: true),
          n(w[3], m(r.summary.expenses), bold: true),
          n(w[4], m(r.summary.net), bold: true, c: C.blue),
        ]),
      ),
    ]);
  }

  Widget _list(String title, List<NameQty> rows, String qtyLabel, {bool profit = true}) => Box(
        child: Column(children: [
          Container(
            color: C.head,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: C.blue, letterSpacing: .4))),
              SizedBox(width: 48, child: Text(qtyLabel, textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: C.blue))),
              if (profit) const SizedBox(width: 90, child: Text('FAIDA', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: C.blue))),
            ]),
          ),
          if (rows.isEmpty) const Padding(padding: EdgeInsets.all(14), child: Text('Hakuna', style: TextStyle(color: C.muted))),
          for (final x in rows)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
              child: Row(children: [
                Expanded(child: Text(x.name, style: const TextStyle(fontSize: 13.5))),
                SizedBox(width: 48, child: Text('${x.qty}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13.5, fontFeatures: tabular))),
                if (profit) SizedBox(width: 90, child: Text(money(x.profit), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, fontFeatures: tabular))),
              ]),
            ),
        ]),
      );
}

/// Nguzo za faida halisi: thamani juu, bora = bluu nzito, kipindi kinachoendelea = mistari
class _Bars extends StatefulWidget {
  final List<ReportRow> rows;
  final int best;
  const _Bars({required this.rows, required this.best});
  @override
  State<_Bars> createState() => _BarsState();
}

class _BarsState extends State<_Bars> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    if (rows.isEmpty) return const SizedBox(height: 60, child: Center(child: Text('Hakuna data', style: TextStyle(color: C.muted))));
    final mx = rows.fold<int>(1, (a, r) => r.s.net > a ? r.s.net : a);
    final dense = rows.length > 8;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final g = Curves.easeOutCubic.transform(_c.value);
        return Column(children: [
          SizedBox(
            height: 150,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < rows.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: dense ? 2 : 4),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Opacity(
                        opacity: g,
                        child: FittedBox(
                          child: Text(moneyBar(rows[i].s.net),
                              style: TextStyle(fontSize: dense ? 9.5 : 10.5, fontWeight: i == widget.best ? FontWeight.w800 : FontWeight.w600, color: i == widget.best ? C.blue : C.muted)),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        height: (118 * (rows[i].s.net <= 0 ? 0.02 : rows[i].s.net / mx) * g).clamp(3.0, 118.0).toDouble(),
                        constraints: const BoxConstraints(maxWidth: 34),
                        decoration: BoxDecoration(
                          color: i == widget.best ? C.blue : const Color(0xFFBAE6FD),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(2)),
                        ),
                        foregroundDecoration: rows[i].current ? _Stripes() : null,
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          Row(children: [
            for (final r in rows) Expanded(child: Text(r.short, textAlign: TextAlign.center, style: TextStyle(fontSize: dense ? 9.5 : 11, color: C.muted, fontWeight: FontWeight.w600))),
          ]),
        ]);
      },
    );
  }
}

/// mistari ya kipindi kinachoendelea
class _Stripes extends Decoration {
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _StripesPainter();
}

class _StripesPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final s = cfg.size!;
    final rect = offset & s;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(6), topRight: const Radius.circular(6)));
    final p = Paint()
      ..color = const Color(0x80FFFFFF)
      ..strokeWidth = 3;
    for (double x = -s.height; x < s.width; x += 7) {
      canvas.drawLine(Offset(rect.left + x, rect.bottom), Offset(rect.left + x + s.height, rect.top), p);
    }
    canvas.restore();
  }
}

/// Dirisha la siku moja (bidhaa zilizouzwa + hesabu ya siku)
class _DayDialog extends StatelessWidget {
  final DateTime date;
  const _DayDialog(this.date);
  @override
  Widget build(BuildContext context) => FutureBuilder<DayDetail>(
        future: Api.i.day(date),
        builder: (c, s) {
          if (!s.hasData) return const SizedBox(height: 180, child: Loading());
          final d = s.data!;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 18, 16, 10), child: DialogHeader(d.label)),
            Flexible(
              child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 0, 18, 16), children: [
                const TableHead(['BIDHAA', 'IDADI', 'FAIDA'], [null, 44, 80]),
                if (d.items.isEmpty) const Padding(padding: EdgeInsets.all(14), child: Text('Hakuna mauzo siku hii', style: TextStyle(color: C.muted))),
                for (final x in d.items)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
                    child: Row(children: [
                      Expanded(child: Text(x.name, style: const TextStyle(fontSize: 14))),
                      SizedBox(width: 44, child: Text('${x.qty}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 14))),
                      SizedBox(width: 80, child: Text(money(x.profit), textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFeatures: tabular))),
                    ]),
                  ),
                const SizedBox(height: 8),
                StatRow('Mauzo', d.summary.sales, size: 14),
                StatRow('Mtaji wa vilivyouzwa', d.summary.capital, size: 14),
                StatRow('Gharama', d.summary.expenses, size: 14),
                StatRow('Faida halisi', d.summary.net, bold: true, topLine: true, blue: true, size: 15.5),
              ]),
            ),
          ]);
        },
      );
}
