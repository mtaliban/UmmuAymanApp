import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../services/pdf.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';
import 'shell.dart';

/// MAUZO YA LEO — kadi + dirisha linaloelea juu ya kibodi
///  1. BIDHAA ZILIZOUZWA: kadi (IDADI · SELLING · BUYING · FAIDA) + kitufe `+ Ongeza`.
///  2. Dirisha (Bidhaa | Gharama): tafuta -> gusa aina -> Idadi -> Bei -> Next.
///     Bidhaa isiyo kwenye stock: Idadi · Selling · Buying.
///  3. Jumla · Mauzo · Faida, GHARAMA + Jumla, Hesabu ya leo, Hifadhi/Hariri.
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

enum _Tab { bidhaa, gharama }

class _SalesScreenState extends State<SalesScreen> {
  final _day = dayOnly(DateTime.now());
  final _scroll = ScrollController();
  bool _loading = true;
  Object? _error;

  List<SaleLine> _receiptLines = [];
  List<SaleLine> _lines = [];
  List<SaleLine> _savedLines = [];
  List<Expense> _exps = [];
  List<Variant> _variants = [];
  bool _saved = false;
  bool _saving = false;
  bool _pdfBusy = false;
  Shop? _shop;
  int _newIndex = -1, _newExp = -1;

  // dirisha
  bool _open = false;
  _Tab _tab = _Tab.bidhaa;
  int _editIndex = -1;
  int _expIndex = -1;
  Variant? _sel;

  final _q = TextEditingController();
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _buy = TextEditingController();
  final _eName = TextEditingController();
  final _eAmt = TextEditingController();
  final _qF = FocusNode();
  final _qtyF = FocusNode();
  final _priceF = FocusNode();
  final _buyF = FocusNode();
  final _eNameF = FocusNode();
  final _eAmtF = FocusNode();

  @override
  void initState() {
    super.initState();
    for (final f in [_qF, _qtyF, _priceF, _buyF, _eNameF, _eAmtF]) {
      f.addListener(() => setState(() {}));
    }
    _load();
    Api.i.shop().then((s) {
      if (mounted) setState(() => _shop = s);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in [_q, _qty, _price, _buy, _eName, _eAmt]) {
      c.dispose();
    }
    for (final f in [_qF, _qtyF, _priceF, _buyF, _eNameF, _eAmtF]) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Future.wait([Api.i.daily(_day), Api.i.products()]);
      _variants = (r[1] as List<Product>).expand((p) => p.variants).toList();
      _apply(r[0] as DailySheet);
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _apply(DailySheet d) {
    _receiptLines = d.receiptLines;
    _lines = d.lines;
    _savedLines = d.lines.map((l) => SaleLine(variantId: l.variantId, name: l.name, qty: l.qty, selling: l.selling, buying: l.buying)).toList();
    _exps = d.expenses;
    _saved = d.savedAt != null;
    _newIndex = -1;
    _newExp = -1;
    _closeWindow();
  }

  // ------------------------------------------------------------ hesabu
  List<SaleLine> get _all => [..._receiptLines, ..._lines];
  int get _sales => _all.fold(0, (a, l) => a + l.sales);
  int get _capital => _all.fold(0, (a, l) => a + l.capital);
  int get _expenses => _exps.fold(0, (a, e) => a + e.amount);
  int get _qtyAll => _all.fold(0, (a, l) => a + l.qty);
  bool get _empty => _lines.isEmpty && _receiptLines.isEmpty;

  int _available(String vid, {int exceptIndex = -1}) {
    final i = _variants.indexWhere((x) => x.id == vid);
    if (i < 0) return 0;
    final v = _variants[i];
    final saved = _savedLines.where((l) => l.variantId == vid).fold<int>(0, (a, l) => a + l.qty);
    var used = 0;
    for (var k = 0; k < _lines.length; k++) {
      if (k != exceptIndex && _lines[k].variantId == vid) used += _lines[k].qty;
    }
    return v.qty + saved - used;
  }

  void _focusLater(FocusNode f) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) f.requestFocus();
      });

  Future<void> _scrollEnd() async {
    await Future.delayed(const Duration(milliseconds: 80));
    if (!_scroll.hasClients) return;
    await _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  // ------------------------------------------------------------ dirisha
  void _closeWindow() {
    _open = false;
    _tab = _Tab.bidhaa;
    _editIndex = -1;
    _expIndex = -1;
    _sel = null;
    _q.clear();
    _qty.clear();
    _price.clear();
    _buy.clear();
    _eName.clear();
    _eAmt.clear();
  }

  void _closeAndUnfocus() {
    setState(_closeWindow);
    FocusScope.of(context).unfocus();
  }

  void _openAdd() {
    if (_saved) return;
    setState(() {
      _closeWindow();
      _open = true;
    });
    _focusLater(_qF);
  }

  void _openEdit(int i) {
    if (_saved) return;
    final l = _lines[i];
    setState(() {
      _closeWindow();
      _open = true;
      _editIndex = i;
      final idx = _variants.indexWhere((v) => v.id == l.variantId);
      _sel = idx < 0 ? null : _variants[idx];
      _q.text = l.name;
      _qty.text = '${l.qty}';
      _price.text = money(l.selling);
      _buy.text = l.buying > 0 ? money(l.buying) : '';
    });
    _focusLater(_qtyF);
  }

  void _openExpense(int i) {
    if (_saved) return;
    setState(() {
      _closeWindow();
      _open = true;
      _tab = _Tab.gharama;
      _expIndex = i;
      _eName.text = _exps[i].name;
      _eAmt.text = money(_exps[i].amount);
    });
    _focusLater(_eAmtF);
  }

  List<Variant> get _matches {
    final q = _q.text.trim();
    if (q.isEmpty || (_sel != null && _sel!.name == _q.text)) return [];
    return _variants.where((v) => nameMatches(v.name, q)).take(6).toList();
  }

  bool get _noMatch => _sel == null && _q.text.trim().length >= 2 && _matches.isEmpty;

  void _pick(Variant v) {
    setState(() {
      _sel = v;
      _q.text = v.name;
      _price.text = money(v.selling);
      _qty.clear();
    });
    _focusLater(_qtyF);
  }

  int get _avail => _sel == null ? 0 : _available(_sel!.id, exceptIndex: _editIndex);

  bool get _canNext {
    if (_tab == _Tab.gharama) return _eName.text.trim().isNotEmpty && parseMoney(_eAmt.text) > 0;
    final q = parseMoney(_qty.text), p = parseMoney(_price.text);
    if (_sel != null) return q > 0 && p > 0 && q <= _avail;
    if (_editIndex >= 0 || _noMatch) return q > 0 && p > 0 && parseMoney(_buy.text) > 0;
    return false;
  }

  // ------------------------------------------------------------ PDF / shiriki
  Shop get _shopInfo => _shop ?? Shop(name: 'UMMU AYMAN OUTFITS', phone: '', email: '');

  String get _pdfName => 'Mauzo-${dateShort(_day).replaceAll(' ', '-')}.pdf';

  Future<void> _downloadPdf() async {
    if (_pdfBusy) return;
    setState(() => _pdfBusy = true);
    try {
      final bytes = await dailyPdf(shop: _shopInfo, date: _day, lines: _all, expenses: _exps);
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: _pdfName);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _sharePdf() async {
    if (_pdfBusy) return;
    setState(() => _pdfBusy = true);
    try {
      final bytes = await dailyPdf(shop: _shopInfo, date: _day, lines: _all, expenses: _exps);
      await Printing.sharePdf(bytes: bytes, filename: _pdfName);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _persist() async {
    try {
      await Api.i.saveDaily(_day, _lines, _exps);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _next() async {
    if (!_canNext) return;
    if (_tab == _Tab.gharama) {
      final e = Expense(name: _eName.text.trim(), amount: parseMoney(_eAmt.text));
      setState(() {
        if (_expIndex >= 0) {
          _exps[_expIndex] = e;
        } else {
          _exps.add(e);
        }
        _newExp = _expIndex >= 0 ? _expIndex : _exps.length - 1;
        _expIndex = -1;
        _eName.clear();
        _eAmt.clear();
      });
      _focusLater(_eNameF);
      await _persist();
      return;
    }

    final q = parseMoney(_qty.text), p = parseMoney(_price.text);
    final b = parseMoney(_buy.text);
    final SaleLine line;
    if (_sel != null) {
      line = SaleLine(variantId: _sel!.id, name: _sel!.name, qty: q, selling: p, buying: _sel!.buying, stockSelling: _sel!.selling);
    } else {
      final name = _q.text.trim();
      line = SaleLine(variantId: '', name: name[0].toUpperCase() + name.substring(1), qty: q, selling: p, buying: b);
    }
    setState(() {
      if (_editIndex >= 0) {
        _lines[_editIndex] = line;
        _newIndex = _editIndex;
      } else {
        _lines.add(line);
        _newIndex = _lines.length - 1;
      }
      _editIndex = -1;
      _sel = null;
      _q.clear();
      _qty.clear();
      _price.clear();
      _buy.clear();
    });
    _focusLater(_qF);
    _scrollEnd();
    await _persist();
  }

  Future<void> _deleteLine() async {
    if (_editIndex < 0) return;
    final name = _lines[_editIndex].name;
    final ok = await confirmDelete(context, title: 'Ondoa $name?', message: 'Mstari huu utaondolewa kwenye mauzo ya leo.');
    if (!ok) return;
    setState(() {
      _lines.removeAt(_editIndex);
      _newIndex = -1;
      _closeWindow();
    });
    FocusScope.of(context).unfocus();
    await _persist();
  }

  // ------------------------------------------------------------ hifadhi
  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final r = await Future.wait([Api.i.saveDaily(_day, _lines, _exps), Future.delayed(const Duration(milliseconds: 700))]);
      final p = await Api.i.products();
      _variants = p.expand((x) => x.variants).toList();
      setState(() => _apply(r[0] as DailySheet));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Mauzo ya leo', subtitle: dateLong(_day)),
      body: _loading
          ? const Loading()
          : _error != null
              ? ErrorView(_error!, onRetry: _load)
              : Stack(children: [
                  GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: ListView(
                      controller: _scroll,
                      padding: EdgeInsets.fromLTRB(16, 0, 16, _open ? 330 : 40),
                      children: [
                        if (_receiptLines.isNotEmpty) ...[
                          const SectionTitle('Kutoka risiti', padding: EdgeInsets.fromLTRB(2, 18, 2, 8)),
                          for (final l in _receiptLines) _card(l, tag: 'Risiti ${l.receiptNo}', tagBlue: true, bg: C.receiptBg),
                        ],
                        _head(),
                        if (_empty)
                          const EmptyState(
                            icon: Icons.edit_outlined,
                            title: 'Siku mpya',
                            text: 'Bado hujaandika mauzo ya leo.\nGusa “+ Ongeza” kuanza.',
                          ),
                        for (final (i, l) in _lines.indexed)
                          _card(l, highlight: i == _newIndex, onTap: _saved ? null : () => _openEdit(i)),
                        _totalLine(),
                        const SectionTitle('Gharama'),
                        if (_exps.isEmpty)
                          const Padding(padding: EdgeInsets.fromLTRB(2, 2, 2, 8), child: Text('Bado hakuna gharama', style: TextStyle(fontSize: 13.5, color: C.muted)))
                        else
                          for (final (i, e) in _exps.indexed) _expRow(e, i),
                        _expTotal(),
                        if (_empty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Center(
                              child: Text.rich(
                                TextSpan(children: [
                                  const TextSpan(text: 'Mauzo ya jana yako kwenye '),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.baseline,
                                    baseline: TextBaseline.alphabetic,
                                    child: GestureDetector(
                                      onTap: () => Shell.of(context)?.go(3),
                                      child: const Text('Ripoti', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.blue)),
                                    ),
                                  ),
                                ]),
                                style: const TextStyle(fontSize: 12.5, color: C.faint),
                              ),
                            ),
                          )
                        else ...[
                          const SectionTitle('Hesabu ya leo'),
                          Statement(sales: _sales, capital: _capital, expenses: _expenses),
                          const SizedBox(height: 12),
                          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            SmallButton('Pakua PDF', color: C.text2, busy: _pdfBusy, icon: const Icon(Icons.download_rounded, size: 14, color: C.text2), onTap: _downloadPdf),
                            const SizedBox(width: 8),
                            SmallButton('Shiriki', color: C.text2, icon: const Icon(Icons.share_outlined, size: 13, color: C.text2), onTap: _sharePdf),
                            const SizedBox(width: 8),
                            SmallButton(_saved ? 'Hariri' : 'Hifadhi',
                                busy: _saving,
                                filled: !_saved,
                                color: _saved ? C.text2 : C.blue,
                                onTap: _saved ? () => setState(() => _saved = false) : _save),
                          ]),
                        ],
                      ],
                    ),
                  ),
                  if (_open) _window(),
                ]),
    );
  }

  Widget _head() => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
        child: Row(children: [
          const Expanded(child: Text('BIDHAA ZILIZOUZWA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .9))),
          if (!_saved) TopButton('Ongeza', onTap: _openAdd),
        ]),
      );

  Widget _card(SaleLine l, {String? tag, bool tagBlue = false, Color? bg, bool highlight = false, VoidCallback? onTap}) {
    // Bidhaa isiyo kwenye stock ina alama yake (haiathiri stock ya dukani).
    final t = tag ?? (l.variantId.isEmpty ? 'nje ya stock' : null);
    final tBg = tagBlue ? C.blue2 : (tag != null ? C.soft : const Color(0xFFF3F4F6));
    final tFg = tagBlue ? C.blue : (tag != null ? C.text2 : C.muted);
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Box(
          radius: 12,
          color: highlight ? C.blue3 : bg,
          border: highlight ? C.blue : null,
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
              if (t != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: tBg, borderRadius: BorderRadius.circular(4)),
                  child: Text(t, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tFg)),
                ),
            ]),
            const SizedBox(height: 7),
            Row(children: [
              Expanded(child: MiniStat('Idadi', '${l.qty}')),
              Expanded(child: MiniStat('Selling', money(l.selling))),
              Expanded(child: MiniStat('Buying', money(l.buying))),
              Expanded(child: MiniStat('Faida', money(l.profit), bold: true, color: C.blue)),
            ]),
          ]),
        ),
      );
  }

  Widget _totalLine() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.text, width: 1.5))),
        child: Row(children: [
          Expanded(child: Text('Jumla · $_qtyAll', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800))),
          Text('Mauzo ${money(_sales)}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: C.muted, fontFeatures: tabular)),
          const SizedBox(width: 12),
          Text('Faida ${money(_sales - _capital)}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: C.blue, fontFeatures: tabular)),
        ]),
      );

  Widget _expRow(Expense e, int i) => InkWell(
        onTap: _saved ? null : () => _openExpense(i),
        onLongPress: _saved
            ? null
            : () async {
                if (await confirmDelete(context, title: 'Ondoa ${e.name}?', message: 'Gharama hii itaondolewa.')) {
                  setState(() {
                    _exps.removeAt(i);
                    _newExp = -1;
                  });
                  await _persist();
                }
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
          decoration: BoxDecoration(
            color: i == _newExp ? C.blue3 : null,
            border: const Border(bottom: BorderSide(color: C.line)),
          ),
          child: Row(children: [
            Expanded(child: Text(e.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            Text(money(e.amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFeatures: tabular)),
          ]),
        ),
      );

  Widget _expTotal() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.text, width: 1.5))),
        child: Row(children: [
          const Expanded(child: Text('Jumla', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800))),
          Text(money(_expenses), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, fontFeatures: tabular)),
        ]),
      );

  // ------------------------------------------------------------ dirisha linaloelea
  Widget _window() {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      left: 12,
      right: 12,
      bottom: kb + 10,
      child: Material(
        color: Colors.white,
        elevation: 10,
        shadowColor: const Color(0x2E111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: C.winBorder)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _editIndex >= 0 ? const Text('Rekebisha', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)) : _tabs()),
              _closeX(),
            ]),
            const SizedBox(height: 12),
            if (_tab == _Tab.gharama) _expenseForm() else _bidhaaForm(),
          ]),
        ),
      ),
    );
  }

  Widget _tabs() => Row(children: [
        for (final (i, label) in const ['Bidhaa', 'Gharama'].indexed)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              _tab = _Tab.values[i];
              _editIndex = -1;
              _qty.clear();
              _price.clear();
              _buy.clear();
              _q.clear();
              _sel = null;
            }),
            child: Container(
              margin: const EdgeInsets.only(right: 18),
              padding: const EdgeInsets.only(bottom: 3),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _tab.index == i ? C.blue : Colors.transparent, width: 2))),
              child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _tab.index == i ? C.blue : C.faint)),
            ),
          ),
      ]);

  Widget _closeX() => InkWell(
        onTap: _closeAndUnfocus,
        customBorder: const CircleBorder(),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: C.soft, shape: BoxShape.circle, border: Border.all(color: Color(0xFFE5E7EB))),
          child: const Icon(Icons.close_rounded, size: 17, color: C.text),
        ),
      );

  Widget _bidhaaForm() {
    final q = parseMoney(_qty.text);
    final over = _sel != null && q > _avail;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _WinField(
        controller: _q,
        focus: _qF,
        hint: 'Tafuta bidhaa…',
        readOnly: _editIndex >= 0,
        suffix: _sel == null ? null : Text('zipo $_avail', style: const TextStyle(fontSize: 12, color: C.muted)),
        onChanged: (_) => setState(() {
          if (_sel != null && _q.text != _sel!.name) {
            _sel = null;
            _price.clear();
          }
        }),
        onSubmitted: (_) {
          if (_matches.isNotEmpty) _pick(_matches.first);
        },
      ),
      if (_matches.isNotEmpty)
        Column(children: [
          for (final (i, v) in _matches.indexed)
            InkWell(
              onTap: () => _pick(v),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: Color(0xFFF1F2F5)))),
                child: Row(children: [
                  Expanded(child: _bold(v.name, _q.text)),
                  Text('zipo ${v.qty} · ${money(v.selling)}', style: const TextStyle(fontSize: 12, color: C.muted)),
                ]),
              ),
            ),
        ]),
      if (_noMatch || (_editIndex >= 0 && _sel == null))
        const Padding(padding: EdgeInsets.only(top: 6), child: Text('Haipo kwenye stock — jaza bei mwenyewe', style: TextStyle(fontSize: 11.5, color: C.muted))),
      if (_sel != null || _noMatch || _editIndex >= 0) ...[
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _labelled('Idadi', _WinField(controller: _qty, focus: _qtyF, hint: '', number: true, width: 56, align: TextAlign.center, error: over, onChanged: (_) => setState(() {}))),
          const SizedBox(width: 8),
          _labelled(
            _sel != null || _editIndex >= 0 ? 'Bei' : 'Selling',
            _WinField(controller: _price, focus: _priceF, hint: '', number: true, width: 92, align: TextAlign.right, onChanged: (_) => setState(() {})),
          ),
          if (_sel == null) ...[
            const SizedBox(width: 8),
            _labelled('Buying', _WinField(controller: _buy, focus: _buyF, hint: '', number: true, width: 88, align: TextAlign.right, onChanged: (_) => setState(() {}))),
          ],
          const Spacer(),
          _nextBtn(_editIndex >= 0 ? 'Hifadhi' : 'Next'),
        ]),
        if (over)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('${_sel!.name}: zipo $_avail tu', style: const TextStyle(fontSize: 12.5, color: C.red, fontWeight: FontWeight.w600))),
        if (_editIndex >= 0)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _deleteLine,
              style: TextButton.styleFrom(foregroundColor: C.red, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Futa bidhaa hii', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.red)),
            ),
          ),
      ] else
        Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.only(top: 10), child: _nextBtn('Next'))),
    ]);
  }

  Widget _expenseForm() => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: _labelled(
            'Jina la gharama',
            _WinField(controller: _eName, focus: _eNameF, hint: '', onChanged: (_) => setState(() {}), onSubmitted: (_) => _eAmtF.requestFocus()),
          ),
        ),
        const SizedBox(width: 8),
        _labelled('Kiasi', _WinField(controller: _eAmt, focus: _eAmtF, hint: '', number: true, width: 92, align: TextAlign.right, onChanged: (_) => setState(() {}))),
        const SizedBox(width: 8),
        _nextBtn('Next'),
      ]);

  Widget _labelled(String label, Widget field) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: C.muted)),
        const SizedBox(height: 4),
        field,
      ]);

  Widget _nextBtn(String label) {
    final on = _canNext;
    return Opacity(
      opacity: on ? 1 : .4,
      child: InkWell(
        onTap: on ? _next : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 34,
          padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
          decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
          ]),
        ),
      ),
    );
  }

  Widget _bold(String n, String query) {
    final q = query.trim();
    final lower = n.toLowerCase();
    if (q.isEmpty || !lower.startsWith(q.toLowerCase())) {
      return Text(n, style: const TextStyle(fontSize: 14.5, color: C.text));
    }
    final k = q.length.clamp(0, n.length);
    return Text.rich(TextSpan(style: const TextStyle(fontSize: 14.5, color: C.text), children: [
      TextSpan(text: n.substring(0, k), style: const TextStyle(fontWeight: FontWeight.w800)),
      TextSpan(text: n.substring(k)),
    ]));
  }
}

/// Kisanduku cha dirisha: urefu 38, radius 7, mpaka #D1D5DB (bluu 1.5 ukiwa umegusa)
class _WinField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final String hint;
  final bool number;
  final bool readOnly;
  final TextAlign align;
  final double? width;
  final bool error;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  const _WinField({
    required this.controller,
    required this.focus,
    this.hint = '',
    this.number = false,
    this.readOnly = false,
    this.align = TextAlign.left,
    this.width,
    this.error = false,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: c, width: w));
    return SizedBox(
      width: width,
      height: 38,
      child: TextField(
        controller: controller,
        focusNode: focus,
        readOnly: readOnly,
        textAlign: align,
        textInputAction: TextInputAction.next,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        textCapitalization: number ? TextCapitalization.none : TextCapitalization.sentences,
        inputFormatters: [if (number) MoneyInput()],
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, fontFeatures: tabular),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(color: C.faint, fontWeight: FontWeight.w400),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          suffixIcon: suffix == null ? null : Padding(padding: const EdgeInsets.only(right: 10), child: suffix),
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          enabledBorder: b(error ? C.red : C.field, 1),
          focusedBorder: b(error ? C.red : C.blue, 1.5),
          border: b(C.field, 1),
        ),
      ),
    );
  }
}
