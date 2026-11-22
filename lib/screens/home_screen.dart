import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/home_bus.dart';
import '../widgets/app_icons.dart';
import '../widgets/sale_card.dart';
import '../widgets/table.dart';
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
    final day = h.day!;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 120), children: [
      SectionTitle(dayLabel(day), padding: const EdgeInsets.fromLTRB(2, 0, 2, 10)),
      _Summary(h.summary),
      const SizedBox(height: 24),
      _ProductCards(rows: h.top),
      const SizedBox(height: 26),
      ExpenseTable(rows: h.expenses, total: h.summary.expenses),
      const SizedBox(height: 26),
      _ProfitTable(h.summary),
    ]);
  }
}

/// MAUZO YA JUMAMOSI, 21 NOV · LEO   (jana -> · JANA; siku za nyuma -> bila kiambishi)
String dayLabel(DateTime d, {String lead = 'MAUZO YA'}) {
  final t = dayOnly(DateTime.now());
  final diff = t.difference(dayOnly(d)).inDays;
  const days = ['JUMATATU', 'JUMANNE', 'JUMATANO', 'ALHAMISI', 'IJUMAA', 'JUMAMOSI', 'JUMAPILI'];
  const months = ['JAN', 'FEB', 'MAC', 'APR', 'MEI', 'JUN', 'JUL', 'AGO', 'SEP', 'OKT', 'NOV', 'DES'];
  final base = '$lead ${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  if (diff <= 0) return '$base · LEO';
  if (diff == 1) return '$base · JANA';
  return base;
}

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

/// Kadi ya faida: namba kubwa ya FAIDA HALISI pamoja na maneno yake,
/// kisha safu tatu — Mauzo · Mtaji · Gharama (kila moja na ikoni na "Sh").
class _Summary extends StatelessWidget {
  final Summary s;
  const _Summary(this.s);

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.cardLine, width: .8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(children: [
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.trending_up_rounded, size: 16, color: C.blue),
                SizedBox(width: 6),
                Text('Faida halisi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.muted)),
              ]),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(money(s.net),
                        style: const TextStyle(
                            fontSize: 36, fontWeight: FontWeight.w700, color: C.blue, letterSpacing: -.5, height: 1.1, fontFeatures: tabular)),
                    const SizedBox(width: 6),
                    const Text('Shilingi', style: TextStyle(fontSize: 13, color: C.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(amountInWords(s.net),
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: C.text)),
            ]),
          ),
          const Divider(height: .8, thickness: .8, color: C.line),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _Stat(icon: Icons.shopping_cart_outlined, label: 'Mauzo', value: s.sales),
              const VerticalDivider(width: .8, thickness: .8, color: C.line),
              _Stat(icon: Icons.account_balance_wallet_outlined, label: 'Mtaji', value: s.capital),
              const VerticalDivider(width: .8, thickness: .8, color: C.line),
              _Stat(icon: Icons.receipt_long_outlined, label: 'Gharama', value: s.expenses),
            ]),
          ),
        ]),
      );
}

/// Safu moja ya kadi: ikoni · jina, namba (inapungua ikiwa ndefu), "Sh".
class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  const _Stat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 14, color: C.muted),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: C.muted)),
            ]),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(money(value),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.text, fontFeatures: tabular)),
            ),
            const SizedBox(height: 2),
            const Text('Sh', style: TextStyle(fontSize: 11, color: C.faint)),
          ]),
        ),
      );
}

/// MAUZO YA BIDHAA: kadi kama zile za Mauzo — namba yenye duara hafifu,
/// jina, kisha IDADI · SELLING · BUYING · FAIDA.
class _ProductCards extends StatelessWidget {
  final List<TopItem> rows;
  const _ProductCards({required this.rows});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const TblHead('Mauzo ya bidhaa'),
        const SizedBox(height: 8),
        for (final (i, r) in rows.indexed)
          SaleCard(
            rank: i + 1,
            title: r.name,
            profit: r.profit,
            cols: [
              ('IDADI', '${r.qty}'),
              ('SELLING', money(r.selling)),
              ('BUYING', money(r.qty == 0 ? 0 : (r.capital / r.qty).round())),
              ('FAIDA', money(r.profit)),
            ],
          ),
      ]);
}

/// HESABU YA FAIDA: faida ya bidhaa − gharama = FAIDA HALISI (bluu).
class _ProfitTable extends StatelessWidget {
  final Summary s;
  const _ProfitTable(this.s);

  static const _cell = TextStyle(fontSize: 13, color: C.text);
  static const _amount = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.text, fontFeatures: tabular);

  @override
  Widget build(BuildContext context) {
    const bottom = Border(bottom: BorderSide(color: C.line));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const TblHead('Hesabu ya faida'),
      Tbl.frame([
        Tbl.pair(const Text('MAELEZO', style: TblHead.col), 'KIASI (SH)', TblHead.amount,
            bg: C.head, border: bottom, vpad: 10),
        Tbl.pair(const Text('Faida ya bidhaa', style: _cell), money(s.productProfit), _amount, border: bottom),
        Tbl.pair(const Text('Toa: Jumla ya gharama', style: _cell), money(s.expenses), _amount, border: bottom),
        Tbl.pair(
          const Text('FAIDA HALISI', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          money(s.net),
          const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: C.blue, fontFeatures: tabular),
          bg: C.blue2,
          vpad: 15,
        ),
      ]),
    ]);
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
