import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/app_icons.dart';
import '../widgets/ui.dart';
import 'pin_screen.dart';
import 'receipts_screen.dart';

/// NYUMBANI — muhtasari wa siku ya mwisho iliyohifadhiwa:
///  - Faida halisi (kubwa, bluu) + Mauzo / Mtaji / Gharama
///  - BIDHAA ZILIZOUZIKA ZAIDI (kwa faida, kubwa kwanza)
///  - GHARAMA + Jumla
///  - RISITI za siku hiyo (gusa -> risiti katikati)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _Home {
  final HomeData d;
  final DailySheet sheet;
  final List<Receipt> receipts;
  const _Home(this.d, this.sheet, this.receipts);

  DateTime get day => dayOnly(d.date);
  bool get empty => d.summary.sales == 0 && d.summary.expenses == 0 && d.soldToday.isEmpty && receipts.isEmpty;

  List<SoldRow> get top {
    final list = [...d.soldToday]..sort((a, b) => b.profit.compareTo(a.profit));
    return list.take(5).toList();
  }
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_Home> _f;
  final _today = dayOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  Future<_Home> _load() async {
    final d = await Api.i.home(_today);
    final day = dayOnly(d.date);
    final r = await Future.wait([Api.i.daily(day), Api.i.receipts(day)]);
    return _Home(d, r[0] as DailySheet, r[1] as List<Receipt>);
  }

  Future<void> _reload() async {
    setState(() => _f = _load());
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

  PopupMenuItem<String> _menuItem(String v, String icon, String text) => PopupMenuItem<String>(
        value: v,
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          AppIcon(icon, size: 18),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.text)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar(dateLong(_today),
          subtitle: 'Nyumbani',
          action: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: C.muted),
            color: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 6,
            shadowColor: const Color(0x33111827),
            offset: const Offset(0, 44),
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 200),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: C.line)),
            onSelected: _menu,
            itemBuilder: (_) => [
              _menuItem('pin', AppIcons.key, 'Badilisha PIN'),
              const PopupMenuDivider(height: 1),
              _menuItem('toka', AppIcons.logOut, 'Toka'),
            ],
          )),
      body: FutureBuilder<_Home>(
        future: _f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Loading();
          if (s.hasError) return ErrorView(s.error!, onRetry: _reload);
          final x = s.data!;
          if (x.empty) {
            return const Center(
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Bado hakuna mauzo',
                text: 'Ukihifadhi siku yenye mauzo,\nmuhtasari wake utaonekana hapa.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            color: C.blue,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 30), children: [
              _DayLine(day: x.day, saved: x.sheet.savedAt != null),
              const SizedBox(height: 10),
              _Summary(x.d.summary),
              SectionTitle('Bidhaa zilizouzika zaidi', trailing: '${x.top.length} bidhaa'),
              if (x.top.isEmpty)
                const Padding(padding: EdgeInsets.fromLTRB(2, 0, 2, 4), child: Text('Hakuna bidhaa iliyouzwa', style: TextStyle(fontSize: 13, color: C.muted)))
              else
                for (final (i, t) in x.top.indexed) _TopCard(rank: i + 1, row: t),
              SectionTitle('Gharama', trailing: '${x.sheet.expenses.length}'),
              if (x.sheet.expenses.isEmpty)
                const Padding(padding: EdgeInsets.fromLTRB(2, 0, 2, 4), child: Text('Bado hakuna gharama', style: TextStyle(fontSize: 13, color: C.muted)))
              else ...[
                for (final e in x.sheet.expenses) _ExpenseRow(e.name, e.amount),
                _ExpenseTotal(x.d.summary.expenses),
              ],
              SectionTitle('Risiti', trailing: '${x.receipts.length}'),
              if (x.receipts.isEmpty)
                const Padding(padding: EdgeInsets.fromLTRB(2, 0, 2, 4), child: Text('Bado hakuna risiti', style: TextStyle(fontSize: 13, color: C.muted)))
              else
                for (final r in x.receipts)
                  _ReceiptRow(r: r, onTap: () => showReceiptDialog(context, r)),
            ]),
          );
        },
      ),
    );
  }
}

/// "MAUZO YA JANA" ...... "Alhamisi, 19 Nov"
class _DayLine extends StatelessWidget {
  final DateTime day;
  final bool saved;
  const _DayLine({required this.day, required this.saved});

  @override
  Widget build(BuildContext context) {
    final t = dayOnly(DateTime.now());
    final diff = t.difference(day).inDays;
    final label = diff == 0
        ? (saved ? 'MAUZO YA LEO (YAMEHIFADHIWA)' : 'MAUZO YA LEO')
        : diff == 1
            ? 'MAUZO YA JANA'
            : 'MAUZO YA ${day.day} ${monthsShort[day.month - 1]}'.toUpperCase();
    return Row(children: [
      Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .9))),
      const SizedBox(width: 10),
      Text('${daysSw[day.weekday - 1]}, ${day.day} ${monthsShort[day.month - 1]}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.muted)),
    ]);
  }
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

/// Kadi ya bidhaa iliyouzwa zaidi: namba · jina · IDADI · SELLING · MAUZO · FAIDA
class _TopCard extends StatelessWidget {
  final int rank;
  final SoldRow row;
  const _TopCard({required this.rank, required this.row});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Box(
          radius: 12,
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SizedBox(width: 22, child: Text('$rank', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.faint))),
              Expanded(child: Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
              if (row.outOfStock)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(4)),
                  child: const Text('nje ya stock', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: C.text2)),
                ),
            ]),
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Row(children: [
                Expanded(child: MiniStat('Idadi', '${row.qty}')),
                Expanded(child: MiniStat('Selling', money(row.selling))),
                Expanded(child: MiniStat('Mauzo', money(row.qty * row.selling))),
                Expanded(child: MiniStat('Faida', money(row.profit), bold: true, color: C.blue)),
              ]),
            ),
          ]),
        ),
      );
}

class _ExpenseRow extends StatelessWidget {
  final String name;
  final int amount;
  const _ExpenseRow(this.name, this.amount);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
        child: Row(children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          Text(money(amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFeatures: tabular)),
        ]),
      );
}

class _ExpenseTotal extends StatelessWidget {
  final int amount;
  const _ExpenseTotal(this.amount);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.text, width: 1.5))),
        child: Row(children: [
          const Expanded(child: Text('Jumla', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
          Text(money(amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFeatures: tabular)),
        ]),
      );
}

class _ReceiptRow extends StatelessWidget {
  final Receipt r;
  final VoidCallback onTap;
  const _ReceiptRow({required this.r, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Box(
          radius: 12,
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Na. ${r.number} · ${hhmm(r.createdAt)}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
              ]),
            ),
            const SizedBox(width: 10),
            Text(money(r.paid), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, fontFeatures: tabular)),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded, size: 20, color: C.faint),
          ]),
        ),
      );
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
