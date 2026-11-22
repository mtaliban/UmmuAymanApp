import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../services/pdf.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/home_bus.dart';
import '../widgets/app_icons.dart';
import '../widgets/app_nav.dart';
import '../widgets/ui.dart';

/// RISITI (T01–T10)
///
/// C0 GET /receipts?date={leo} · C1 POST /receipts · C2 GET /receipts/{id} ·
/// C3 GET /receipts/history · S0 GET /products/search-list.
/// Dirisha la risiti liko JUU ya kibodi (si bottom-sheet), X inahifadhi na
/// kufunga, ukurasa wa risiti ni ukurasa mzima (si dialog).
class ReceiptsScreen extends StatefulWidget {
  final DateTime? initialDay;
  const ReceiptsScreen({super.key, this.initialDay});
  @override
  State<ReceiptsScreen> createState() => ReceiptsScreenState();
}

class ReceiptsScreenState extends State<ReceiptsScreen> {
  late DateTime _day = dayOnly(widget.initialDay ?? DateTime.now());
  TodayReceipts? _today;
  bool _loading = true;
  Object? _loadError;

  String? _newId;
  bool _open = false, _busy = false;
  String? _error;

  List<Variant> _stock = [];
  Variant? _sel;
  final List<ReceiptItem> _items = [];

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _q = TextEditingController();
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _disc = TextEditingController();
  final _buy = TextEditingController();

  final _nameF = FocusNode();
  final _phoneF = FocusNode();
  final _qF = FocusNode();
  final _qtyF = FocusNode();

  final _scroll = ScrollController();
  final _winKey = GlobalKey(), _totKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in [_name, _phone, _q, _qty, _price, _disc, _buy]) {
      c.dispose();
    }
    for (final f in [_nameF, _phoneF, _qF, _qtyF]) {
      f.dispose();
    }
    super.dispose();
  }

  /// Shell inaiita ukirudi kwenye tab ya Risiti.
  void onTabShown() => _load();

  Future<void> _load() async {
    try {
      final t = await Api.i.receipts(_day);
      if (!mounted) return;
      setState(() {
        _today = t;
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e;
        });
      }
    }
  }

  /// Namba inayokuja (C0 `next_number`, mf. "0009").
  String get _nextNo => _today?.nextNumber ?? '0001';

  List<Variant> get _matches {
    final q = _q.text.trim().toLowerCase();
    if (q.isEmpty || _sel != null) return [];
    final words = q.split(RegExp(r'\s+'));
    return _stock.where((v) {
      final n = v.name.toLowerCase().split(RegExp(r'\s+'));
      return words.every((w) => n.any((x) => x.startsWith(w)));
    }).take(6).toList();
  }

  bool get _newName => _sel == null && _q.text.trim().length >= 2 && _matches.isEmpty;

  /// Next inawaka: Idadi > 0, Bei > 0, Punguzo ≤ Bei (jina jipya: Buying imejazwa).
  /// Idadi HAIKAGULIWI dhidi ya "zipo".
  bool get _canNext =>
      !_busy &&
      parseMoney(_qty.text) > 0 &&
      parseMoney(_price.text) > 0 &&
      parseMoney(_disc.text) <= parseMoney(_price.text) &&
      (_sel != null || (_newName && _buy.text.trim().isNotEmpty));

  Future<void> _openNew() async {
    setState(() {
      _open = true;
      _items.clear();
      _sel = null;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) _nameF.requestFocus();
    });
    try {
      final v = await Api.i.searchList();
      if (mounted) setState(() => _stock = v);
    } catch (_) {}
  }

  void _pick(Variant v) {
    setState(() {
      _sel = v;
      _q.text = v.name;
      _price.text = money(v.selling);
      _qty.clear();
    });
    _qtyF.requestFocus();
  }

  void _next() {
    if (!_canNext) return;
    setState(() {
      _items.add(ReceiptItem(
        variantId: _sel?.id ?? '',
        name: _sel?.name ?? _q.text.trim(),
        qty: parseMoney(_qty.text),
        price: parseMoney(_price.text),
        discount: parseMoney(_disc.text),
        buying: _sel?.buying ?? parseMoney(_buy.text),
      ));
      _sel = null;
      for (final c in [_q, _qty, _price, _disc, _buy]) {
        c.clear();
      }
    });
    _qF.requestFocus();
    _keepAbove();
  }

  /// X: kama kuna bidhaa → C1 kisha funga; bila bidhaa → funga tu.
  /// Ikishindwa, dirisha linabaki wazi na kosa linaonekana ndani.
  Future<void> _closeWindow() async {
    if (_items.isEmpty) {
      _reset();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await Api.i.createReceipt(name: _name.text.trim(), phone: _phone.text.trim(), items: _items);
      if (!mounted) return;
      _reset();
      setState(() {
        _newId = r.id;
        _day = dayOnly(DateTime.now());
      });
      await _load();
      HomeBus.refresh();
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _newId = null);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    setState(() {
      _open = false;
      _items.clear();
      _sel = null;
      _error = null;
    });
    for (final c in [_name, _phone, _q, _qty, _price, _disc, _buy]) {
      c.clear();
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// Jumla ikae 10px juu ya dirisha (T05, T06).
  Future<void> _keepAbove() async {
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted || !_scroll.hasClients) return;
    final w = _winKey.currentContext?.findRenderObject() as RenderBox?;
    final t = _totKey.currentContext?.findRenderObject() as RenderBox?;
    if (w == null || t == null) return;
    final winTop = w.localToGlobal(Offset.zero).dy;
    final bottom = t.localToGlobal(Offset(0, t.size.height)).dy;
    final to = (_scroll.offset + bottom - (winTop - 10)).clamp(0.0, _scroll.position.maxScrollExtent);
    await _scroll.animateTo(to, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  // ------------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    final t = _today;
    final rows = t?.rows ?? const <ReceiptRow>[];
    final count = t?.count ?? rows.length;
    final total = t?.total ?? rows.fold<int>(0, (a, r) => a + r.paid);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: pageBar(
        'Risiti',
        subtitle: dateLong(_day),
        drop: true,
        center: true,
        action: Row(mainAxisSize: MainAxisSize.min, children: [
          HeaderIconButton(AppIcons.history,
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReceiptHistoryScreen()));
                if (mounted) _load();
              }),
          const SizedBox(width: 12),
          HeaderButton('+ Risiti', height: 42, borderWidth: 1.5, padding: 16, weight: FontWeight.w600, onTap: _open ? null : _openNew),
        ]),
      ),
      body: _loading
          ? const SizedBox.expand()
          : _loadError != null
              ? ErrorView(_loadError!, onRetry: _load)
              : Stack(children: [
                  if (_open)
                    ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(16, 16, 16, 420), children: _draftView())
                  else if (rows.isEmpty)
                    const Center(child: _NoReceipts())
                  else
                    ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), children: [
                      SectionTitle(_day == dayOnly(DateTime.now()) ? 'Risiti za leo' : 'Risiti za ${dateShortDay(_day)}',
                          trailing: '$count', padding: const EdgeInsets.fromLTRB(2, 14, 2, 8)),
                      for (final r in rows)
                        _RcCard(
                          row: r,
                          highlight: r.id == _newId,
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(id: r.id)));
                            if (mounted) _load();
                          },
                        ),
                      _TotalLine(
                        left: 'Jumla · risiti $count',
                        right: money(total),
                      ),
                    ]),
                  if (_open) _window(),
                ]),
    );
  }

  /// Bidhaa zilizoongezwa (juu ya dirisha) + mstari wa Kulipwa.
  List<Widget> _draftView() {
    if (_items.isEmpty) return const [];
    final q = _items.fold<int>(0, (a, i) => a + i.qty);
    final paid = _items.fold<int>(0, (a, i) => a + i.amount);
    final phone = _phone.text.trim();
    return [
      Row(children: [
        Expanded(
          child: Text(_name.text.trim().isEmpty ? 'Mteja' : titleCase(_name.text),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        Text('Na. $_nextNo${phone.isEmpty ? '' : ' · ${phoneFmt(phone)}'}',
            style: const TextStyle(fontSize: 12.5, color: C.muted, fontFeatures: tabular)),
      ]),
      const SizedBox(height: 10),
      for (final (i, it) in _items.indexed) ...[
        _DraftCard(it, highlight: i == _items.length - 1),
        const SizedBox(height: 8),
      ],
      _TotalLine(key: _totKey, left: 'Kulipwa · $q', right: money(paid)),
    ];
  }

  Widget _window() {
    final showFields = _sel != null || _newName;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      left: 12,
      right: 12,
      // Ukurasa unapunguzwa na Scaffold kwa urefu wa keyboard — fomu ikae
      // chini juu ya keyboard bila kupanda mara mbili.
      bottom: 10,
      child: Container(
        key: _winKey,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.winBorder),
          boxShadow: const [BoxShadow(color: Color(0x2E111827), blurRadius: 24, offset: Offset(0, 8))],
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Risiti mpya', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text('Na. $_nextNo', style: const TextStyle(fontSize: 12.5, color: C.muted, fontFeatures: tabular)),
            const Spacer(),
            InkWell(
              onTap: _busy ? null : _closeWindow,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.line)),
                child: _busy
                    ? const Padding(padding: EdgeInsets.all(8), child: DotsLoader(size: 3))
                    : const Icon(Icons.close_rounded, size: 16, color: C.text),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              flex: 12,
              child: DialogField(label: 'Jina la mteja', controller: _name, focus: _nameF, hint: 'Mf. Said Hamad', onChanged: (_) => setState(() {}), onSubmitted: (_) => _phoneF.requestFocus()),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 10,
              child: DialogField(label: 'Simu', controller: _phone, focus: _phoneF, number: true, hint: '07…', onChanged: (_) => setState(() {}), onSubmitted: (_) => _qF.requestFocus()),
            ),
          ]),
          const SizedBox(height: 10),
          _BidhaaField(
            controller: _q,
            focus: _qF,
            suffix: _sel == null ? null : 'zipo ${_sel!.qty}',
            onChanged: (_) => setState(() => _sel = null),
            onSubmitted: (_) {
              if (_matches.isNotEmpty) _pick(_matches.first);
            },
          ),
          if (_matches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(children: [
                for (final v in _matches)
                  InkWell(
                    onTap: () => _pick(v),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1F2F5)))),
                      child: Row(children: [
                        Expanded(child: _bold(v.name, _q.text)),
                        Text('zipo ${v.qty} · ${money(v.selling)}', style: const TextStyle(fontSize: 12, color: C.muted, fontFeatures: tabular)),
                      ]),
                    ),
                  ),
              ]),
            ),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (showFields) ...[
              DialogField(label: 'Idadi', controller: _qty, focus: _qtyF, number: true, width: 48, align: TextAlign.center, onChanged: (_) => setState(() {}), onSubmitted: (_) => _next()),
              const SizedBox(width: 8),
              DialogField(label: 'Bei', controller: _price, money: true, width: 80, align: TextAlign.right, onChanged: (_) => setState(() {})),
              const SizedBox(width: 8),
              _newName
                  ? DialogField(label: 'Buying', controller: _buy, money: true, width: 72, align: TextAlign.right, onChanged: (_) => setState(() {}))
                  : DialogField(label: 'Punguzo', controller: _disc, money: true, width: 72, align: TextAlign.right, onChanged: (_) => setState(() {})),
            ],
            const Spacer(),
            _NextBtn(onTap: _canNext ? _next : null),
          ]),
          if (_error != null) ErrorText(_error!),
        ]),
      ),
    );
  }

  Widget _bold(String n, String query) {
    final q = query.trim().toLowerCase();
    final lower = n.toLowerCase();
    if (q.isEmpty || !lower.startsWith(q)) {
      return Text(n, style: const TextStyle(fontSize: 14.5, color: C.text));
    }
    final k = q.length.clamp(0, n.length);
    return Text.rich(TextSpan(style: const TextStyle(fontSize: 14.5, color: C.text), children: [
      TextSpan(text: n.substring(0, k), style: const TextStyle(fontWeight: FontWeight.w800)),
      TextSpan(text: n.substring(k)),
    ]));
  }
}

// ======================================================================= vipande vya orodha

/// T01 — hakuna risiti leo
class _NoReceipts extends StatelessWidget {
  const _NoReceipts();
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: C.blue2, shape: BoxShape.circle),
          child: const Center(child: AppIcon(AppIcons.fileText, size: 28, color: C.text)),
        ),
        const SizedBox(height: 16),
        const Text('Hakuna risiti leo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ]);
}

/// Kadi ya risiti: mteja · Na. 0006 · 09:14 · kiasi ›
class _RcCard extends StatelessWidget {
  final ReceiptRow row;
  final bool highlight;
  final VoidCallback onTap;
  const _RcCard({required this.row, this.highlight = false, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Box(
          onTap: onTap,
          radius: 12,
          color: highlight ? C.blue3 : null,
          border: highlight ? C.blue : C.cardLine,
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titleCase(row.customer), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('Na. ${row.number} · ${row.time}', style: const TextStyle(fontSize: 12.5, color: C.muted, fontFeatures: tabular)),
              ]),
            ),
            Text(money(row.paid), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFeatures: tabular)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, size: 18, color: C.faint),
          ]),
        ),
      );
}

/// Kadi ya bidhaa iliyoongezwa (IDADI · BEI · PUNGUZO · KIASI)
class _DraftCard extends StatelessWidget {
  final ReceiptItem it;
  final bool highlight;
  const _DraftCard(this.it, {this.highlight = false});

  @override
  Widget build(BuildContext context) => Box(
        radius: 12,
        color: highlight ? C.blue3 : null,
        border: highlight ? C.blue : C.cardLine,
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          Row(children: [
            Expanded(flex: 62, child: MiniStat('IDADI', '${it.qty}')),
            const SizedBox(width: 12),
            Expanded(flex: 100, child: MiniStat('BEI', money(it.price))),
            const SizedBox(width: 12),
            Expanded(flex: 100, child: MiniStat('PUNGUZO', it.discount == 0 ? '—' : money(it.discount))),
            const SizedBox(width: 12),
            Expanded(flex: 100, child: MiniStat('KIASI', money(it.amount), bold: true, color: C.blue)),
          ]),
        ]),
      );
}

/// Mstari wa jumla (mstari mweusi 1.5 juu)
class _TotalLine extends StatelessWidget {
  final String left;
  final String right;
  const _TotalLine({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.text, width: 1.5))),
        child: Row(children: [
          Expanded(
            child: Text(left, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
          Text(right, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: C.blue, fontFeatures: tabular)),
        ]),
      );
}

/// Kisanduku cha "Bidhaa" (urefu 38, radius 7) chenye "zipo N" kulia
class _BidhaaField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final String? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  const _BidhaaField({required this.controller, required this.focus, this.suffix, this.onChanged, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: c, width: w));
    return SizedBox(
      height: 38,
      child: TextField(
        controller: controller,
        focusNode: focus,
        textInputAction: TextInputAction.next,
        textCapitalization: TextCapitalization.sentences,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Tafuta bidhaa…',
          hintStyle: const TextStyle(color: C.faint, fontWeight: FontWeight.w400),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          suffixIcon: suffix == null ? null : Padding(padding: const EdgeInsets.only(right: 10), child: Text(suffix!, style: const TextStyle(fontSize: 12, color: C.muted))),
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          enabledBorder: b(C.field, 1),
          focusedBorder: b(C.blue, 1.5),
          border: b(C.field, 1),
        ),
      ),
    );
  }
}

/// Next › (34 juu, radius 8, bluu) — hufifia mpaka sehemu zijazwe
class _NextBtn extends StatelessWidget {
  final VoidCallback? onTap;
  const _NextBtn({this.onTap});
  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Opacity(
      opacity: on ? 1 : .4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 34,
          padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
          decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(8)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Next', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
          ]),
        ),
      ),
    );
  }
}

// ======================================================================= T09 — ukurasa wa risiti

class ReceiptScreen extends StatefulWidget {
  final String id;
  const ReceiptScreen({super.key, required this.id});
  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  Receipt? _r;
  Shop? _shop;
  Object? _err;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    Api.i.shop().then((s) {
      if (mounted) setState(() => _shop = s);
    }).catchError((_) {});
  }

  Future<void> _load() async {
    try {
      final r = await Api.i.receipt(widget.id);
      if (mounted) setState(() => _r = r);
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  Future<void> _pdf({required bool share}) async {
    final r = _r;
    if (r == null || _busy) return;
    setState(() => _busy = true);
    try {
      final shop = _shop ?? r.shop ?? Shop(name: 'UMMU AYMAN OUTFITS', phone: '', email: '');
      if (share) {
        await shareReceiptPdf(r, shop);
      } else {
        await downloadReceiptPdf(r, shop);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: pageBar(
        r == null ? 'Risiti' : 'Risiti Na. ${r.number}',
        subtitle: r == null ? '' : '${titleCase(r.customerName.isEmpty ? 'Mteja' : r.customerName)} · ${hhmm(r.createdAt)}',
        flatBack: true,
      ),
      // Upau wa vitufe (46×46, icon pekee) umekaa juu ya menyu ya chini.
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _IconAction(AppIcons.download, busy: _busy, onTap: r == null ? null : () => _pdf(share: false)),
            const SizedBox(width: 10),
            _IconAction(AppIcons.share2, onTap: r == null ? null : () => _pdf(share: true)),
            const SizedBox(width: 10),
            _IconAction(AppIcons.whatsapp, whatsapp: true, onTap: r == null ? null : () => openReceiptWhatsApp(r, _shop)),
          ]),
        ),
        const AppNav(index: 4),
      ]),
      body: _err != null
          ? ErrorView(_err!, onRetry: _load)
          : r == null
              ? const SizedBox.expand()
              : ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
                  Box(
                    radius: 14,
                    border: C.cardLine,
                    padding: EdgeInsets.zero,
                    child: ReceiptBody(r, shop: r.shop ?? _shop),
                  ),
                ]),
    );
  }
}

/// Mwili wa risiti: duka katikati · MTEJA kushoto / Na., tarehe, saa kulia ·
/// jedwali · Jumla/Punguzo · IMELIPWA · "Asante kwa kununua nasi".
class ReceiptBody extends StatelessWidget {
  final Receipt r;
  final Shop? shop;
  const ReceiptBody(this.r, {super.key, this.shop});

  @override
  Widget build(BuildContext context) {
    const sub = TextStyle(fontSize: 13, color: C.muted);
    const th = TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: C.blue, letterSpacing: .4);
    const total = TextStyle(fontSize: 14.5, color: C.muted);
    final shopName = (shop?.name.isNotEmpty ?? false) ? shop!.name : 'UMMU AYMAN OUTFITS';
    final contact = [if (shop != null && shop!.phone.isNotEmpty) shop!.phone, if (shop != null && shop!.email.isNotEmpty) shop!.email].join(' · ');

    return Padding(
      // Nembo pembeni kushoto (kubwa kidogo), jina la duka na namba
      // zinajipanga kando yake; zikikosa nafasi zinapungua kwa upole.
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Image.asset('assets/brand/logo_mark.png', height: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(shopName,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.blue)),
              ),
              if (contact.isNotEmpty) ...[
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(contact, maxLines: 1, style: sub),
                ),
              ],
            ]),
          ),
        ]),
          const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: DottedLine()),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('MTEJA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: C.muted, letterSpacing: .4)),
                const SizedBox(height: 2),
                Text(titleCase(r.customerName.isEmpty ? 'Mteja' : r.customerName),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                if (r.customerPhone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(phoneFmt(r.customerPhone), style: sub),
                  ),
              ]),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(dateShort(r.createdAt), style: const TextStyle(fontSize: 13.5, color: C.muted, fontFeatures: tabular)),
              const SizedBox(height: 2),
              Text('Saa ${hhmm(r.createdAt)}', style: const TextStyle(fontSize: 13.5, color: C.muted, fontFeatures: tabular)),
            ]),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(bottom: 7),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.text, width: 1.5))),
            child: Row(children: [const Expanded(child: Text('BIDHAA', style: th)), const Text('KIASI', style: th)]),
          ),
          // Kila bidhaa: jina na kiasi tu — hakuna "3 × 15,000" wala maelezo ya punguzo.
          for (final it in r.items)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.softLine))),
              child: Row(children: [
                Expanded(
                  child: Text(it.name,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                Text(money(it.amount), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, fontFeatures: tabular)),
              ]),
            ),
          if (r.discountTotal > 0) ...[
            const SizedBox(height: 12),
            Row(children: [const Expanded(child: Text('Jumla kabla ya punguzo', style: total)), Text(money(r.gross), style: total)]),
            const SizedBox(height: 6),
            Row(children: [const Expanded(child: Text('Punguzo', style: total)), Text('− ${money(r.discountTotal)}', style: total)]),
          ],
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.text, width: 1.5))),
            child: Row(children: [
              const Expanded(child: Text('IMELIPWA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              Text(money(r.paid), style: const TextStyle(fontSize: 26, height: 1.1, fontWeight: FontWeight.w700, color: C.blue, fontFeatures: tabular)),
            ]),
          ),
          const SizedBox(height: 16),
          const DottedLine(),
          const SizedBox(height: 12),
          const Text('Asante kwa kununua nasi', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: C.muted)),
      ]),
    );
  }
}

/// Mstari wa vidoti (kama kwenye risiti ya karatasi)
class DottedLine extends StatelessWidget {
  final Color color;
  const DottedLine({super.key, this.color = const Color(0xFFCBD5E1)});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (c, b) {
        final n = (b.maxWidth / 8).floor().clamp(4, 400);
        return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var i = 0; i < n; i++) Container(width: 4, height: 1, color: color),
        ]);
      });
}

/// Kitufe cha ikoni pekee (46×46, radius 10): Pakua PDF · Shiriki · WhatsApp.
class _IconAction extends StatelessWidget {
  final String icon;
  final bool whatsapp;
  final bool busy;
  final VoidCallback? onTap;
  const _IconAction(this.icon, {this.whatsapp = false, this.busy = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = whatsapp ? Colors.white : C.blue;
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: whatsapp ? const Color(0xFF1FA855) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: whatsapp ? const Color(0xFF1FA855) : C.blue, width: 1.2),
        ),
        child: Center(child: busy ? DotsLoader(color: fg, size: 5) : AppIcon(icon, size: 22, color: fg)),
      ),
    );
  }
}

// ======================================================================= T10 — historia

class ReceiptHistoryScreen extends StatefulWidget {
  const ReceiptHistoryScreen({super.key});
  @override
  State<ReceiptHistoryScreen> createState() => _ReceiptHistoryScreenState();
}

class _ReceiptHistoryScreenState extends State<ReceiptHistoryScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final List<ReceiptDay> _days = [];
  String? _before;
  bool _loading = true, _more = false;
  Object? _error;
  Timer? _debounce;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Scroll -> C3 kwa `before={next_before}`.
  void _onScroll() {
    if (!_scroll.hasClients || _before == null || _more || _loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 160) _load(more: true);
  }

  Future<void> _load({bool more = false}) async {
    final seq = ++_seq;
    setState(() {
      _error = null;
      if (more) {
        _more = true;
      } else {
        _loading = true;
      }
    });
    try {
      final h = await Api.i.receiptHistory(q: _search.text.trim(), before: more ? _before : null);
      if (!mounted || seq != _seq) return;
      setState(() {
        if (!more) _days.clear();
        _days.addAll(h.days);
        _before = h.nextBefore;
        _loading = false;
        _more = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = e;
        _loading = false;
        _more = false;
      });
    }
  }

  /// Kutafuta: subiri 300ms baada ya kuandika.
  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: pageBar('Historia', subtitle: 'Risiti zote', flatBack: true),
        // Menyu ya chini inaonekana pia hapa; Risiti ikiwa active.
        bottomNavigationBar: const AppNav(index: 4),
        body: _loading && _days.isEmpty
            ? const Loading()
            : ListView(
                controller: _scroll,
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.cardLine)),
                      child: Row(children: [
                        const Icon(Icons.search_rounded, size: 20, color: C.faint),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _search,
                            onChanged: _onSearch,
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              hintText: 'Tafuta mteja au namba…',
                              hintStyle: TextStyle(color: C.faint, fontSize: 14, fontWeight: FontWeight.w400),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                      child: Column(children: [
                        Text('$_error', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.red)),
                        const SizedBox(height: 8),
                        SmallButton('Jaribu tena', onTap: () => _load()),
                      ]),
                    ),
                  if (_error == null && !_loading && _days.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Text('Hakuna risiti', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: C.muted)),
                    ),
                  for (final d in _days) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 24, 18, 10),
                      child: Row(children: [
                        Expanded(
                          child: Text(d.label.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: .55, color: C.text)),
                        ),
                        const SizedBox(width: 10),
                        Text(money(d.total), style: const TextStyle(fontSize: 13, color: C.muted, fontFeatures: tabular)),
                      ]),
                    ),
                    for (final r in d.rows)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _HistCard(
                          row: r,
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(id: r.id)));
                            _load();
                          },
                        ),
                      ),
                  ],
                  if (_more) const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Center(child: DotsLoader(size: 6))),
                  const SizedBox(height: 24),
                ],
              ),
      );
}

/// Kadi ya risiti kwenye Historia: mteja · Na./saa kushoto, kiasi › kulia.
class _HistCard extends StatelessWidget {
  final ReceiptRow row;
  final VoidCallback onTap;
  const _HistCard({required this.row, required this.onTap});
  @override
  Widget build(BuildContext context) => Box(
        onTap: onTap,
        radius: 13,
        border: C.cardLine,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titleCase(row.customer),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('Na. ${row.number} · ${row.time}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: C.muted, fontFeatures: tabular)),
            ]),
          ),
          const SizedBox(width: 10),
          Text(money(row.paid), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, fontFeatures: tabular)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, size: 20, color: C.faint),
        ]),
      );
}

// ======================================================================= wasaidizi

/// "said hamad" -> "Said Hamad"
String titleCase(String s) => s
    .trim()
    .split(RegExp(r'\s+'))
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

/// 0712445900 -> "0712 445 900"
String phoneFmt(String p) {
  final d = p.replaceAll(RegExp(r'\D'), '');
  return d.length == 10 ? '${d.substring(0, 4)} ${d.substring(4, 7)} ${d.substring(7)}' : p;
}

String _waText(Receipt r, Shop? shop) {
  final b = StringBuffer('*${(shop?.name.isNotEmpty ?? false) ? shop!.name : 'UMMU AYMAN OUTFITS'}*\n');
  b.writeln('Risiti Na. ${r.number} · ${dateShort(r.createdAt)}, ${hhmm(r.createdAt)}');
  if (r.customerName.isNotEmpty) b.writeln('Mteja: ${titleCase(r.customerName)}');
  b.writeln();
  for (final i in r.items) {
    b.writeln('${i.name} — ${money(i.amount)}');
  }
  b
    ..writeln()
    ..writeln('*IMELIPWA: ${money(r.paid)}*')
    ..write('Asante kwa kununua nasi');
  return b.toString();
}

/// Simu ya mteja 0712… -> 255712…; bila simu -> wa.me/?text=
Future<void> openReceiptWhatsApp(Receipt r, Shop? shop) async {
  final intl = waPhone(r.customerPhone);
  final url = intl.isEmpty ? 'https://wa.me/?text=' : 'https://wa.me/$intl?text=';
  await launchUrl(Uri.parse(url + Uri.encodeComponent(_waText(r, shop))), mode: LaunchMode.externalApplication);
}

/// Inatumiwa na sehemu nyingine zinazohitaji kunakili maandishi ya risiti.
Future<void> copyReceiptText(Receipt r) => Clipboard.setData(ClipboardData(text: _waText(r, null)));
