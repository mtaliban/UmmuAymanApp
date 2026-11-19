import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../services/pdf.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';

// ======================================================================= RISITI (orodha ya siku)
class ReceiptsScreen extends StatefulWidget {
  final DateTime? initialDay;
  const ReceiptsScreen({super.key, this.initialDay});
  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  late DateTime _day = dayOnly(widget.initialDay ?? DateTime.now());
  late Future<List<Receipt>> _f;
  final List<ReceiptItem> _draft = [];
  String? _hl;
  String _nextNo = '0001';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _f = Api.i.receipts(_day));
    _nextNumber();
  }

  /// Namba inayokuja (mf. "0006") — inaonekana kwenye kichwa cha fomu.
  Future<void> _nextNumber() async {
    try {
      final list = await _f;
      var max = 0;
      for (final r in list) {
        final n = int.tryParse(r.number.replaceAll(RegExp(r'[^0-9]'), ''));
        if (n != null && n > max) max = n;
      }
      if (mounted) setState(() => _nextNo = (max + 1).toString().padLeft(4, '0'));
    } catch (_) {}
  }

  Future<void> _history() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReceiptHistoryScreen()));
    if (mounted) _load();
  }

  Future<void> _new([int edit = -1]) async {
    FocusScope.of(context).unfocus();
    final r = await showModalBottomSheet<Receipt>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewReceiptSheet(
        items: _draft,
        number: _nextNo,
        editIndex: edit,
        onChanged: () => setState(() {}),
      ),
    );
    if (!mounted) return;
    if (r == null) {
      _nextNumber();
      return;
    }
    setState(() {
      _draft.clear();
      _day = dayOnly(DateTime.now());
      _hl = r.id;
    });
    _load();
    await showReceiptDialog(context, r);
    if (mounted) _load();
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 70),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 66,
              height: 66,
              decoration: const BoxDecoration(color: C.blue2, shape: BoxShape.circle),
              child: const Icon(Icons.description_outlined, size: 28, color: C.text),
            ),
            const SizedBox(height: 16),
            const Text('Bado hakuna risiti', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isToday = _day == dayOnly(DateTime.now());
    return Scaffold(
      appBar: pageBar(
        'Risiti',
        subtitle: isToday ? 'Leo' : dateShort(_day),
        back: widget.initialDay != null,
        action: SmallButton('Historia',
            color: C.text2, icon: const Icon(Icons.history_rounded, size: 14, color: C.text2), onTap: _history),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 10),
          child: Row(children: [
            Expanded(
              child: Text(
                isToday ? 'RISITI ZA LEO' : 'RISITI ZA ${dateShort(_day).toUpperCase()}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .9),
              ),
            ),
            TopButton('Risiti mpya', onTap: _new),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<Receipt>>(
            future: _f,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) return const Loading();
              if (s.hasError) return ErrorView(s.error!, onRetry: _load);
              final list = [...s.data!]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              if (list.isEmpty && _draft.isEmpty) return _empty();
              final paid = _draft.fold<int>(0, (a, e) => a + e.amount);
              final qty = _draft.fold<int>(0, (a, e) => a + e.qty);
              return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 30), children: [
                for (final (i, it) in _draft.indexed) ...[
                  _DraftCard(it, highlight: i == _draft.length - 1, onTap: () => _new(i)),
                  const SizedBox(height: 8),
                ],
                if (_draft.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 6, 2, 16),
                    child: Row(children: [
                      Expanded(
                        child: Text('Kulipwa · $qty', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                      ),
                      Text(money(paid),
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: C.blue, fontFeatures: tabular)),
                    ]),
                  ),
                for (final r in list) ...[
                  Box(
                    onTap: () => showReceiptDialog(context, r),
                    radius: 12,
                    color: r.id == _hl ? C.blue3 : null,
                    border: r.id == _hl ? C.blue : null,
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('Na. ${r.number} · ${hhmm(r.createdAt)}', style: const TextStyle(fontSize: 12, color: C.muted)),
                        ]),
                      ),
                      const SizedBox(width: 10),
                      Text(money(r.paid), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, fontFeatures: tabular)),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: C.faint),
                    ]),
                  ),
                  const SizedBox(height: 8),
                ],
                if (list.isNotEmpty) ...[
                  const Divider(height: 20, thickness: 1.2, color: C.text),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
                    child: Row(children: [
                      Expanded(child: Text('Jumla · risiti ${list.length}', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800))),
                      Text(money(list.fold<int>(0, (a, r) => a + r.paid)),
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: C.blue, fontFeatures: tabular)),
                    ]),
                  ),
                ],
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

/// Kadi ya bidhaa iliyoongezwa kwenye risiti (picha 5/9 na 6/9)
class _DraftCard extends StatelessWidget {
  final ReceiptItem it;
  final bool highlight;
  final VoidCallback onTap;
  const _DraftCard(this.it, {required this.highlight, required this.onTap});
  @override
  Widget build(BuildContext context) => Box(
        onTap: onTap,
        color: highlight ? C.blue3 : null,
        border: highlight ? C.blue : null,
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: MiniStat('Idadi', '${it.qty}')),
            Expanded(child: MiniStat('Bei', money(it.price))),
            Expanded(child: MiniStat('Punguzo', it.discount > 0 ? money(it.discount) : '–')),
            Expanded(child: MiniStat('Kiasi', money(it.amount), bold: true, color: C.blue)),
          ]),
        ]),
      );
}

// ======================================================================= FOMU YA RISITI MPYA (chini)
class NewReceiptSheet extends StatefulWidget {
  final List<ReceiptItem> items;
  final String number;
  final int editIndex;
  final VoidCallback onChanged;
  const NewReceiptSheet({super.key, required this.items, required this.number, required this.onChanged, this.editIndex = -1});
  @override
  State<NewReceiptSheet> createState() => _NewReceiptSheetState();
}

class _NewReceiptSheetState extends State<NewReceiptSheet> {
  final _cName = TextEditingController(), _cPhone = TextEditingController();
  final _search = TextEditingController(), _q = TextEditingController(), _p = TextEditingController(), _d = TextEditingController();
  final _fName = FocusNode(), _fPhone = FocusNode(), _fSearch = FocusNode(), _fQ = FocusNode(), _fP = FocusNode(), _fD = FocusNode();
  List<Variant> _variants = [];
  Variant? _sel;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Api.i.products().then((ps) {
      if (!mounted) return;
      final all = ps.expand((x) => x.variants).toList();
      setState(() => _variants = all);
      if (widget.editIndex >= 0) {
        final it = widget.items[widget.editIndex];
        final found = all.where((x) => x.id == it.variantId).toList();
        setState(() {
          _sel = found.isEmpty ? null : found.first;
          _q.text = '${it.qty}';
          _p.text = money(it.price);
          _d.text = it.discount > 0 ? money(it.discount) : '';
        });
      }
    });
  }

  List<Variant> get _matches {
    final q = _search.text.trim();
    if (q.isEmpty || _sel != null) return [];
    return _variants.where((v) => nameMatches(v.name, q)).take(5).toList();
  }

  void _pick(Variant v) {
    setState(() {
      _sel = v;
      _search.clear();
      _p.text = money(v.selling);
    });
    _fQ.requestFocus();
  }

  void _clearSel() {
    setState(() {
      _sel = null;
      _q.clear();
      _p.clear();
      _d.clear();
    });
    _fSearch.requestFocus();
  }

  void _reset() {
    setState(() {
      _sel = null;
      _search.clear();
      _q.clear();
      _p.clear();
      _d.clear();
    });
    _fSearch.requestFocus();
  }

  void _commit() {
    final v = _sel;
    if (v == null) return;
    final q = parseMoney(_q.text), p = parseMoney(_p.text), d = parseMoney(_d.text);
    if (q <= 0) {
      showError(context, 'Andika idadi');
      _fQ.requestFocus();
      return;
    }
    final used = widget.items.asMap().entries.where((e) => e.key != widget.editIndex && e.value.variantId == v.id).fold<int>(0, (a, e) => a + e.value.qty);
    if (q + used > v.qty) {
      showError(context, '${v.name}: zipo ${v.qty - used} tu');
      _fQ.requestFocus();
      return;
    }
    if (d > p) {
      showError(context, 'Punguzo ni kubwa kuliko bei');
      _fD.requestFocus();
      return;
    }
    final it = ReceiptItem(variantId: v.id, name: v.name, qty: q, price: p, discount: d, buying: v.buying);
    if (widget.editIndex >= 0) {
      widget.items[widget.editIndex] = it;
      widget.onChanged();
      _reset();
      Navigator.pop(context);
      return;
    }
    widget.items.add(it);
    widget.onChanged();
    _reset();
  }

  Future<void> _finish() async {
    FocusScope.of(context).unfocus();
    if (_cName.text.trim().isEmpty) {
      showError(context, 'Andika jina la mteja');
      _fName.requestFocus();
      return;
    }
    if (widget.items.isEmpty) {
      showError(context, 'Ongeza bidhaa');
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await Api.i.createReceipt(name: _cName.text.trim(), phone: _cPhone.text.trim(), items: widget.items);
      if (mounted) Navigator.pop(context, r);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Text('Risiti mpya', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Text('Na. ${widget.number}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.muted)),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 17, color: C.text2),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  flex: 3,
                  child: DialogField(label: 'Jina la mteja', controller: _cName, focus: _fName, autofocus: true, onSubmitted: (_) => _fPhone.requestFocus()),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DialogField(label: 'Simu', controller: _cPhone, focus: _fPhone, number: true, hint: '07…', onSubmitted: (_) => _fSearch.requestFocus()),
                ),
              ]),
              const SizedBox(height: 10),
              const Text('Bidhaa', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: C.muted)),
              const SizedBox(height: 4),
              if (_sel == null) _searchField() else _selectedBox(),
              if (_matches.isNotEmpty) _results(),
              const SizedBox(height: 10),
              if (_sel != null)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 66,
                    child: DialogField(label: 'Idadi', controller: _q, focus: _fQ, number: true, hint: '0', align: TextAlign.center, onChanged: (_) => setState(() {}), onSubmitted: (_) => _fP.requestFocus()),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DialogField(label: 'Bei', controller: _p, focus: _fP, money: true, hint: '0', align: TextAlign.right, onChanged: (_) => setState(() {}), onSubmitted: (_) => _fD.requestFocus()),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DialogField(label: 'Punguzo', controller: _d, focus: _fD, money: true, hint: '0', align: TextAlign.right, onChanged: (_) => setState(() {}), onSubmitted: (_) => _commit()),
                  ),
                  const SizedBox(width: 8),
                  PrimaryButton('Next', onTap: _commit),
                ])
              else
                Row(children: [
                  if (widget.items.isNotEmpty) SmallButton('Maliza risiti', busy: _busy, onTap: _finish),
                  const Spacer(),
                  PrimaryButton('Next', onTap: null),
                ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _searchField() => SizedBox(
        height: 42,
        child: TextField(
          controller: _search,
          focusNode: _fSearch,
          textInputAction: TextInputAction.search,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            final m = _matches;
            if (m.isNotEmpty) _pick(m.first);
          },
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Tafuta bidhaa...',
            hintStyle: const TextStyle(color: C.faint, fontWeight: FontWeight.w400),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C.field)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C.blue, width: 1.6)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C.field)),
          ),
        ),
      );

  Widget _selectedBox() => InkWell(
        onTap: _clearSel,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.field)),
          child: Row(children: [
            Expanded(
              child: Text(_sel!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            ),
            Text('zipo ${_sel!.qty}', style: const TextStyle(fontSize: 12.5, color: C.muted, fontFeatures: tabular)),
          ]),
        ),
      );

  Widget _results() {
    final m = _matches;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.line),
      ),
      child: Column(children: [
        for (final (i, v) in m.indexed)
          InkWell(
            onTap: () => _pick(v),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: C.line))),
              child: Row(children: [
                Expanded(child: Text(v.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                Text('zipo ${v.qty} · ${money(v.selling)}',
                    style: TextStyle(fontSize: 12, color: v.qty == 0 ? C.red : C.muted, fontFeatures: tabular)),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ======================================================================= HISTORIA YA RISITI
class ReceiptHistoryScreen extends StatefulWidget {
  const ReceiptHistoryScreen({super.key});
  @override
  State<ReceiptHistoryScreen> createState() => _ReceiptHistoryScreenState();
}

class _ReceiptHistoryScreenState extends State<ReceiptHistoryScreen> {
  late Future<List<(DateTime, List<Receipt>)>> _f = _load();
  final _search = TextEditingController();

  Future<List<(DateTime, List<Receipt>)>> _load() async {
    final today = dayOnly(DateTime.now());
    final days = [today, for (var i = 1; i <= 14; i++) today.subtract(Duration(days: i))];
    final lists = await Future.wait(days.map((d) => Api.i.receipts(d)));
    return [for (var i = 0; i < days.length; i++) (days[i], lists[i])];
  }

  String _dayLabel(DateTime d) {
    final today = dayOnly(DateTime.now());
    final wd = daysSw[d.weekday - 1].toUpperCase();
    final md = '${d.day} ${monthsShort[d.month - 1].toUpperCase()}';
    if (d == today) return 'LEO · $wd $md';
    if (d == today.subtract(const Duration(days: 1))) return 'JANA · $wd $md';
    return '$wd $md';
  }

  void _reload() => setState(() => _f = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: pageBar('Historia ya risiti', subtitle: 'Risiti zote', back: true),
        body: FutureBuilder<List<(DateTime, List<Receipt>)>>(
          future: _f,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return const Loading();
            if (s.hasError) return ErrorView(s.error!, onRetry: _reload);
            final q = _search.text.trim().toLowerCase();
            final groups = s.data!
                .map((g) {
                  final list = q.isEmpty
                      ? g.$2
                      : g.$2
                          .where((r) => r.customerName.toLowerCase().contains(q) || r.number.toLowerCase().contains(q))
                          .toList();
                  return (g.$1, list);
                })
                .where((g) => g.$2.isNotEmpty)
                .toList();
            return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 30), children: [
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.line)),
                child: Row(children: [
                  const Icon(Icons.search_rounded, size: 18, color: C.faint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: 'Tafuta mteja au namba...',
                        hintStyle: TextStyle(color: C.faint, fontSize: 14, fontWeight: FontWeight.w400),
                      ),
                    ),
                  ),
                ]),
              ),
              if (groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Text('Hakuna risiti', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: C.muted)),
                ),
              for (final g in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 18, 2, 4),
                  child: Row(children: [
                    Expanded(
                      child: Text(_dayLabel(g.$1), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .4)),
                    ),
                    Text(money(g.$2.fold<int>(0, (a, r) => a + r.paid)),
                        style: const TextStyle(fontSize: 12, color: C.muted, fontFeatures: tabular)),
                  ]),
                ),
                for (var i = 0; i < g.$2.length; i++)
                  InkWell(
                    onTap: () => showReceiptDialog(context, g.$2[i]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
                      decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: C.line))),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(g.$2[i].customerName,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text('Na. ${g.$2[i].number} · ${hhmm(g.$2[i].createdAt)}',
                                style: const TextStyle(fontSize: 12, color: C.muted)),
                          ]),
                        ),
                        const SizedBox(width: 10),
                        Text(money(g.$2[i].paid),
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, fontFeatures: tabular)),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: C.faint),
                      ]),
                    ),
                  ),
              ],
            ]);
          },
        ),
      );
}

// ======================================================================= RISITI KATIKATI (dirisha)
Future<void> showReceiptDialog(BuildContext context, Receipt r) => showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'funga',
      barrierColor: const Color(0x730B1220),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, a1, a2) => _ReceiptDialog(receipt: r),
      transitionBuilder: (ctx, a, b, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(opacity: c, child: ScaleTransition(scale: Tween(begin: .94, end: 1.0).animate(c), child: child));
      },
    );

class _ReceiptDialog extends StatefulWidget {
  final Receipt receipt;
  const _ReceiptDialog({required this.receipt});
  @override
  State<_ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<_ReceiptDialog> {
  Shop? _shop;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Api.i.shop().then((s) {
      if (mounted) setState(() => _shop = s);
    });
  }

  Shop get _s => _shop ?? Shop(name: 'UMMU AYMAN OUTFITS', phone: '', email: '');

  String _waText() {
    final r = widget.receipt;
    final b = StringBuffer()
      ..writeln('*${_s.name}*')
      ..writeln('Risiti Na. ${r.number} · ${dateShort(r.createdAt)}')
      ..writeln('Mteja: ${r.customerName}')
      ..writeln();
    for (final it in r.items) {
      b.writeln('${it.name}  ${it.qty} × ${money(it.price - it.discount)} = ${money(it.amount)}');
    }
    b
      ..writeln()
      ..writeln('Jumla: ${money(r.gross)}');
    if (r.discountTotal > 0) b.writeln('Punguzo: -${money(r.discountTotal)}');
    b
      ..writeln('*Imelipwa: TSh ${money(r.paid)}*')
      ..writeln()
      ..writeln('Asante kwa kununua.');
    return b.toString();
  }

  Future<void> _whatsapp() async {
    final phone = waPhone(widget.receipt.customerPhone);
    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(_waText())}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) showError(context, 'WhatsApp haikufunguka');
  }

  Future<void> _pdf({required bool share}) async {
    setState(() => _busy = true);
    try {
      final bytes = await receiptPdf(widget.receipt, _s);
      final name = 'risiti-${widget.receipt.number}.pdf';
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
    final r = widget.receipt;
    const head = TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: C.blue, letterSpacing: .4);
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Stack(children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(_s.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: C.blue, letterSpacing: .3)),
                    const SizedBox(height: 3),
                    Text('${_s.phone} · ${_s.email}',
                        textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: C.muted)),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Divider(height: 1, color: C.line)),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Risiti Na.', style: TextStyle(fontSize: 11.5, color: C.muted)),
                          Text(r.number, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const Text('Tarehe', style: TextStyle(fontSize: 11.5, color: C.muted)),
                        Text('${dateShort(r.createdAt)} · ${hhmm(r.createdAt)}', style: const TextStyle(fontSize: 13)),
                      ]),
                    ]),
                    const SizedBox(height: 8),
                    Text.rich(TextSpan(children: [
                      const TextSpan(text: 'Mteja: ', style: TextStyle(fontSize: 13, color: C.muted)),
                      TextSpan(text: r.customerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      if (r.customerPhone.isNotEmpty)
                        TextSpan(text: ' · ${r.customerPhone}', style: const TextStyle(fontSize: 13, color: C.text2)),
                    ])),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.only(bottom: 8),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.text, width: 1.2))),
                      child: const Row(children: [
                        Expanded(child: Text('BIDHAA', style: head)),
                        SizedBox(width: 38, child: Text('IDADI', textAlign: TextAlign.center, style: head)),
                        SizedBox(width: 66, child: Text('BEI', textAlign: TextAlign.right, style: head)),
                        SizedBox(width: 74, child: Text('KIASI', textAlign: TextAlign.right, style: head)),
                      ]),
                    ),
                    for (final it in r.items)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(it.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                              if (it.discount > 0)
                                Text('punguzo ${money(it.discount)} kila moja', style: const TextStyle(fontSize: 11, color: C.muted)),
                            ]),
                          ),
                          SizedBox(width: 38, child: Text('${it.qty}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5))),
                          SizedBox(
                            width: 66,
                            child: Text(money(it.price),
                                textAlign: TextAlign.right, style: const TextStyle(fontSize: 13.5, fontFeatures: tabular)),
                          ),
                          SizedBox(
                            width: 74,
                            child: Text(money(it.amount),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, fontFeatures: tabular)),
                          ),
                        ]),
                      ),
                    const SizedBox(height: 10),
                    _t('Jumla', money(r.gross)),
                    if (r.discountTotal > 0) _t('Punguzo', '− ${money(r.discountTotal)}'),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, thickness: 1.2, color: C.text)),
                    Row(children: [
                      const Expanded(
                        child: Text('IMELIPWA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: .4)),
                      ),
                      Text(money(r.paid),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: C.blue, fontFeatures: tabular)),
                    ]),
                    const SizedBox(height: 14),
                    const Text('Asante kwa kununua nasi',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: C.muted)),
                  ]),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: C.line),
                        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child: const Icon(Icons.close, size: 16, color: C.text2),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _Action('Pakua PDF', Icons.download_rounded, busy: _busy, onTap: () => _pdf(share: false)),
                ),
                const SizedBox(width: 8),
                Expanded(child: _Action('WhatsApp', Icons.chat_bubble_outline_rounded, green: true, onTap: _whatsapp)),
                const SizedBox(width: 8),
                Expanded(
                  child: _Action('Shiriki', Icons.share_outlined, onTap: () => _pdf(share: true)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _t(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(l, style: const TextStyle(fontSize: 13.5, color: C.muted))),
          Text(v, style: const TextStyle(fontSize: 13.5, color: C.text2, fontFeatures: tabular)),
        ]),
      );
}

/// Kitufe cha chini ya risiti: Pakua PDF · WhatsApp · Shiriki
class _Action extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool green;
  final bool busy;
  final VoidCallback? onTap;
  const _Action(this.label, this.icon, {this.green = false, this.busy = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    final bg = green ? C.green : Colors.white;
    final fg = green ? Colors.white : C.blue;
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: green ? C.green : C.blue, width: 1.2),
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
