import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../services/pdf.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';

/// RIPOTI — WIKI · MWEZI · MWAKA
///  1. Faida halisi (kubwa) + Mauzo · Mtaji · Gharama
///  2. Grafu: siku/wiki/miezi yenye biashara tu; gusa nguzo = ripoti ya kipindi hicho
///  3. Bidhaa: zilizouzika zaidi / zilizouzwa kidogo (IDADI · MAUZO · MTAJI · FAIDA)
///  4. Gharama za kipindi + Jumla, kisha kadi ya PDF (Pakua PDF · Shiriki)
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
  Map<String, Variant> _byName = {};
  List<Expense> _expenses = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _f = _fetch();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final ps = await Api.i.products();
      if (mounted) {
        setState(() => _byName = {for (final v in ps.expand((p) => p.variants)) v.name: v});
      }
    } catch (_) {}
  }

  Future<Report> _fetch() async {
    final r = await Api.i.report(_period, _anchor);
    _last = r;
    _loadExpenses(r);
    return r;
  }

  /// Gharama za wiki kwa jina (kutoka daily sheets za siku zake)
  Future<void> _loadExpenses(Report r) async {
    _expenses = [];
    if (r.period != Period.week) return;
    try {
      final days = r.rows.map((x) => DateTime.parse(x.key)).toList();
      final sheets = await Future.wait(days.map((d) => Api.i.daily(d)));
      final map = <String, int>{};
      for (final s in sheets) {
        for (final e in s.expenses) {
          map[e.name] = (map[e.name] ?? 0) + e.amount;
        }
      }
      final list = map.entries
          .map((e) => Expense(name: e.key, amount: e.value))
          .where((e) => e.amount > 0)
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));
      if (mounted) setState(() => _expenses = list);
    } catch (_) {}
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
      FocusScope.of(context).unfocus();
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DayReportScreen(date: DateTime.parse(r.key))));
    } else if (_period == Period.month) {
      _setPeriod(Period.week, DateTime.parse(r.key));
    } else {
      final p = r.key.split('-');
      _setPeriod(Period.month, DateTime(int.parse(p[0]), int.parse(p[1]), 1));
    }
  }

  String _range(Report r) {
    switch (r.period) {
      case Period.week:
        final s = r.anchor.subtract(Duration(days: r.anchor.weekday - 1));
        final e = s.add(const Duration(days: 6));
        final m1 = monthsSw[s.month - 1], m2 = monthsSw[e.month - 1];
        return s.month == e.month ? '${s.day} – ${e.day} $m2 ${e.year}' : '${s.day} $m1 – ${e.day} $m2 ${e.year}';
      case Period.month:
        return '${monthsSw[r.anchor.month - 1]} ${r.anchor.year}';
      case Period.year:
        return '${r.anchor.year}';
    }
  }

  Future<void> _pdf({required bool share}) async {
    final r = _last;
    if (r == null) return;
    setState(() => _busy = true);
    try {
      final shop = await Api.i.shop();
      final bytes = await reportPdf(r, shop);
      final name = 'ripoti-${r.period.noun}-${iso(r.anchor)}.pdf';
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: name);
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Ripoti', subtitle: 'Wiki · mwezi · mwaka'),
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
    final active = r.rows.where((x) => x.s.sales > 0).toList();
    var best = -1;
    for (var i = 0; i < active.length; i++) {
      if (best < 0 || active[i].s.net > active[best].s.net) best = i;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          IconButton(onPressed: () => _move(-1), icon: const Icon(Icons.chevron_left_rounded, color: C.blue)),
          Expanded(
            child: Text(_range(r), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
          ),
          IconButton(
            onPressed: r.hasNext ? () => _move(1) : null,
            icon: Icon(Icons.chevron_right_rounded, color: r.hasNext ? C.blue : const Color(0xFFCBD5E1)),
          ),
        ]),
      ),
      _SummaryCard('Faida halisi ya ${r.period.noun}', r.summary),
      SectionTitle(r.period.chartTitle,
          trailing: r.period == Period.week
              ? 'gusa siku kuona ripoti yake'
              : r.period == Period.month
                  ? 'gusa wiki kuona ripoti yake'
                  : 'gusa mwezi kuona ripoti yake',
          padding: const EdgeInsets.fromLTRB(2, 22, 2, 10)),
      Box(
        radius: 14,
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
        child: _Bars(rows: active, best: best, onTap: (i) => _tapRow(active[i])),
      ),
      if (r.period == Period.month) ...[
        const SectionTitle('Wiki za mwezi', padding: EdgeInsets.fromLTRB(2, 22, 2, 10)),
        _PeriodRows(rows: r.rows, label: _weekLabel, currentNote: 'Wiki hii · inaendelea', onTap: _tapRow),
      ],
      if (r.period == Period.year) ...[
        const SectionTitle('Miezi ya mwaka', padding: EdgeInsets.fromLTRB(2, 22, 2, 10)),
        _PeriodRows(rows: r.rows, label: (x) => x.label, currentNote: 'Mwezi huu · inaendelea', onTap: _tapRow),
      ],
      if (r.top.isNotEmpty) ...[
        const SectionTitle('Zilizouzika zaidi', padding: EdgeInsets.fromLTRB(2, 24, 2, 10)),
        _RankedList(r.top, _byName, startAt: 1),
      ],
      if (r.low.isNotEmpty) ...[
        const SectionTitle('Zilizouzwa kidogo', padding: EdgeInsets.fromLTRB(2, 22, 2, 10)),
        _RankedList(r.low, _byName, startAt: 1),
      ],
      if (r.unsold.isNotEmpty) ...[
        const SectionTitle('Hazijauzwa', padding: EdgeInsets.fromLTRB(2, 22, 2, 10)),
        Box(
          child: Column(children: [
            for (var i = 0; i < r.unsold.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: C.line))),
                child: Row(children: [
                  Expanded(child: Text(r.unsold[i].name, style: const TextStyle(fontSize: 13.5))),
                  Text('zipo ${r.unsold[i].qty}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.muted)),
                ]),
              ),
          ]),
        ),
      ],
      SectionTitle('Gharama za ${r.period.noun}', trailing: 'Jumla ${money(r.summary.expenses)}', padding: const EdgeInsets.fromLTRB(2, 24, 2, 6)),
      if (_expenses.isNotEmpty)
        for (final e in _expenses) _ExpenseLine(e.name, money(e.amount))
      else
        _ExpenseLine('Gharama', money(r.summary.expenses)),
      const Divider(height: 1, thickness: 1.2, color: C.text),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(children: [
          const Expanded(child: Text('Jumla', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800))),
          Text(money(r.summary.expenses), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, fontFeatures: tabular)),
        ]),
      ),
      const SectionTitle('Stock', padding: EdgeInsets.fromLTRB(2, 22, 2, 10)),
      Box(
        child: IntrinsicHeight(
          child: Row(children: [
            Expanded(child: _top('Mtaji uliopo dukani', money(r.capitalInShop))),
            const VerticalDivider(width: 1, color: C.line),
            Expanded(child: _top('Manunuzi ya ${r.period.noun}', money(r.purchases))),
          ]),
        ),
      ),
      const SizedBox(height: 22),
      Box(
        radius: 12,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: C.redSoft, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: const Text('PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: C.red)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ripoti ya ${r.period.noun}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
              Text(_range(r), style: const TextStyle(fontSize: 12, color: C.muted)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _PdfButton('Pakua PDF', Icons.download_rounded, busy: _busy, onTap: () => _pdf(share: false))),
        const SizedBox(width: 8),
        Expanded(child: _PdfButton('Shiriki', Icons.share_outlined, filled: true, onTap: () => _pdf(share: true))),
      ]),
    ]);
  }

  String _weekLabel(ReportRow x) {
    final s = DateTime.parse(x.key);
    final e = s.add(const Duration(days: 6));
    return '${s.day} – ${e.day} ${monthsShort[e.month - 1]}';
  }

  Widget _top(String l, String v) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: const TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, fontFeatures: tabular)),
        ]),
      );
}

// ======================================================================= vipande

/// Kadi ya faida halisi + Mauzo · Mtaji · Gharama
class _SummaryCard extends StatelessWidget {
  final String title;
  final Summary s;
  const _SummaryCard(this.title, this.s);
  @override
  Widget build(BuildContext context) => Box(
        radius: 16,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          FittedBox(
            child: Text(money(s.net), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: C.blue, fontFeatures: tabular)),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: C.line)),
          IntrinsicHeight(
            child: Row(children: [
              Expanded(child: _Mini('Mauzo', money(s.sales))),
              const VerticalDivider(width: 1, color: C.line),
              Expanded(child: _Mini('Mtaji', money(s.capital))),
              const VerticalDivider(width: 1, color: C.line),
              Expanded(child: _Mini('Gharama', money(s.expenses))),
            ]),
          ),
        ]),
      );
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;
  const _Mini(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: C.muted)),
          const SizedBox(height: 2),
          FittedBox(
            child: Text(value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, fontFeatures: tabular)),
          ),
        ]),
      );
}

/// Bidhaa zilizopangwa kwa namba (IDADI · MAUZO · MTAJI · FAIDA)
class _RankedList extends StatelessWidget {
  final List<NameQty> rows;
  final Map<String, Variant> byName;
  final int startAt;
  const _RankedList(this.rows, this.byName, {this.startAt = 1});
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final (i, x) in rows.indexed) ...[
          Box(
            radius: 12,
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SizedBox(
                  width: 16,
                  child: Text('${i + startAt}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.faint)),
                ),
                Expanded(
                  child: Text(x.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: MiniStat('Idadi', '${x.qty}')),
                Expanded(child: MiniStat('Mauzo', _mauzo(x))),
                Expanded(child: MiniStat('Mtaji', _mtaji(x))),
                Expanded(child: MiniStat('Faida', money(x.profit), bold: true, color: C.blue)),
              ]),
            ]),
          ),
          const SizedBox(height: 8),
        ],
      ]);

  String _mauzo(NameQty x) {
    final v = byName[x.name];
    return v == null ? '–' : money(x.qty * v.selling);
  }

  String _mtaji(NameQty x) {
    final v = byName[x.name];
    return v == null ? '–' : money(x.qty * v.buying);
  }
}

/// Mistari ya wiki/miezi (Mwezi: WIKI ZA MWEZI; Mwaka: MIEZI YA MWAKA)
class _PeriodRows extends StatelessWidget {
  final List<ReportRow> rows;
  final String Function(ReportRow) label;
  final String currentNote;
  final ValueChanged<ReportRow> onTap;
  const _PeriodRows({required this.rows, required this.label, required this.currentNote, required this.onTap});
  @override
  Widget build(BuildContext context) => Box(
        child: Column(children: [
          for (var i = 0; i < rows.length; i++)
            InkWell(
              onTap: () => onTap(rows[i]),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: C.line))),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label(rows[i]), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      if (rows[i].current)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(currentNote, style: const TextStyle(fontSize: 11.5, color: C.muted)),
                        ),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('faida', style: TextStyle(fontSize: 10.5, color: C.muted)),
                    Text(money(rows[i].s.net),
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: C.blue, fontFeatures: tabular)),
                  ]),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: C.faint),
                ]),
              ),
            ),
        ]),
      );
}

class _ExpenseLine extends StatelessWidget {
  final String name;
  final String amount;
  const _ExpenseLine(this.name, this.amount);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        child: Row(children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13.5, color: C.text2))),
          Text(amount, style: const TextStyle(fontSize: 13.5, color: C.text2, fontFeatures: tabular)),
        ]),
      );
}

/// Kitufe cha PDF: Pakua PDF (mpaka wa bluu) au Shiriki (bluu iliyojaa)
class _PdfButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final bool busy;
  final VoidCallback? onTap;
  const _PdfButton(this.label, this.icon, {this.filled = false, this.busy = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : C.blue;
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: filled ? C.blue : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: C.blue, width: 1.2),
        ),
        child: Center(
          child: busy
              ? DotsLoader(color: fg, size: 5)
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: fg)),
                ]),
        ),
      ),
    );
  }
}

/// Nguzo za faida halisi: thamani juu, bora = bluu nzito, gusa kuona ripoti
class _Bars extends StatefulWidget {
  final List<ReportRow> rows;
  final int best;
  final ValueChanged<int> onTap;
  const _Bars({required this.rows, required this.best, required this.onTap});
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
    if (rows.isEmpty) {
      return const SizedBox(height: 80, child: Center(child: Text('Hakuna mauzo kipindi hiki', style: TextStyle(color: C.muted))));
    }
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
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onTap(i),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: dense ? 2 : 4),
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Opacity(
                          opacity: g,
                          child: FittedBox(
                            child: Text(moneyBar(rows[i].s.net),
                                style: TextStyle(
                                  fontSize: dense ? 9.5 : 10.5,
                                  fontWeight: i == widget.best ? FontWeight.w800 : FontWeight.w600,
                                  color: i == widget.best ? C.blue : C.muted,
                                )),
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
                        ),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          Row(children: [
            for (final r in rows)
              Expanded(
                child: Text(r.short,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: dense ? 9.5 : 11,
                      color: r.current ? C.blue : C.muted,
                      fontWeight: r.current ? FontWeight.w800 : FontWeight.w600,
                    )),
              ),
          ]),
        ]);
      },
    );
  }
}

// ======================================================================= RIPOTI YA SIKU
class DayReportScreen extends StatefulWidget {
  final DateTime date;
  const DayReportScreen({super.key, required this.date});
  @override
  State<DayReportScreen> createState() => _DayReportScreenState();
}

class _DayReportScreenState extends State<DayReportScreen> {
  late Future<(DayDetail, Map<String, Variant>, List<Expense>)> _f = _load();

  Future<(DayDetail, Map<String, Variant>, List<Expense>)> _load() async {
    final res = await Future.wait([Api.i.day(widget.date), Api.i.products(), Api.i.daily(widget.date)]);
    final d = res[0] as DayDetail;
    final ps = res[1] as List<Product>;
    final sheet = res[2] as DailySheet;
    final by = {for (final v in ps.expand((p) => p.variants)) v.name: v};
    return (d, by, sheet.expenses.where((e) => e.amount > 0).toList());
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.date;
    return Scaffold(
      appBar: pageBar('${daysSw[d.weekday - 1]}, ${d.day} ${monthsShort[d.month - 1]}', subtitle: 'Ripoti ya siku', back: true),
      body: FutureBuilder<(DayDetail, Map<String, Variant>, List<Expense>)>(
        future: _f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Loading();
          if (s.hasError) return ErrorView(s.error!, onRetry: () => setState(() => _f = _load()));
          final (day, by, expenses) = s.data!;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
            _SummaryCard('Faida halisi ya siku', day.summary),
            SectionTitle('Bidhaa zilizouzika zaidi',
                trailing: '${day.items.length} bidhaa', padding: const EdgeInsets.fromLTRB(2, 24, 2, 10)),
            if (day.items.isEmpty)
              const Padding(padding: EdgeInsets.fromLTRB(2, 0, 2, 4), child: Text('Hakuna mauzo siku hii', style: TextStyle(fontSize: 13, color: C.muted)))
            else
              _RankedList(day.items, by),
            const SectionTitle('Gharama', padding: EdgeInsets.fromLTRB(2, 24, 2, 6)),
            if (expenses.isEmpty)
              const Padding(padding: EdgeInsets.fromLTRB(2, 0, 2, 4), child: Text('Bado hakuna gharama', style: TextStyle(fontSize: 13, color: C.muted)))
            else
              for (final e in expenses) _ExpenseLine(e.name, money(e.amount)),
            const Divider(height: 1, thickness: 1.2, color: C.text),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: Row(children: [
                const Expanded(child: Text('Jumla', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800))),
                Text(money(day.summary.expenses),
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, fontFeatures: tabular)),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
