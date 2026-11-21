import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/home_bus.dart';
import '../widgets/app_icons.dart';
import '../widgets/ui.dart';
import 'pin_screen.dart';

/// NYUMBANI — muhtasari wa siku ya mwisho yenye mauzo.
///
/// API MOJA TU: GET /home (bila vigezo). Jibu:
///   {"day": "2026-11-20" | null,
///    "summary": {sales, capital, expenses, product_profit, net},
///    "top": [{name, qty, selling, sales, capital, profit, out_of_stock}],
///    "expenses": [{name, amount}]}
///
/// `day == null` -> H1 (hakuna mauzo bado).
/// Ukurasa huu hauna sehemu ya risiti; bidhaa za risiti zimo ndani ya `top`.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> with WidgetsBindingObserver {
  HomeData? _h;
  bool _loaded = false;
  bool _offline = false;
  StreamSubscription<void>? _bus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Mauzo/Risiti zikibadilisha kitu -> HomeBus.refresh() -> pakia upya.
    _bus = HomeBus.stream.listen((_) => _load());
    _load();
  }

  @override
  void dispose() {
    _bus?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// App ikirudi kutoka background -> GET /home upya.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final h = await Api.i.home();
      if (!mounted) return;
      setState(() {
        _h = h;
        _offline = false;
        _loaded = true;
      });
    } catch (e) {
      if (e is ApiException && e.status == 401) {
        _toPin();
        return;
      }
      final c = await Api.i.lastHome();
      if (!mounted) return;
      setState(() {
        _h = c;
        _offline = c == null; // data ya kumbukumbu ikiwepo, ionyeshwe
        _loaded = true;
      });
    }
  }

  void _toPin() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const PinScreen()), (_) => false);
  }

  Future<void> _menu(String v) async {
    if (v == 'toka') {
      await Api.i.logout();
      _toPin();
    } else if (v == 'pin') {
      await showCenterDialog(context, builder: (_) => const _ChangePin());
    }
  }

  PopupMenuItem<String> _menuItem(String v, String icon, String text) => PopupMenuItem<String>(
        value: v,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          AppIcon(icon, size: 18),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: C.text)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final h = _h;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: pageBar(
        dateLong(now),
        subtitle: 'Nyumbani',
        action: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: C.text2),
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 8,
          offset: const Offset(0, 44),
          constraints: const BoxConstraints.tightFor(width: 200),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: C.cardLine)),
          onSelected: _menu,
          itemBuilder: (_) => [
            _menuItem('pin', AppIcons.key, 'Badilisha PIN'),
            const PopupMenuDivider(height: 8),
            _menuItem('toka', AppIcons.logOut, 'Toka'),
          ],
        ),
      ),
      // Nyeupe wakati inapakia (hakuna mzunguko).
      body: !_loaded
          ? const SizedBox.expand()
          : _offline
              ? _Offline(onRetry: _load)
              : h == null || h.day == null
                  ? const Center(child: _NoSales())
                  : RefreshIndicator(color: C.blue, onRefresh: _load, child: _body(h)),
    );
  }

  Widget _body(HomeData h) {
    final s = h.summary;
    final day = h.day!;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 120), children: [
      Row(children: [
        Expanded(
          child: Text(dayLabel(day),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.text2)),
        ),
        Text(dayShort(day), style: const TextStyle(fontSize: 12.5, color: C.muted)),
      ]),
      const SizedBox(height: 8),
      _Summary(s),
      SectionTitle('Bidhaa zilizouzwa', trailing: '${h.top.length} bidhaa', padding: const EdgeInsets.fromLTRB(2, 20, 2, 8)),
      for (final (i, t) in h.top.indexed) _TopCard(rank: i + 1, row: t),
    ]);
  }
}

/// MAUZO YA LEO / JANA / <SIKU> / <TAREHE>
String dayLabel(DateTime d) {
  final t = dayOnly(DateTime.now());
  final diff = t.difference(dayOnly(d)).inDays;
  const days = ['JUMATATU', 'JUMANNE', 'JUMATANO', 'ALHAMISI', 'IJUMAA', 'JUMAMOSI', 'JUMAPILI'];
  const months = ['JAN', 'FEB', 'MAC', 'APR', 'MEI', 'JUN', 'JUL', 'AGO', 'SEP', 'OKT', 'NOV', 'DES'];
  if (diff <= 0) return 'MAUZO YA LEO';
  if (diff == 1) return 'MAUZO YA JANA';
  if (diff <= 6) return 'MAUZO YA ${days[d.weekday - 1]}';
  return 'MAUZO YA ${d.day} ${months[d.month - 1]}';
}

/// "Ijumaa, 20 Nov"
String dayShort(DateTime d) => '${daysSw[d.weekday - 1]}, ${d.day} ${monthsShort[d.month - 1]}';

/// H1 — bado hakuna mauzo yoyote
class _NoSales extends StatelessWidget {
  const _NoSales();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: C.blue2, shape: BoxShape.circle),
            child: const Center(child: AppIcon(AppIcons.house, size: 28, color: C.text)),
          ),
          const SizedBox(height: 16),
          const Text('Bado hakuna mauzo', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Ukiandika mauzo kwenye ukurasa wa Mauzo,\nyataonekana hapa.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: C.muted, height: 1.5)),
        ]),
      );
}

/// Hakuna mtandao na hakuna data ya kumbukumbu
class _Offline extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _Offline({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Hakuna mtandao', style: TextStyle(fontSize: 13, color: C.muted)),
          const SizedBox(height: 12),
          SmallButton('Jaribu tena', onTap: onRetry),
        ]),
      );
}

/// Faida halisi kubwa + Mauzo · Mtaji · Gharama
class _Summary extends StatelessWidget {
  final Summary s;
  const _Summary(this.s);
  @override
  Widget build(BuildContext context) => Box(
        radius: 18,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Faida halisi', style: TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w600)),
          Text(money(s.net), style: const TextStyle(fontSize: 34, height: 1.2, fontWeight: FontWeight.w800, color: C.blue, fontFeatures: tabular)),
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

/// Kadi ya bidhaa ya siku: namba · jina · IDADI · SELLING · MAUZO · FAIDA
/// Safu zina upana 62 : 100 : 112 : 100 na nafasi 12 kati yake; namba ndefu
/// zinapungua kwa FittedBox (hazigusani).
class _TopCard extends StatelessWidget {
  final int rank;
  final TopItem row;
  const _TopCard({required this.rank, required this.row});

  @override
  Widget build(BuildContext context) {
    const flex = [62, 100, 112, 100];
    final cols = [
      ('IDADI', '${row.qty}'),
      ('SELLING', money(row.selling)),
      ('MAUZO', money(row.sales)),
      ('FAIDA', money(row.profit)),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.cardLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(width: 22, child: Text('$rank', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.faint))),
          Expanded(
              child: Text(row.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 7),
        Padding(
          padding: const EdgeInsets.only(left: 22),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                flex: flex[i],
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cols[i].$1, style: const TextStyle(fontSize: 11, color: C.muted)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(cols[i].$2,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: i == 3 ? FontWeight.w800 : FontWeight.w600,
                          color: i == 3 ? C.blue : C.text,
                          fontFeatures: tabular,
                        )),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ]),
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
