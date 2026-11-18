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
  const ReceiptsScreen({super.key});
  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  DateTime _day = dayOnly(DateTime.now());
  late Future<List<Receipt>> _f;
  String? _hl;

  @override
  void initState() {
    super.initState();
    _f = Api.i.receipts(_day);
  }

  void _load() => setState(() => _f = Api.i.receipts(_day));

  void _move(int d) {
    final n = _day.add(Duration(days: d));
    if (n.isAfter(dayOnly(DateTime.now()))) return;
    _day = n;
    _load();
  }

  Future<void> _new() async {
    final r = await Navigator.of(context).push<Receipt>(MaterialPageRoute(builder: (_) => const NewReceiptScreen()));
    _day = dayOnly(DateTime.now());
    _hl = r?.id;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _day == dayOnly(DateTime.now());
    return Scaffold(
      appBar: pageBar('Risiti', action: TopButton('Risiti mpya', onTap: _new)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 30), children: [
        Row(children: [
          IconButton(onPressed: () => _move(-1), icon: const Icon(Icons.chevron_left_rounded, color: C.blue)),
          Expanded(child: Text(dateLong(_day), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700))),
          IconButton(onPressed: isToday ? null : () => _move(1), icon: Icon(Icons.chevron_right_rounded, color: isToday ? const Color(0xFFCBD5E1) : C.blue)),
        ]),
        FutureBuilder<List<Receipt>>(
          future: _f,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return const Loading();
            if (s.hasError) return ErrorView(s.error!, onRetry: _load);
            final list = s.data!;
            final total = list.fold<int>(0, (a, r) => a + r.paid);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('Risiti ${list.length}', trailing: 'TSh ${money(total)}', color: C.blue, padding: const EdgeInsets.fromLTRB(2, 10, 2, 8)),
              if (list.isEmpty)
                const Box(padding: EdgeInsets.all(22), child: Text('Hakuna risiti siku hii.', textAlign: TextAlign.center, style: TextStyle(color: C.muted)))
              else
                Box(
                  child: Column(children: [
                    for (var i = 0; i < list.length; i++)
                      InkWell(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptViewScreen(receipt: list[i]))),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(color: list[i].id == _hl ? C.blue3 : null, border: i == 0 ? null : const Border(top: BorderSide(color: C.line))),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Na. ${list[i].number} · ${list[i].customerName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text('${hhmm(list[i].createdAt)} · ${list[i].itemsText}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.muted)),
                              ]),
                            ),
                            const SizedBox(width: 10),
                            Text(money(list[i].paid), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, fontFeatures: tabular)),
                          ]),
                        ),
                      ),
                  ]),
                ),
            ]);
          },
        ),
      ]),
    );
  }
}

// ======================================================================= RISITI MPYA
/// Mteja (jina + WhatsApp) -> Bidhaa kama daftari: jina -> orodha chini -> Idadi -> Bei -> Punguzo -> Ijayo
/// -> Jumla / Punguzo / Imelipwa -> "Tengeneza risiti"
class NewReceiptScreen extends StatefulWidget {
  const NewReceiptScreen({super.key});
  @override
  State<NewReceiptScreen> createState() => _NewReceiptScreenState();
}

class _NewReceiptScreenState extends State<NewReceiptScreen> {
  final _cName = TextEditingController(), _cPhone = TextEditingController();
  final _fPhone = FocusNode();
  List<Variant> _variants = [];
  final List<ReceiptItem> _items = [];
  bool _busy = false;

  int _edit = -1;
  Variant? _sel;
  final _n = TextEditingController(), _q = TextEditingController(), _p = TextEditingController(), _d = TextEditingController();
  final _fn = FocusNode(), _fq = FocusNode(), _fp = FocusNode(), _fd = FocusNode();

  @override
  void initState() {
    super.initState();
    for (final f in [_fn, _fq, _fp, _fd]) {
      f.addListener(() => setState(() {}));
    }
    Api.i.products().then((p) => setState(() => _variants = p.expand((x) => x.variants).toList()));
  }

  List<Variant> get _matches {
    final q = _n.text.trim();
    if (q.isEmpty || (_sel != null && _sel!.name == _n.text)) return [];
    return _variants.where((v) => nameMatches(v.name, q)).take(5).toList();
  }

  void _pick(Variant v) {
    setState(() {
      _sel = v;
      _n.text = v.name;
      _p.text = money(v.selling);
    });
    _fq.requestFocus();
  }

  void _reset() {
    _edit = -1;
    _sel = null;
    _n.clear();
    _q.clear();
    _p.clear();
    _d.clear();
  }

  void _commit([String? _]) {
    final v = _sel;
    if (v == null) {
      _fn.requestFocus();
      return;
    }
    final q = parseMoney(_q.text), p = parseMoney(_p.text), d = parseMoney(_d.text);
    if (q <= 0) {
      showError(context, 'Andika idadi');
      _fq.requestFocus();
      return;
    }
    final used = _items.asMap().entries.where((e) => e.key != _edit && e.value.variantId == v.id).fold<int>(0, (a, e) => a + e.value.qty);
    if (q + used > v.qty) {
      showError(context, '${v.name}: zipo ${v.qty - used} tu');
      _fq.requestFocus();
      return;
    }
    if (d > p) {
      showError(context, 'Punguzo ni kubwa kuliko bei');
      _fd.requestFocus();
      return;
    }
    final it = ReceiptItem(variantId: v.id, name: v.name, qty: q, price: p, discount: d, buying: v.buying);
    setState(() {
      if (_edit >= 0) {
        _items[_edit] = it;
      } else {
        _items.add(it);
      }
      _reset();
    });
    _fn.requestFocus();
  }

  Future<void> _create() async {
    FocusScope.of(context).unfocus();
    if (_cName.text.trim().isEmpty) {
      showError(context, 'Andika jina la mteja');
      return;
    }
    if (_items.isEmpty) {
      showError(context, 'Ongeza bidhaa');
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await Api.i.createReceipt(name: _cName.text.trim(), phone: _cPhone.text.trim(), items: _items);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptViewScreen(receipt: r)));
      if (mounted) Navigator.pop(context, r);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const _w = <double?>[null, 30, 64, 64, 72];

  @override
  Widget build(BuildContext context) {
    final gross = _items.fold<int>(0, (a, i) => a + i.gross), disc = _items.fold<int>(0, (a, i) => a + i.discountTotal);
    final kb = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      appBar: pageBar('Risiti mpya', back: true),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
            const SectionTitle('Mteja', padding: EdgeInsets.fromLTRB(2, 22, 2, 12)),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Field(label: 'Jina', controller: _cName, hint: 'Jina la mteja', onSubmitted: (_) => _fPhone.requestFocus())),
              const SizedBox(width: 10),
              Expanded(child: Field(label: 'WhatsApp', controller: _cPhone, focus: _fPhone, number: true, hint: '07xx xxx xxx', onSubmitted: (_) => _fn.requestFocus())),
            ]),
            const SectionTitle('Bidhaa', padding: EdgeInsets.fromLTRB(2, 30, 2, 8)),
            const TableHead(['BIDHAA', 'IDADI', 'BEI', 'PUNGUZO', 'KIASI'], _w),
            for (var i = 0; i < _items.length; i++) if (i == _edit) _editor() else _row(i),
            if (_edit == -1) _editor(),
            if (_fn.hasFocus && _matches.isNotEmpty) _dropdown(),
            if (_items.isNotEmpty) ...[
              const SizedBox(height: 24),
              Box(
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Row(children: [
                      const Expanded(child: Text('Jumla', style: TextStyle(fontSize: 15.5, color: C.text2))),
                      Text(money(gross), style: const TextStyle(fontSize: 15.5, color: C.text2, fontFeatures: tabular)),
                    ]),
                  ),
                  StatRow('Punguzo', disc, size: 15.5),
                  StatRow('Imelipwa', gross - disc, bold: true, topLine: true, blue: true, size: 18),
                ]),
              ),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [SmallButton('Tengeneza risiti', busy: _busy, onTap: _create)]),
            ],
          ]),
        ),
        if (kb)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
            child: Row(children: [
              Expanded(child: Text('Bidhaa ${_items.fold<int>(0, (a, i) => a + i.qty)}', style: const TextStyle(fontSize: 12.5, color: C.muted))),
              Text('Jumla ${money(gross - disc)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: C.blue, fontFeatures: tabular)),
            ]),
          ),
      ]),
    );
  }

  Widget _num(double? w, String t, {bool bold = false}) =>
      tableCell(w, Text(t, textAlign: TextAlign.right, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w400, fontFeatures: tabular)));

  Widget _row(int i) {
    final it = _items[i];
    return InkWell(
      onTap: () {
        setState(() {
          _edit = i;
          _sel = _variants.firstWhere((v) => v.id == it.variantId);
          _n.text = it.name;
          _q.text = '${it.qty}';
          _p.text = money(it.price);
          _d.text = it.discount > 0 ? money(it.discount) : '';
        });
        _fq.requestFocus();
      },
      onLongPress: () => setState(() => _items.removeAt(i)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.blueLine))),
        child: Row(children: [
          Expanded(child: Text(it.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
          _num(_w[1], '${it.qty}'),
          _num(_w[2], money(it.price)),
          _num(_w[3], it.discount > 0 ? money(it.discount) : '–'),
          _num(_w[4], money(it.amount), bold: true),
        ]),
      ),
    );
  }

  Widget _editor() => Container(
        color: C.blue3,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(children: [
          Expanded(
            child: InlineInput(
              controller: _n,
              focus: _fn,
              align: TextAlign.left,
              hint: 'Andika bidhaa…',
              onChanged: (_) => setState(() {
                if (_sel != null && _sel!.name != _n.text) _sel = null;
              }),
              onSubmitted: (_) {
                final m = _matches;
                if (_sel == null && m.isNotEmpty) {
                  _pick(m.first);
                } else if (_sel != null) {
                  _fq.requestFocus();
                }
              },
            ),
          ),
          tableCell(_w[1], InlineInput(controller: _q, focus: _fq, number: true, onChanged: (_) => setState(() {}), onSubmitted: (_) => _fp.requestFocus())),
          tableCell(_w[2], InlineInput(controller: _p, focus: _fp, number: true, onChanged: (_) => setState(() {}), onSubmitted: (_) => _fd.requestFocus())),
          tableCell(_w[3], InlineInput(controller: _d, focus: _fd, number: true, hint: '0', onChanged: (_) => setState(() {}), onSubmitted: _commit)),
          _num(_w[4], ''),
        ]),
      );

  Widget _dropdown() => Container(
        margin: const EdgeInsets.fromLTRB(0, 2, 0, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 22, offset: Offset(0, 8))],
        ),
        child: Column(children: [
          for (final (i, v) in _matches.indexed)
            InkWell(
              onTap: () => _pick(v),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: Color(0xFFF1F2F5)))),
                child: Row(children: [
                  Expanded(child: Text(v.name, style: TextStyle(fontSize: 14.5, fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500, color: C.text2))),
                  Text('zipo ${v.qty} · ${money(v.selling)}', style: TextStyle(fontSize: 12, color: v.qty == 0 ? C.red : C.muted)),
                ]),
              ),
            ),
        ]),
      );
}

// ======================================================================= RISITI RASMI
class ReceiptViewScreen extends StatefulWidget {
  final Receipt receipt;
  const ReceiptViewScreen({super.key, required this.receipt});
  @override
  State<ReceiptViewScreen> createState() => _ReceiptViewScreenState();
}

class _ReceiptViewScreenState extends State<ReceiptViewScreen> {
  Shop? _shop;
  bool _pdfBusy = false;

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

  /// Inafungua WhatsApp moja kwa moja kwenye namba ya mteja, ujumbe wa risiti uko tayari.
  Future<void> _whatsapp() async {
    final phone = waPhone(widget.receipt.customerPhone);
    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(_waText())}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) showError(context, 'WhatsApp haikufunguka');
  }

  Future<void> _pdf() async {
    setState(() => _pdfBusy = true);
    try {
      final bytes = await receiptPdf(widget.receipt, _s);
      await Printing.sharePdf(bytes: bytes, filename: 'risiti-${widget.receipt.number}.pdf');
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.receipt;
    const head = TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: C.muted, letterSpacing: .5);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: pageBar('Na. ${r.number}', back: true),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          constraints: const BoxConstraints(minHeight: 540),
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, 4))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_s.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('${_s.phone} · ${_s.email}', style: const TextStyle(fontSize: 13.5, color: C.muted)),
            const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Divider(height: 1, thickness: 1.2, color: C.text)),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Mteja', style: TextStyle(fontSize: 13, color: C.muted)),
                  Text(r.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  if (r.customerPhone.isNotEmpty) Text(r.customerPhone, style: const TextStyle(fontSize: 14.5)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Na. ${r.number}', style: const TextStyle(fontSize: 13, color: C.muted)),
                Text(dateShort(r.createdAt), style: const TextStyle(fontSize: 14.5)),
              ]),
            ]),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.only(bottom: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
              child: const Row(children: [
                Expanded(child: Text('BIDHAA', style: head)),
                SizedBox(width: 40, child: Text('IDADI', textAlign: TextAlign.center, style: head)),
                SizedBox(width: 72, child: Text('BEI', textAlign: TextAlign.right, style: head)),
                SizedBox(width: 80, child: Text('KIASI', textAlign: TextAlign.right, style: head)),
              ]),
            ),
            for (final it in r.items)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(it.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      if (it.discount > 0) Text('punguzo ${money(it.discount)} kila moja', style: const TextStyle(fontSize: 11.5, color: C.muted)),
                    ]),
                  ),
                  SizedBox(width: 40, child: Text('${it.qty}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15))),
                  SizedBox(width: 72, child: Text(money(it.price - it.discount), textAlign: TextAlign.right, style: const TextStyle(fontSize: 15, fontFeatures: tabular))),
                  SizedBox(width: 80, child: Text(money(it.amount), textAlign: TextAlign.right, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, fontFeatures: tabular))),
                ]),
              ),
            const SizedBox(height: 18),
            Row(children: [
              const Spacer(flex: 9),
              Expanded(
                flex: 16,
                child: Column(children: [
                  _t('Jumla', money(r.gross)),
                  if (r.discountTotal > 0) _t('Punguzo', '− ${money(r.discountTotal)}'),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, thickness: 1.2, color: C.text)),
                  Row(children: [
                    const Expanded(child: Text('Imelipwa', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                    Text('TSh ${money(r.paid)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, fontFeatures: tabular)),
                  ]),
                ]),
              ),
            ]),
            const SizedBox(height: 40),
            const Divider(color: Color(0xFFD1D5DB)),
            const SizedBox(height: 8),
            const Text('Asante kwa kununua', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: C.muted)),
          ]),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          SmallButton('Pakua PDF', color: C.text2, busy: _pdfBusy, onTap: _pdf),
          const SizedBox(width: 8),
          SmallButton('Tuma WhatsApp', color: const Color(0xFF15803D), icon: const Icon(Icons.chat_outlined, size: 14, color: Color(0xFF15803D)), onTap: _whatsapp),
        ]),
      ]),
    );
  }

  Widget _t(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(l, style: const TextStyle(fontSize: 14.5, color: C.muted))),
          Text(v, style: const TextStyle(fontSize: 14.5, color: C.muted, fontFeatures: tabular)),
        ]),
      );
}
