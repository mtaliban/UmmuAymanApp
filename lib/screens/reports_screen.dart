import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../services/report_pdf.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/app_icons.dart';
import '../widgets/ui.dart';

/// RIPOTI — vipindi 4: SIKU · WIKI · MWEZI · MWAKA
///  1. Tab + ‹ label › (› imefifia kwa kipindi cha leo)
///  2. Kadi ya faida halisi (34/w500 bluu + maneno ya Kiswahili) na safu tatu
///     sawa: Mauzo · Mtaji · Gharama (kila moja na kiasi chake kwa maneno).
///  3. Siku: hakuna grafu. Wiki: nguzo 7 za siku. Mwezi: nguzo 5 za wiki.
///     Mwaka: miezi 12 kwa mistari miwili (Jan–Jun, Jul–Des). Gusa nguzo
///     kuchagua; gusa tena kufungua ripoti ya kipindi chake.
///  4. Zilizouzika zaidi (5 za juu) na zilizouzwa kidogo (za chini) — namba,
///     mstari wa faida na idadi kwenye kidonge.
///  5. Kadi ya PDF yenye Pakua na Shiriki.
/// API: P1 GET /reports/day/{date} · P2–P4 GET /reports/{period}?date=
const _periods = ['day', 'week', 'month', 'year'];
const _tabs = ['Siku', 'Wiki', 'Mwezi', 'Mwaka'];

/// Rangi za muundo wa Ripoti (vidoti vya safu na grafu) — zote ziko theme.dart.
const _mauzoDot = C.dotSales;
const _mtajiDot = C.dotCapital;
const _gharamaDot = C.dotExpense;
const _fill = C.headBg; // #F3F4F6 — kichwa cha jedwali na kidonge cha idadi

/// Kiasi pamoja na "Sh" (shilingi) — kama zinavyoonekana kwenye risiti.
String _sh(num v) => '${money(v)} Sh';

/// "siku" / "wiki" / "mwezi" / "mwaka"
String _unit(String period) => const {'day': 'siku', 'week': 'wiki', 'month': 'mwezi', 'year': 'mwaka'}[period] ?? period;

/// Aina ya ripoti inayofunguliwa kwa kugusa nguzo
const _child = {'week': 'day', 'month': 'week', 'year': 'month'};

/// Kichwa cha grafu — nguzo za wiki ni siku, za mwezi ni wiki, za mwaka ni miezi.
String _chartTitle(String period) =>
    const {'week': 'Faida kila siku', 'month': 'Faida kila wiki', 'year': 'Faida kila mwezi'}[period] ?? 'Faida';

/// Kichwa cha ukurasa wa kipindi (short_label)
String _detailTitle(String period, DateTime d) => switch (period) {
      'day' => '${daysSw[d.weekday - 1]}, ${d.day} ${monthsShort[d.month - 1]}',
      'week' => _weekText(d),
      _ => '${monthsSw[d.month - 1]} ${d.year}',
    };

/// "15 – 21 Nov 2026" (wiki inaanza Jumapili)
String _weekText(DateTime d) {
  final a = d.subtract(Duration(days: d.weekday % 7));
  final b = a.add(const Duration(days: 6));
  return a.month == b.month
      ? '${a.day} – ${b.day} ${monthsShort[b.month - 1]} ${b.year}'
      : '${a.day} ${monthsShort[a.month - 1]} – ${b.day} ${monthsShort[b.month - 1]} ${b.year}';
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _tab = 0;
  DateTime _d = dayOnly(DateTime.now());
  late Future<Report> _f = _fetch();
  bool _busy = false;

  Future<Report> _fetch() => Api.i.report(_periods[_tab], _d);

  void _reload() => setState(() => _f = _fetch());

  void _go(int i) {
    setState(() {
      _tab = i;
      _d = dayOnly(DateTime.now());
      _f = _fetch();
    });
  }

  void _shift(int dir) {
    setState(() {
      _d = switch (_tab) {
        0 => _d.add(Duration(days: dir)),
        1 => _d.add(Duration(days: 7 * dir)),
        2 => DateTime(_d.year, _d.month + dir, 1),
        _ => DateTime(_d.year + dir, 1, 1),
      };
      _f = _fetch();
    });
  }

  /// Kugusa nguzo: wiki → siku · mwezi → wiki · mwaka → mwezi
  Future<void> _openBar(RBar b) async {
    final next = _child[_periods[_tab]];
    final d = DateTime.tryParse(b.key);
    if (next == null || d == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReportDetailScreen(period: next, date: d, title: _detailTitle(next, d)),
    ));
  }

  Future<void> _pdf(Report r, {required bool share}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final shop = await Api.i.shop();
      if (share) {
        await shareReportPdf(r, shop);
      } else {
        await downloadReportPdf(r, shop);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Ripoti', subtitle: 'Siku · wiki · mwezi · mwaka', drop: true),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), children: [
        Segmented(items: _tabs, index: _tab, onChanged: _go),
        FutureBuilder<Report>(
          future: _f,
          builder: (c, s) {
            final r = s.data;
            final error = s.hasError;
            final waiting = s.connectionState != ConnectionState.done;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 10, 2, 12),
                child: _PeriodNav(
                  label: r?.label ?? '',
                  prev: r?.hasPrev ?? false,
                  next: r?.hasNext ?? false,
                  onPrev: () => _shift(-1),
                  onNext: () => _shift(1),
                ),
              ),
              if (error)
                Padding(padding: const EdgeInsets.only(top: 24), child: ErrorView(s.error!, onRetry: _reload))
              else if (r == null || waiting)
                const SizedBox(height: 80)
              else
                _Body(r: r, busy: _busy, onBarTap: r.isDay ? null : _openBar, onPdf: (share) => _pdf(r, share: share)),
            ]);
          },
        ),
      ]),
    );
  }
}

/// Ukurasa mpya uliofunguliwa kwa kugusa nguzo (R06 · R11 · R15)
class ReportDetailScreen extends StatefulWidget {
  final String period;
  final DateTime date;
  final String title;
  const ReportDetailScreen({super.key, required this.period, required this.date, required this.title});
  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late Future<Report> _f = Api.i.report(widget.period, widget.date);
  bool _busy = false;

  void _reload() => setState(() => _f = Api.i.report(widget.period, widget.date));

  /// Gusa nguzo ndani ya ukurasa uliofunguliwa: wiki → siku n.k.
  Future<void> _openBar(RBar b) async {
    final next = _child[widget.period];
    final d = DateTime.tryParse(b.key);
    if (next == null || d == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReportDetailScreen(period: next, date: d, title: _detailTitle(next, d)),
    ));
  }

  Future<void> _pdf(Report r, {required bool share}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final shop = await Api.i.shop();
      if (share) {
        await shareReportPdf(r, shop);
      } else {
        await downloadReportPdf(r, shop);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar(widget.title, subtitle: 'Ripoti ya ${_unit(widget.period)}', flatBack: true),
      body: FutureBuilder<Report>(
        future: _f,
        builder: (c, s) {
          if (s.hasError) return ErrorView(s.error!, onRetry: _reload);
          final r = s.data;
          if (r == null || s.connectionState != ConnectionState.done) return const SizedBox.expand();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [_Body(r: r, busy: _busy, onBarTap: r.isDay ? null : _openBar, onPdf: (share) => _pdf(r, share: share))],
          );
        },
      ),
    );
  }
}

// ======================================================================= mwili

class _Body extends StatelessWidget {
  final Report r;
  final bool busy;
  final ValueChanged<RBar>? onBarTap;
  final ValueChanged<bool> onPdf;
  const _Body({required this.r, required this.busy, this.onBarTap, required this.onPdf});

  /// Bidhaa 5 za juu na 5 za chini za kipindi.
  /// Siku huja na bidhaa zote tu, kwa hiyo tunazipanga wenyewe.
  (List<RProduct>, List<RProduct>) _ranked() {
    final byQty = [for (final p in r.products) if (p.qty > 0) p]
      ..sort((a, b) => b.qty != a.qty ? b.qty.compareTo(a.qty) : b.sales.compareTo(a.sales));
    final top = (r.isDay ? byQty : [for (final p in r.top) if (p.qty > 0) p]).take(5).toList();
    final low = r.isDay
        ? ([for (final p in byQty) if (!top.contains(p)) p]..sort((a, b) => a.qty != b.qty ? a.qty.compareTo(b.qty) : a.sales.compareTo(b.sales)))
            .take(5)
            .toList()
        : [for (final p in r.low) if (p.qty > 0) p].take(5).toList();
    return (top, low);
  }

  @override
  Widget build(BuildContext context) {
    const gap = EdgeInsets.fromLTRB(2, 20, 2, 10);
    final (top, low) = _ranked();
    final w = <Widget>[
      _ProfitCard('Faida halisi ya ${r.title}', r.summary),
      if (!r.isDay) ...[
        SectionTitle(_chartTitle(r.period), trailing: 'gusa kuona ripoti yake', weight: FontWeight.w700, padding: gap),
        _ChartCard(bars: r.bars, onOpen: onBarTap),
      ],
      // Bidhaa 5 zilizouzika zaidi na 5 zenye mauzo ya chini; zisizouzika hazionyeshwi.
      if (top.isNotEmpty) ...[
        SectionTitle('Zilizouzika zaidi', trailing: '5 za juu', weight: FontWeight.w700, padding: gap),
        _ProductTable(top),
      ],
      if (low.isNotEmpty) ...[
        SectionTitle('Zilizouzwa kidogo', trailing: 'za chini', weight: FontWeight.w700, padding: gap),
        _ProductTable(low),
      ],
      const SizedBox(height: 20),
      _PdfCard(r, busy: busy, onPdf: onPdf),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: w);
  }
}

// ======================================================================= vipande

/// ‹ label › — mishale 22 (imefifia kama haiwezekani), label 15/w800
class _PeriodNav extends StatelessWidget {
  final String label;
  final bool prev, next;
  final VoidCallback onPrev, onNext;
  const _PeriodNav({required this.label, required this.prev, required this.next, required this.onPrev, required this.onNext});

  Widget _arrow(IconData icon, bool on, VoidCallback tap) => SizedBox(
        width: 38,
        height: 30,
        child: IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: on ? tap : null,
          icon: Icon(icon, size: 22, color: on ? C.profit : C.faint),
        ),
      );

  @override
  Widget build(BuildContext context) => Row(children: [
        _arrow(Icons.chevron_left_rounded, prev, onPrev),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, textAlign: TextAlign.center, style: Txt.period),
          ),
        ),
        _arrow(Icons.chevron_right_rounded, next, onNext),
      ]);
}

/// Kadi: faida halisi (34/w500 bluu + " Sh") na maneno yake, kisha
/// Mauzo · Mtaji · Gharama — kila safu sawa, na kiasi chake kwa maneno.
class _ProfitCard extends StatelessWidget {
  final String label;
  final Summary s;
  const _ProfitCard(this.label, this.s);

  @override
  Widget build(BuildContext context) => Box(
        radius: 16,
        border: C.rule,
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Txt.metric.copyWith(color: C.heading, fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(money(s.net), style: Txt.big44),
              const SizedBox(width: 5),
              Text('Sh', style: Txt.stat.copyWith(color: C.heading, fontWeight: FontWeight.w500)),
            ]),
          ),
          // Kiasi kwa maneno ya Kiswahili: 128,000 -> "Laki 1 na elfu 28"
          Text(amountInWords(s.net), style: Txt.note.copyWith(color: C.heading)),
          const SizedBox(height: 8),
          _MetricRow(_mauzoDot, 'Mauzo', s.sales),
          _MetricRow(_mtajiDot, 'Mtaji', s.capital),
          _MetricRow(_gharamaDot, 'Gharama', s.expenses),
        ]),
      );
}

/// Doti · jina (15) na maneno (12 kijivu) · kiasi 15/w500 kulia
class _MetricRow extends StatelessWidget {
  final Color color;
  final String name;
  final int amount;
  const _MetricRow(this.color, this.name, this.amount);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.rule))),
        child: Row(children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: Txt.metric),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(amountInWords(amount), maxLines: 1, style: Txt.note),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(_sh(amount), maxLines: 1, style: Txt.metricValue),
          ),
        ]),
      );
}

/// Fremu ya grafu (kadi 14, mpaka hafifu)
class _ChartCard extends StatelessWidget {
  final List<RBar> bars;
  final ValueChanged<RBar>? onOpen;
  const _ChartCard({required this.bars, this.onOpen});

  @override
  Widget build(BuildContext context) => Box(
        radius: 14,
        border: C.rule,
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        child: _BarChart(bars: bars, onOpen: onOpen),
      );
}

/// Grafu ya faida. Nguzo 8+ zinagawanywa mistari miwili (miezi 12 = 6 + 6).
/// Gusa nguzo kuichagua (bluu kuu); gusa tena kufungua ripoti yake.
/// `net == null` = kipindi bado hakijafika (mstari mwembamba, haugusiki).
class _BarChart extends StatefulWidget {
  final List<RBar> bars;
  final ValueChanged<RBar>? onOpen;
  const _BarChart({required this.bars, this.onOpen});

  @override
  State<_BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<_BarChart> {
  int _sel = -1;

  /// Nguzo yenye faida kubwa ndiyo ichaguliwe mwanzoni.
  int get _best {
    var best = -1;
    for (var i = 0; i < widget.bars.length; i++) {
      final n = widget.bars[i].net;
      if (n == null) continue;
      if (best < 0 || n > (widget.bars[best].net ?? 0)) best = i;
    }
    return best;
  }

  @override
  void initState() {
    super.initState();
    _sel = _best;
  }

  @override
  void didUpdateWidget(covariant _BarChart old) {
    super.didUpdateWidget(old);
    if (!identical(old.bars, widget.bars)) _sel = _best;
  }

  void _tap(int i) {
    final b = widget.bars[i];
    if (b.net == null) return;
    if (i == _sel && widget.onOpen != null) {
      widget.onOpen!(b);
    } else {
      setState(() => _sel = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bars = widget.bars;
    if (bars.isEmpty) return const SizedBox(height: 40);
    final per = bars.length > 7 ? (bars.length / 2).ceil() : bars.length;
    return Column(children: [
      for (var start = 0; start < bars.length; start += per) ...[
        if (start > 0) const Divider(height: 22, color: C.rule),
        _row(start, math.min(start + per, bars.length)),
      ],
    ]);
  }

  Widget _row(int start, int end) {
    final bars = widget.bars;
    final nets = [for (final b in bars) if (b.net != null) b.net!];
    final mx = nets.isEmpty ? 1 : nets.reduce(math.max);
    return Row(children: [
      for (var i = start; i < end; i++)
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: bars[i].net == null ? null : () => _tap(i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 18,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      // Bila data: hakuna namba kabisa (si maandishi hafifu).
                      bars[i].net == null ? '' : moneyBar(bars[i].net!),
                      style: Txt.chart.copyWith(color: i == _sel ? C.profit : C.heading),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(height: 108, child: Align(alignment: Alignment.bottomCenter, child: _bar(bars[i], i, mx))),
                const SizedBox(height: 6),
                SizedBox(
                  height: 18,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      bars[i].label,
                      style: Txt.chart.copyWith(
                        color: bars[i].net == null ? C.muted : (i == _sel ? C.profit : C.heading),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ]);
  }

  Widget _bar(RBar b, int i, int mx) {
    final n = b.net;
    final h = n == null ? 2.0 : (n <= 0 ? 5.0 : math.max(6.0, 8 + 98 * n / mx));
    return Container(
      height: h,
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 28),
      decoration: BoxDecoration(
        color: n == null ? C.rule : (i == _sel ? C.profit : C.bar),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5), bottom: Radius.circular(2)),
      ),
    );
  }
}

/// Jedwali la bidhaa: namba, jina (mistari 2) + mstari wa maendeleo, idadi
/// kwenye kidonge chenye upana maalum, faida (upana 104).
class _ProductTable extends StatelessWidget {
  final List<RProduct> rows;
  const _ProductTable(this.rows);

  @override
  Widget build(BuildContext context) {
    final mx = rows.map((r) => r.profit.abs()).reduce(math.max);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: C.rule), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Container(
            color: _fill,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: const Row(children: [
              Expanded(child: Text('BIDHAA', style: _head)),
              SizedBox(width: 48, child: Text('IDADI', style: _head, textAlign: TextAlign.center)),
              SizedBox(width: 104, child: Text('FAIDA', style: _head, textAlign: TextAlign.right)),
            ]),
          ),
          for (var i = 0; i < rows.length; i++) _row(rows[i], i, mx),
        ]),
      ),
    );
  }

  Widget _row(RProduct p, int i, int mx) => Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.rule))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: C.rankBg, shape: BoxShape.circle),
            child: Text('${i + 1}', style: Txt.badge),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Txt.row),
              const SizedBox(height: 6),
              _Progress(p.profit.abs() / (mx == 0 ? 1 : mx), negative: p.profit < 0),
            ]),
          ),
          SizedBox(
            width: 48,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _fill, borderRadius: BorderRadius.circular(8)),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text('${p.qty}', style: Txt.qty)),
              ),
            ),
          ),
          SizedBox(
            width: 104,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(_sh(p.profit),
                  textAlign: TextAlign.right,
                  style: Txt.rowProfit.copyWith(color: p.profit < 0 ? C.loss : C.profit)),
            ),
          ),
        ]),
      );

  static const _head = Txt.tableHead;
}

/// Mstari wa maendeleo chini ya jina la bidhaa:
/// track #E5E7EB · faida #4F8FC4 · hasara #EF4444.
class _Progress extends StatelessWidget {
  final double value;
  final bool negative;
  const _Progress(this.value, {required this.negative});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Container(
          height: 5,
          color: C.rankBg,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(.04, 1.0),
            child: ColoredBox(color: negative ? C.barLoss : C.bar),
          ),
        ),
      );
}

/// Kadi ya PDF (Ripoti ya siku/wiki/mwezi/mwaka + short_label) na vitufe
/// viwili vya mraba — Pakua PDF · Shiriki (sawa na vya ukurasa wa Risiti).
class _PdfCard extends StatelessWidget {
  final Report r;
  final bool busy;
  final ValueChanged<bool> onPdf;
  const _PdfCard(this.r, {required this.busy, required this.onPdf});

  @override
  Widget build(BuildContext context) => Box(
        radius: 14,
        border: C.rule,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 50,
            height: 42,
            decoration: BoxDecoration(color: C.netBg, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text('PDF', style: Txt.chip.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ripoti ya ${r.title}', style: Txt.item),
              Text(r.shortLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.note),
            ]),
          ),
          const SizedBox(width: 8),
          _ReportAction(AppIcons.download, busy: busy, onTap: () => onPdf(false)),
          const SizedBox(width: 8),
          _ReportAction(AppIcons.share2, onTap: () => onPdf(true)),
        ]),
      );
}

/// Kitufe cha mraba (44×44) cha pakua/shiriki — sawa na cha ukurasa wa Risiti.
class _ReportAction extends StatelessWidget {
  final String icon;
  final bool busy;
  final VoidCallback? onTap;
  const _ReportAction(this.icon, {this.busy = false, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: C.profit, width: 1.5),
          ),
          child: Center(child: busy ? const DotsLoader(color: C.profit, size: 5) : AppIcon(icon, size: 21, color: C.profit)),
        ),
      );
}
