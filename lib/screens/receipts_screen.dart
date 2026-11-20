import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../services/pdf.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/home_bus.dart';
import '../widgets/app_icons.dart';
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
  List<Receipt> _list = [];
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
      final list = await Api.i.receipts(_day);
      if (!mounted) return;
      setState(() {
        _list = list;
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

  /// Namba inayokuja (mf. "0009").
  String get _nextNo {
    var max = 0;
    for (final r in _list) {
      final n = int.tryParse(r.number.replaceAll(RegExp(r'[^0-9]'), ''));
      if (n != null && n > max) max = n;
    }
    return '${max + 1}'.padLeft(4, '0');
  }

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
    _nameF.requestFocus();
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
    final isToday = _day == dayOnly(DateTime.now());
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: pageBar(
        'Risiti',
        subtitle: isToday ? dateLong(DateTime.now()) : dateShortDay(_day),
        back: widget.initialDay != null,
        boxBack: widget.initialDay != null,
        action: Row(mainAxisSize: MainAxisSize.min, children: [
          SmallButton('Historia',
              color: C.text2,
              borderColor: C.field,
              height: 32,
              icon: const Icon(Icons.history_rounded, size: 14, color: C.text2),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReceiptHistoryScreen()));
                if (mounted) _load();
              }),
          const SizedBox(width: 8),
          SmallButton('+ Risiti mpya', height: 32, onTap: _open ? null : _openNew),
        ]),
      ),
      body: _loading
          ? const SizedBox.expand()
          : _loadError != null
              ? ErrorView(_loadError!, onRetry: _load)
              : Stack(children: [
                  if (_open)
                    ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(16, 14, 16, 420), children: _draftView())
                  else if (_list.isEmpty)
                    const Center(child: _NoReceipts())
                  else
                    ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 120), children: [
                      SectionTitle(_day == dayOnly(DateTime.now()) ? 'Risiti za leo' : 'Risiti za ${dateShortDay(_day)}',
                          trailing: '${_list.length}', padding: const EdgeInsets.fromLTRB(2, 14, 2, 8)),
                      for (final r in _list)
                        _RcCard(
                          row: r,
                          highlight: r.id == _newId,
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(id: r.id)));
                            if (mounted) _load();
                          },
                        ),
                      _TotalLine(
                        left: 'Jumla · risiti ${_list.length}',
                        right: money(_list.fold<int>(0, (a, r) => a + r.paid)),
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
    final kb = MediaQuery.of(context).viewInsets.bottom;
    final showFields = _sel != null || _newName;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      left: 12,
      right: 12,
      bottom: kb + 10,
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
              customBorder: const CircleBorder(),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: C.soft, shape: BoxShape.circle, border: Border.all(color: C.line)),
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
              DialogField(label: 'Idadi', controller: _qty, focus: _qtyF, number: true, width: 54, align: TextAlign.center, onChanged: (_) => setState(() {}), onSubmitted: (_) => _next()),
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
  final Receipt row;
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
          border: highlight ? C.blue : null,
          padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titleCase(row.customerName), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('Na. ${row.number} · ${hhmm(row.createdAt)}', style: const TextStyle(fontSize: 12.5, color: C.muted, fontFeatures: tabular)),
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
        border: highlight ? C.blue : null,
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
      final shop = _shop ?? Shop(name: 'UMMU AYMAN OUTFITS', phone: '', email: '');
      final bytes = await receiptPdf(r, shop);
      final name = 'Risiti-${r.number}.pdf';
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: name);
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
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
        back: true,
        boxBack: true,
      ),
      body: _err != null
          ? ErrorView(_err!, onRetry: _load)
          : r == null
              ? const SizedBox.expand()
              : ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 120), children: [
                  Box(
                    radius: 14,
                    border: C.field,
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                    child: ReceiptBody(r, shop: _shop),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _Action('Pakua PDF', Icons.download_rounded, busy: _busy, onTap: () => _pdf(share: false))),
                    const SizedBox(width: 8),
                    Expanded(child: _Action('WhatsApp', Icons.chat_bubble_outline_rounded, green: true, onTap: () => openReceiptWhatsApp(r, _shop))),
                    const SizedBox(width: 8),
                    Expanded(child: _Action('Shiriki', Icons.share_outlined, onTap: () => _pdf(share: true))),
                  ]),
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
    const mut = TextStyle(fontSize: 12.5, color: C.muted);
    const th = TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: C.blue, letterSpacing: .4);
    final shopName = (shop?.name.isNotEmpty ?? false) ? shop!.name : 'UMMU AYMAN OUTFITS';
    final contact = [if (shop != null && shop!.phone.isNotEmpty) shop!.phone, if (shop != null && shop!.email.isNotEmpty) shop!.email].join(' · ');

    Widget row(List<Widget> c) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: c[0]),
          SizedBox(width: 36, child: c[1]),
          SizedBox(width: 64, child: c[2]),
          SizedBox(width: 74, child: c[3]),
        ]);
    Text rt(String s, [TextStyle st = const TextStyle(fontSize: 13, fontFeatures: tabular)]) => Text(s, textAlign: TextAlign.right, style: st);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(shopName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: C.blue, letterSpacing: .4)),
      if (contact.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(contact, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: C.muted)),
      ],
      const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: DottedLine()),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('MTEJA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: C.muted, letterSpacing: .3)),
            const SizedBox(height: 2),
            Text(titleCase(r.customerName.isEmpty ? 'Mteja' : r.customerName), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            if (r.customerPhone.isNotEmpty) Text(phoneFmt(r.customerPhone), style: mut),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Risiti Na. ${r.number}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(dateShort(r.createdAt), style: mut),
          Text('Saa ${hhmm(r.createdAt)}', style: mut),
        ]),
      ]),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.only(bottom: 6),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.text, width: 1.5))),
        child: row([
          const Text('BIDHAA', style: th),
          rt('IDADI', th),
          rt('BEI', th),
          rt('KIASI', th),
        ]),
      ),
      for (final it in r.items)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F2F5)))),
          child: row([
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(it.name, style: const TextStyle(fontSize: 13)),
              if (it.discount > 0) Text('punguzo ${money(it.discount)} kila moja', style: const TextStyle(fontSize: 11, color: C.muted)),
            ]),
            rt('${it.qty}'),
            rt(money(it.price)),
            rt(money(it.amount), const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: tabular)),
          ]),
        ),
      if (r.discountTotal > 0) ...[
        const SizedBox(height: 8),
        Row(children: [const Expanded(child: Text('Jumla', style: mut)), Text(money(r.gross), style: const TextStyle(fontSize: 13, fontFeatures: tabular))]),
        Row(children: [const Expanded(child: Text('Punguzo', style: mut)), Text('− ${money(r.discountTotal)}', style: const TextStyle(fontSize: 13, fontFeatures: tabular))]),
      ],
      Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.only(top: 10),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.text, width: 1.5))),
        child: Row(children: [
          const Expanded(child: Text('IMELIPWA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          Text(money(r.paid), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.blue, fontFeatures: tabular)),
        ]),
      ),
      const SizedBox(height: 16),
      const Text('Asante kwa kununua nasi', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: C.muted)),
    ]);
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

/// Kitufe cha chini ya risiti: Pakua PDF · WhatsApp · Shiriki (40 juu)
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

// ======================================================================= T10 — historia

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
    final days = [today, for (var i = 1; i <= 20; i++) today.subtract(Duration(days: i))];
    final lists = await Future.wait(days.map((d) => Api.i.receipts(d)));
    return [for (var i = 0; i < days.length; i++) (days[i], lists[i])];
  }

  String _dayLabel(DateTime d) {
    final today = dayOnly(DateTime.now());
    final wd = daysSw[d.weekday - 1];
    final md = '${d.day} ${monthsShort[d.month - 1]}';
    if (d == today) return 'Leo · $wd, $md';
    if (d == today.subtract(const Duration(days: 1))) return 'Jana · $wd, $md';
    return '$wd, $md';
  }

  void _reload() => setState(() => _f = _load());

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: pageBar('Historia', subtitle: 'Risiti zote', back: true, boxBack: true),
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
                      : g.$2.where((r) => r.customerName.toLowerCase().contains(q) || r.number.toLowerCase().contains(q)).toList();
                  return (g.$1, list);
                })
                .where((g) => g.$2.isNotEmpty)
                .toList();
            return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 60), children: [
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
                        hintText: 'Tafuta mteja au namba…',
                        hintStyle: TextStyle(color: C.faint, fontSize: 14, fontWeight: FontWeight.w400),
                      ),
                    ),
                  ),
                ]),
              ),
              if (groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Text('Hakuna risiti', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: C.muted)),
                ),
              for (final g in groups) ...[
                SectionTitle(_dayLabel(g.$1),
                    trailing: money(g.$2.fold<int>(0, (a, r) => a + r.paid)), padding: const EdgeInsets.fromLTRB(2, 18, 2, 4)),
                for (final (i, r) in g.$2.indexed)
                  InkWell(
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(id: r.id)));
                      _reload();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
                      decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: C.line))),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(titleCase(r.customerName), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('Na. ${r.number} · ${hhmm(r.createdAt)}', style: const TextStyle(fontSize: 12, color: C.muted, fontFeatures: tabular)),
                          ]),
                        ),
                        const SizedBox(width: 10),
                        Text(money(r.paid), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, fontFeatures: tabular)),
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
    b.writeln('${i.name} ${i.qty} × ${money(i.price - i.discount)} = ${money(i.amount)}');
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
