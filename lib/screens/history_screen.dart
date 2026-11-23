import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/app_icons.dart';
import '../widgets/app_nav.dart';
import '../widgets/ui.dart';
import 'sales_screen.dart';

/// HISTORIA — mauzo ya siku zilizopita kwa miezi (M16–M18).
/// Scroll chini -> pakia zaidi (next_before). Gusa siku -> Mauzo ya siku hiyo.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends State<HistoryScreen> {
  final List<HistoryMonth> _months = [];
  String? _next;
  bool _loading = false, _first = true;
  Object? _error;
  final _sc = ScrollController();

  /// Miezi iliyofunguliwa kwa mkono (ya zamani hufungwa; ya sasa hufunguka).
  final Map<String, bool> _shown = {};

  @override
  void initState() {
    super.initState();
    _sc.addListener(() {
      if (_sc.position.extentAfter < 300) _more();
    });
    _more();
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  Future<void> _more() async {
    if (_loading || (!_first && _next == null)) return;
    setState(() => _loading = true);
    try {
      final h = await Api.i.history(before: _first ? null : _next);
      if (!mounted) return;
      setState(() {
        for (final m in h.months) {
          if (_months.isNotEmpty && _months.last.label == m.label) {
            _months.last.days.addAll(m.days);
          } else {
            _months.add(m);
          }
        }
        _next = h.nextBefore;
        _first = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDay(String date) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SalesScreen(date: date)));
    if (!mounted) return;
    setState(() {
      _months.clear();
      _shown.clear();
      _next = null;
      _first = true;
    });
    _more();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: pageBar('Historia', subtitle: 'Mauzo ya siku zilizopita', flatBack: true),
        bottomNavigationBar: const AppNav(index: 1),
        body: _first
            ? const SizedBox.expand()
            : _error != null
                ? ErrorView(_error!, onRetry: () {
                    setState(() => _error = null);
                    _more();
                  })
                : _months.isEmpty
                    ? const Center(child: _NoHistory())
                    : _list(),
      );

  Widget _list() {
    final total = _months.fold(0, (a, m) => a + m.days.length);
    final collapsible = total >= 3;
    return ListView(
      controller: _sc,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        for (final (i, m) in _months.indexed) ...[
          _monthHead(m, i, collapsible),
          if (!collapsible || (_shown[m.label] ?? i == 0)) ...[
            if (m.days.length >= 2) ...[
              _MonthSummary(m),
              const SizedBox(height: 8),
            ],
            for (final d in m.days) ...[
              _DayCard(d, onTap: () => _openDay(d.date)),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ],
    );
  }

  /// Kichwa cha mwezi: "NOVEMBA 2026" kushoto, "siku N" kulia; siku 3+ zinafungwa.
  Widget _monthHead(HistoryMonth m, int i, bool collapsible) {
    final shown = _shown[m.label] ?? i == 0;
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(
          child: Text(m.label, style: Txt.section),
        ),
        Text('siku ${m.days.length}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.heading)),
        if (collapsible) ...[
          const SizedBox(width: 2),
          Transform.rotate(
            angle: shown ? 1.5708 : 0,
            child: const AppIcon(AppIcons.chevronRight, size: 16, color: C.heading),
          ),
        ],
      ]),
    );
    final top = EdgeInsets.only(top: i == 0 ? 0 : 22);
    if (!collapsible) return Padding(padding: top, child: row);
    return InkWell(
      onTap: () => setState(() => _shown[m.label] = !shown),
      child: Padding(padding: top, child: row),
    );
  }
}

/// Muhtasari wa mwezi: SIKU | MAUZO | FAIDA HALISI
class _MonthSummary extends StatelessWidget {
  final HistoryMonth month;
  const _MonthSummary(this.month);

  @override
  Widget build(BuildContext context) {
    final sales = month.days.fold(0, (a, d) => a + d.sales);
    final net = month.days.fold(0, (a, d) => a + d.net);
    final cells = [('SIKU', '${month.days.length}', false), ('MAUZO', money(sales), false), ('FAIDA HALISI', money(net), true)];
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.rule)),
      child: Row(children: [
        for (final (i, c) in cells.indexed)
          Expanded(
            child: Container(
              padding: EdgeInsets.fromLTRB(i == 0 ? 14 : 12, 12, 12, 12),
              decoration: BoxDecoration(border: i == 0 ? null : const Border(left: BorderSide(color: C.rule))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.label),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(c.$2,
                      maxLines: 1, style: Txt.stat.copyWith(color: c.$3 ? C.profit : C.ink)),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _DayCard extends StatelessWidget {
  final HistoryDay day;
  final VoidCallback onTap;
  const _DayCard(this.day, {required this.onTap});

  @override
  Widget build(BuildContext context) => Box(
        radius: 12,
        border: C.rule,
        onTap: onTap,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(children: [
              Expanded(
                child: Text(day.label,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.title),
              ),
              const SizedBox(width: 8),
              const AppIcon(AppIcons.chevronRight, size: 18, color: C.heading),
            ]),
          ),
          const Divider(height: 1, thickness: 1, color: C.rule),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 12, 13),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Cell('MAUZO', money(day.sales)),
              _Cell('BIDHAA', '${day.items}'),
              _Cell('FAIDA HALISI', money(day.net), blue: true),
            ]),
          ),
        ]),
      );
}

/// Seli ya kadi: lebo ndogo hafifu juu, namba 17 chini.
class _Cell extends StatelessWidget {
  final String label;
  final String value;
  final bool blue;
  const _Cell(this.label, this.value, {this.blue = false});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.label),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                maxLines: 1, style: Txt.stat.copyWith(color: blue ? C.profit : C.ink)),
          ),
        ]),
      );
}

class _NoHistory extends StatelessWidget {
  const _NoHistory();
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        const AppIcon(AppIcons.history, size: 28, color: C.label),
        const SizedBox(height: 12),
        const Text('Hakuna historia', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: C.label)),
      ]);
}
