import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';
import 'pin_screen.dart';

/// NYUMBANI
///  - Faida halisi ya leo (kubwa) + Mauzo / Mtaji / Gharama
///  - Vichupo: Stock (makundi yote, jina + idadi) | Vilivyouzwa leo (jedwali)
///  - Ukibonyeza kundi -> dirisha katikati: kila aina (Zilikuwa, Zimeuzwa, Zimebaki / Buying, Selling, Faida) + Jumla
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeData> _f;
  int _tab = 0;
  final _today = dayOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _f = Api.i.home(_today);
  }

  Future<void> _reload() async {
    setState(() => _f = Api.i.home(_today));
    await _f;
  }

  Future<void> _menu(String v) async {
    if (v == 'toka') {
      await Api.i.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const PinScreen()), (_) => false);
    } else if (v == 'pin') {
      await showCenterDialog(context, builder: (_) => const _ChangePin());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar(dateLong(_today),
          action: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: C.muted),
            color: Colors.white,
            surfaceTintColor: Colors.white,
            onSelected: _menu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pin', child: Text('Badilisha PIN')),
              PopupMenuItem(value: 'toka', child: Text('Toka')),
            ],
          )),
      body: FutureBuilder<HomeData>(
        future: _f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Loading();
          if (s.hasError) return ErrorView(s.error!, onRetry: _reload);
          final d = s.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            color: C.blue,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
              _Kpi(d.summary),
              const SizedBox(height: 16),
              UnderlineTabs(
                items: const ['Stock', 'Vilivyouzwa leo'],
                counts: ['${d.totalQty}', '${d.soldToday.fold<int>(0, (a, r) => a + r.qty)}'],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: Offset(child.key == const ValueKey(1) ? .08 : -.08, 0), end: Offset.zero).animate(a), child: child),
                ),
                child: _tab == 0 ? KeyedSubtree(key: const ValueKey(0), child: _StockGrid(d)) : KeyedSubtree(key: const ValueKey(1), child: _SoldTable(d.soldToday)),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final Summary s;
  const _Kpi(this.s);
  @override
  Widget build(BuildContext context) => Box(
        radius: 18,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Faida halisi ya leo', style: TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(money(s.net), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: C.blue, fontFeatures: tabular)),
          const SizedBox(height: 12),
          const Divider(height: 1, color: C.line),
          const SizedBox(height: 10),
          Row(children: [
            for (final (i, x) in [('Mauzo', s.sales), ('Mtaji', s.capital), ('Gharama', s.expenses)].indexed)
              Expanded(
                child: Container(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
                  decoration: BoxDecoration(border: i == 0 ? null : const Border(left: BorderSide(color: C.line))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(x.$1, style: const TextStyle(fontSize: 11.5, color: C.muted)),
                    Text(money(x.$2), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFeatures: tabular)),
                  ]),
                ),
              ),
          ]),
        ]),
      );
}

class _StockGrid extends StatelessWidget {
  final HomeData d;
  const _StockGrid(this.d);
  @override
  Widget build(BuildContext context) => Column(children: [
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: d.products.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, mainAxisExtent: 74),
          itemBuilder: (_, i) {
            final p = d.products[i];
            return Box(
              onTap: () => showCenterDialog(context, builder: (_) => _ProductDialog(p)),
              padding: const EdgeInsets.fromLTRB(12, 11, 10, 9),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.text2)),
                const SizedBox(height: 2),
                Text('${p.qty}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, fontFeatures: tabular)),
              ]),
            );
          },
        ),
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
          child: Row(children: [
            const Expanded(child: Text('Jumla ya bidhaa', style: TextStyle(fontSize: 14.5, color: C.muted))),
            Text('${d.totalQty}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.blue)),
          ]),
        ),
      ]);
}

/// Dirisha la kundi (muundo C kisomi)
class _ProductDialog extends StatelessWidget {
  final Product p;
  const _ProductDialog(this.p);
  @override
  Widget build(BuildContext context) {
    final vs = p.variants;
    final was = vs.fold<int>(0, (a, v) => a + v.qty + v.soldToday);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
        child: DialogHeader(p.name, sub: p.hasTypes ? 'aina ${vs.length} · leo' : 'leo'),
      ),
      Flexible(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(14, 0, 14, 16), children: [
          for (final v in vs) ...[
            Box(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 9),
                Row(children: [
                  Expanded(child: MiniStat('Zilikuwa', '${v.qty + v.soldToday}')),
                  Expanded(child: MiniStat('Zimeuzwa', v.soldToday == 0 ? '–' : '${v.soldToday}')),
                  Expanded(child: MiniStat('Zimebaki', '${v.qty}', bold: true, color: v.qty == 0 ? C.red : null)),
                ]),
                const Padding(padding: EdgeInsets.symmetric(vertical: 9), child: Divider(height: 1, color: C.line)),
                Row(children: [
                  Expanded(child: MiniStat('Buying', money(v.buying))),
                  Expanded(child: MiniStat('Selling', money(v.selling))),
                  Expanded(child: MiniStat('Faida', v.profitToday == 0 ? '–' : money(v.profitToday), bold: true)),
                ]),
              ]),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 4),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.text, width: 2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Jumla', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 9),
              Row(children: [
                Expanded(child: MiniStat('Zilikuwa', '$was', bold: true)),
                Expanded(child: MiniStat('Zimeuzwa', '${p.soldToday}', bold: true)),
                Expanded(child: MiniStat('Zimebaki', '${p.qty}', bold: true)),
              ]),
              const Padding(padding: EdgeInsets.symmetric(vertical: 9), child: Divider(height: 1, color: C.line)),
              Row(children: [
                const Expanded(child: SizedBox()),
                const Expanded(child: SizedBox()),
                Expanded(child: MiniStat('Faida', money(p.profitToday), bold: true)),
              ]),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

class _SoldTable extends StatelessWidget {
  final List<SoldRow> rows;
  const _SoldTable(this.rows);
  @override
  Widget build(BuildContext context) {
    final q = rows.fold<int>(0, (a, r) => a + r.qty);
    final b = rows.fold<int>(0, (a, r) => a + r.qty * r.buying);
    final s = rows.fold<int>(0, (a, r) => a + r.qty * r.selling);
    final p = rows.fold<int>(0, (a, r) => a + r.profit);
    const w = [null, 30.0, 66.0, 66.0, 60.0];
    TextStyle n([bool b = false]) => TextStyle(fontSize: 12.5, fontWeight: b ? FontWeight.w800 : FontWeight.w400, fontFeatures: tabular);
    Widget r(double? wd, String t, [bool bold = false]) => tableCell(wd, Text(t, textAlign: TextAlign.right, style: n(bold)));
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Box(
        child: Column(children: [
          Container(
            color: C.head,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              for (final (i, t) in ['BIDHAA', 'IDADI', 'BUYING', 'SELLING', 'FAIDA'].indexed)
                tableCell(w[i], Text(t, textAlign: i == 0 ? TextAlign.left : TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: C.muted, letterSpacing: .4))),
            ]),
          ),
          if (rows.isEmpty)
            const Padding(padding: EdgeInsets.all(18), child: Text('Bado hakuna mauzo leo', style: TextStyle(color: C.muted))),
          for (final x in rows)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(x.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('${money(x.buying)} · ${money(x.selling)}', style: const TextStyle(fontSize: 10.5, color: C.muted)),
                  ]),
                ),
                r(w[1], '${x.qty}'),
                r(w[2], money(x.qty * x.buying)),
                r(w[3], money(x.qty * x.selling)),
                r(w[4], money(x.profit), true),
              ]),
            ),
          if (rows.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
              child: Row(children: [
                const Expanded(child: Text('Jumla', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
                r(w[1], '$q', true),
                r(w[2], money(b), true),
                r(w[3], money(s), true),
                tableCell(w[4], Text(money(p), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: C.blue, fontFeatures: tabular))),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _ChangePin extends StatefulWidget {
  const _ChangePin();
  @override
  State<_ChangePin> createState() => _ChangePinState();
}

class _ChangePinState extends State<_ChangePin> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  bool _busy = false;
  Future<void> _save() async {
    if (_new.text.length != 4) {
      showError(context, 'PIN mpya iwe namba 4');
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.i.changePin(_old.text, _new.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const DialogHeader('Badilisha PIN'),
          const SizedBox(height: 14),
          Field(label: 'PIN ya sasa', controller: _old, number: true, autofocus: true),
          const SizedBox(height: 10),
          Field(label: 'PIN mpya (namba 4)', controller: _new, number: true, action: TextInputAction.done, onSubmitted: (_) => _save()),
          const SizedBox(height: 14),
          Align(alignment: Alignment.centerRight, child: SmallButton('Hifadhi', busy: _busy, onTap: _save)),
        ]),
      );
}
