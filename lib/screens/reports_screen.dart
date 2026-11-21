import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../services/report_pdf.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';

/// RIPOTI — vipindi 4: SIKU · WIKI · MWEZI · MWAKA
///  1. Tab + ‹ label › (› imefifia kwa kipindi cha leo)
///  2. Muhtasari: faida halisi (bluu 32/w800) + Mauzo · Mtaji · Gharama
///  3. Siku: jedwali la bidhaa zote + Jumla · Wiki/Mwezi/Mwaka: grafu ya faida
///     (gusa nguzo = ripoti ya kipindi chake) + zilizouzika zaidi/kidogo/hazijauzika
///  4. Kadi ya PDF + Pakua PDF · Shiriki
/// API: P1 GET /reports/day/{date} · P2–P4 GET /reports/{period}?date=
const _periods = ['day', 'week', 'month', 'year'];
const _tabs = ['Siku', 'Wiki', 'Mwezi', 'Mwaka'];

/// "siku" / "wiki" / "mwezi" / "mwaka"
String _unit(String period) => const {'day': 'siku', 'week': 'wiki', 'month': 'mwezi', 'year': 'mwaka'}[period] ?? period;

/// Aina ya ripoti inayofunguliwa kwa kugusa nguzo
const _child = {'week': 'day', 'month': 'week', 'year': 'month'};

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
      appBar: pageBar('Ripoti', subtitle: 'Siku · wiki · mwezi · mwaka'),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 120), children: [
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
                const Padding(padding: EdgeInsets.only(top: 40), child: Loading())
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
      appBar: pageBar(widget.title, subtitle: 'Ripoti ya ${_unit(widget.period)}', back: true, boxBack: true),
      body: FutureBuilder<Report>(
        future: _f,
        builder: (c, s) {
          if (s.hasError) return ErrorView(s.error!, onRetry: _reload);
          final r = s.data;
          if (r == null || s.connectionState != ConnectionState.done) return const Loading();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
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

  @override
  Widget build(BuildContext context) {
    final s = r.summary;
    final w = <Widget>[_SummaryCard('Faida halisi ya ${r.title}', s)];

    if (r.isDay) {
      if (r.products.isNotEmpty) {
        w.add(SectionTitle('Bidhaa zilizouzwa', trailing: '${r.products.length} bidhaa', padding: const EdgeInsets.fromLTRB(2, 20, 2, 10)));
        w.add(_Table(
          head: const ['BIDHAA', 'IDADI', 'MAUZO', 'FAIDA'],
          widths: const [null, 40, 82, 72],
          rows: [
            for (final p in r.products) [p.name, '${p.qty}', money(p.sales), money(p.profit)],
          ],
          total: ['Jumla', '${r.totalQty}', money(s.sales), money(s.productProfit)],
          blueLast: true,
        ));
      }
    } else {
      final unit = _unit(r.period);
      w.add(SectionTitle('Faida kila $unit', trailing: 'gusa $unit kuona ripoti yake', padding: const EdgeInsets.fromLTRB(2, 20, 2, 10)));
      w.add(Box(radius: 14, padding: const EdgeInsets.fromLTRB(6, 12, 6, 8), child: _BarChart(bars: r.bars, onTap: onBarTap)));
      if (r.top.isNotEmpty) {
        w.add(const SectionTitle('Zilizouzika zaidi', trailing: 'idadi kubwa', padding: EdgeInsets.fromLTRB(2, 20, 2, 10)));
        w.add(_Table(
          head: const ['BIDHAA', 'IDADI', 'FAIDA'],
          widths: const [null, 50, 86],
          blueLast: true,
          rows: [
            for (final p in r.top) [p.name, '${p.qty}', money(p.profit)],
          ],
        ));
      }
      if (r.low.isNotEmpty) {
        w.add(const SectionTitle('Zilizouzwa kidogo', trailing: 'idadi ndogo', padding: EdgeInsets.fromLTRB(2, 20, 2, 10)));
        w.add(_Table(
          head: const ['BIDHAA', 'IDADI', 'FAIDA'],
          widths: const [null, 50, 86],
          blueLast: true,
          rows: [
            for (final p in r.low) [p.name, '${p.qty}', money(p.profit)],
          ],
        ));
      }
      if (r.unsold.isNotEmpty) {
        w.add(SectionHeader('Hazijauzika kabisa', trailing: '${r.unsold.length}', top: 20));
        w.add(_Table(
          head: const ['BIDHAA', 'ZIPO', 'MTAJI'],
          widths: const [null, 50, 86],
          rows: [
            for (final u in r.unsold) [u.name, '${u.qty}', money(u.capital)],
          ],
        ));
      }
    }

    w.add(const SizedBox(height: 22));
    w.add(_PdfCard(r));
    w.add(const SizedBox(height: 10));
    w.add(Row(children: [
      Expanded(child: _PdfButton('Pakua PDF', Icons.download_rounded, busy: busy, onTap: () => onPdf(false))),
      const SizedBox(width: 10),
      Expanded(child: _PdfButton('Shiriki', Icons.share_outlined, filled: true, onTap: () => onPdf(true))),
    ]));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: w);
  }
}

/// "BIDHAA ZILIZOUZWA · 4 bidhaa" — kichwa cha sehemu kinachogusika kwa ukurasa
class SectionHeader extends StatelessWidget {
  final String text;
  final String? trailing;
  final double top;
  const SectionHeader(this.text, {super.key, this.trailing, this.top = 20});
  @override
  Widget build(BuildContext context) => SectionTitle(text, trailing: trailing, padding: EdgeInsets.fromLTRB(2, top, 2, 10));
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
          icon: Icon(icon, size: 22, color: on ? C.blue : const Color(0xFFD1D5DB)),
        ),
      );

  @override
  Widget build(BuildContext context) => Row(children: [
        _arrow(Icons.chevron_left_rounded, prev, onPrev),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
        _arrow(Icons.chevron_right_rounded, next, onNext),
      ]);
}

/// Kadi: faida halisi (32/w800 bluu) + Mauzo · Mtaji · Gharama
class _SummaryCard extends StatelessWidget {
  final String title;
  final Summary s;
  const _SummaryCard(this.title, this.s);
  @override
  Widget build(BuildContext context) => Box(
        radius: 18,
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

/// Jedwali la ripoti: vichwa 10.5/w800 bluu + mstari mweusi, mistari 13.5
class _Table extends StatelessWidget {
  final List<String> head;
  final List<double?> widths;
  final List<List<String>> rows;
  final List<String>? total;
  final bool blueLast;
  const _Table({required this.head, required this.widths, required this.rows, this.total, this.blueLast = false});

  TextStyle _st(int i, bool h, bool t, int n) => h
      ? const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: C.blue, letterSpacing: .4)
      : TextStyle(
          fontSize: 13.5,
          fontFeatures: tabular,
          fontWeight: (t || i == 1 || (blueLast && i == n - 1)) ? FontWeight.w800 : (i == 0 ? FontWeight.w600 : FontWeight.w400),
          color: (blueLast && i == n - 1) || (t && i == n - 1) ? C.blue : C.text,
        );

  Widget _row(List<String> c, {bool isHead = false, bool isTotal = false}) => Container(
        padding: EdgeInsets.fromLTRB(2, isHead ? 0 : 11, 2, isHead ? 6 : 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: isHead
                ? const BorderSide(color: C.text, width: 1.5)
                : isTotal
                    ? BorderSide.none
                    : const BorderSide(color: Color(0xFFF1F2F5)),
            top: isTotal ? const BorderSide(color: C.text, width: 1.5) : BorderSide.none,
          ),
        ),
        child: Row(children: [
          for (var i = 0; i < c.length; i++)
            widths[i] == null
                ? Expanded(
                    child: Text(c[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(i, isHead, isTotal, c.length)),
                  )
                : SizedBox(
                    width: widths[i],
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(c[i], textAlign: TextAlign.right, style: _st(i, isHead, isTotal, c.length)),
                    ),
                  ),
        ]),
      );

  @override
  Widget build(BuildContext context) => Column(children: [
        _row(head, isHead: true),
        for (final r in rows) _row(r),
        if (total != null) _row(total!, isTotal: true),
      ]);
}

/// Grafu ya faida: 0 = nguzo fupi (6px), null = mpaka wa vidoti (haigusiki)
class _BarChart extends StatelessWidget {
  final List<RBar> bars;
  final ValueChanged<RBar>? onTap;
  const _BarChart({required this.bars, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 34),
        child: Center(child: Text('Hakuna mauzo kipindi hiki', style: TextStyle(fontSize: 13, color: C.muted))),
      );
    }
    final nets = [for (final b in bars) if (b.net != null) b.net!];
    final mx = nets.isEmpty ? 1 : nets.reduce(math.max);
    var best = -1;
    for (var i = 0; i < bars.length; i++) {
      final n = bars[i].net;
      if (n == null) continue;
      if (best < 0 || n > bars[best].net!) best = i;
    }
    final dense = bars.length > 8;
    return SizedBox(
      height: 158,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < bars.length; i++) Expanded(child: _column(bars[i], i == best, mx, dense)),
      ]),
    );
  }

  Widget _column(RBar b, bool isBest, int mx, bool dense) {
    final n = b.net;
    final h = n == null ? 0.0 : (n <= 0 ? 6.0 : math.max(6.0, 118 * n / mx));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: n == null ? null : () => onTap?.call(b),
      child: _bar(b, n, h, isBest, dense),
    );
  }

  Widget _bar(RBar b, int? n, double h, bool isBest, bool dense) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: dense ? 3 : 4),
      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        SizedBox(
          height: 15,
          child: n == null
              ? null
              : FittedBox(
                  child: Text(moneyBar(n),
                      style: TextStyle(fontSize: dense ? 9 : 10.5, fontWeight: FontWeight.w700, color: isBest ? C.blue : C.muted)),
                ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 118,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: n == null
                ? const SizedBox(width: double.infinity, child: _Dotted())
                : Container(
                    height: h,
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 34),
                    decoration: BoxDecoration(
                      color: isBest ? C.blue : const Color(0xFF7DB7DB),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 15,
          child: FittedBox(
            child: Text(b.label,
                style: TextStyle(
                  fontSize: dense ? 9 : 11.5,
                  fontWeight: isBest ? FontWeight.w800 : FontWeight.w600,
                  color: isBest ? C.blue : (n == null ? const Color(0xFFD1D5DB) : C.muted),
                )),
          ),
        ),
      ]),
    );
  }
}

/// Mpaka wa vidoti kwa kipindi ambacho bado hakijafika
class _Dotted extends StatelessWidget {
  const _Dotted();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (c, b) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var x = 0.0; x < b.maxWidth - 3; x += 6) Container(width: 3, height: 2, color: const Color(0xFFD1D5DB)),
          ],
        ),
      );
}

/// Kadi ya PDF (Ripoti ya siku/wiki/mwezi/mwaka + short_label)
class _PdfCard extends StatelessWidget {
  final Report r;
  const _PdfCard(this.r);
  @override
  Widget build(BuildContext context) => Box(
        radius: 12,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: C.blue2, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: const Text('PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: C.blue)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ripoti ya ${r.title}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
              Text(r.shortLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.muted)),
            ]),
          ),
        ]),
      );
}

/// Pakua PDF (mstari) · Shiriki (bluu iliyojaa) — urefu 40
class _PdfButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final bool busy;
  final VoidCallback onTap;
  const _PdfButton(this.label, this.icon, {this.filled = false, this.busy = false, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : C.blue;
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 40,
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
