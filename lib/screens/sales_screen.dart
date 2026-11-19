import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';

/// MAUZO YA LEO — daftari la jioni
///  1. Bidhaa zilizouzwa: mistari ya risiti ipo tayari ("risiti 0003"), anaendelea kuandika chini yake.
///     Mstari: andika jina -> orodha inashuka chini ya mstari -> gusa aina (au Ijayo = ya kwanza)
///            -> Idadi -> Ijayo -> Selling (imejaa kutoka stock, anaweza kubadilisha) -> Ijayo -> mstari mpya.
///     Buying inajaa yenyewe; Profit inajihesabu.
///  2. Gharama: jina lolote -> kiasi -> Ijayo.
///  3. Hesabu ya leo: Mauzo, Mtaji, Faida ya bidhaa, Gharama, Faida halisi.
///  4. Kitufe kidogo: Hifadhi -> (vidoti) -> Hariri.
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _day = dayOnly(DateTime.now());
  bool _loading = true;
  Object? _error;

  List<SaleLine> _receiptLines = [];
  List<SaleLine> _lines = [];
  List<SaleLine> _savedLines = []; // zilizohifadhiwa (zimeshatoka stock)
  List<Expense> _exps = [];
  List<Variant> _variants = [];
  List<String> _expNames = [];
  bool _saved = false;
  bool _saving = false;

  // mhariri wa mstari wa mauzo
  int _editIndex = -1; // -1 = mstari mpya
  Variant? _sel;
  final _nameC = TextEditingController();
  final _qtyC = TextEditingController();
  final _sellC = TextEditingController();
  final _nameF = FocusNode();
  final _qtyF = FocusNode();
  final _sellF = FocusNode();

  // mhariri wa gharama
  int _expIndex = -1;
  final _eNameC = TextEditingController();
  final _eAmtC = TextEditingController();
  final _eNameF = FocusNode();
  final _eAmtF = FocusNode();

  @override
  void initState() {
    super.initState();
    for (final f in [_nameF, _qtyF, _sellF, _eNameF, _eAmtF]) {
      f.addListener(() => setState(() {}));
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [_nameC, _qtyC, _sellC, _eNameC, _eAmtC]) {
      c.dispose();
    }
    for (final f in [_nameF, _qtyF, _sellF, _eNameF, _eAmtF]) {
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
      final r = await Future.wait([Api.i.daily(_day), Api.i.products(), Api.i.expenseNames()]);
      final d = r[0] as DailySheet;
      _variants = (r[1] as List<Product>).expand((p) => p.variants).toList();
      _expNames = r[2] as List<String>;
      _apply(d);
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
    _resetEditor();
    _resetExp();
  }

  // ------------------------------------------------------------ hesabu
  List<SaleLine> get _all => [..._receiptLines, ..._lines];
  int get _sales => _all.fold(0, (a, l) => a + l.sales);
  int get _capital => _all.fold(0, (a, l) => a + l.capital);
  int get _expenses => _exps.fold(0, (a, e) => a + e.amount);

  /// zilizopo kwa aina hii (stock ya sasa + zilizohifadhiwa awali leo - zilizoandikwa kwenye mistari mingine)
  int _available(String vid, {int exceptIndex = -1}) {
    final v = _variants.firstWhere((x) => x.id == vid);
    final saved = _savedLines.where((l) => l.variantId == vid).fold<int>(0, (a, l) => a + l.qty);
    var used = 0;
    for (var i = 0; i < _lines.length; i++) {
      if (i != exceptIndex && _lines[i].variantId == vid) used += _lines[i].qty;
    }
    return v.qty + saved - used;
  }

  void _focusLater(FocusNode f) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) f.requestFocus();
      });

  // ------------------------------------------------------------ mhariri wa mauzo
  void _resetEditor() {
    _editIndex = -1;
    _sel = null;
    _nameC.clear();
    _qtyC.clear();
    _sellC.clear();
  }

  List<Variant> get _matches {
    final q = _nameC.text.trim();
    if (q.isEmpty || (_sel != null && _sel!.name == _nameC.text)) return [];
    return _variants.where((v) => nameMatches(v.name, q)).take(5).toList();
  }

  void _pick(Variant v) {
    setState(() {
      _sel = v;
      _nameC.text = v.name;
      _sellC.text = money(v.selling);
    });
    _focusLater(_qtyF);
  }

  void _onNameSubmit(String _) {
    if (_sel == null || _sel!.name != _nameC.text) {
      final m = _matches;
      if (m.isEmpty) {
        showError(context, 'Bidhaa "${_nameC.text}" haipo kwenye stock');
        _nameF.requestFocus();
        return;
      }
      _pick(m.first);
    } else {
      _qtyF.requestFocus();
    }
  }

  void _onQtySubmit(String _) {
    _sellF.requestFocus();
    _sellC.selection = TextSelection(baseOffset: 0, extentOffset: _sellC.text.length);
  }

  void _commitLine([String? _]) {
    final v = _sel;
    final q = parseMoney(_qtyC.text);
    final s = parseMoney(_sellC.text);
    if (v == null) return _nameF.requestFocus();
    if (q <= 0) {
      showError(context, 'Andika idadi');
      return _qtyF.requestFocus();
    }
    if (s <= 0) {
      showError(context, 'Andika bei');
      return _sellF.requestFocus();
    }
    final avail = _available(v.id, exceptIndex: _editIndex);
    if (q > avail) {
      showError(context, '${v.name}: zipo $avail tu');
      return _qtyF.requestFocus();
    }
    final line = SaleLine(variantId: v.id, name: v.name, qty: q, selling: s, buying: v.buying, stockSelling: v.selling);
    setState(() {
      if (_editIndex >= 0) {
        _lines[_editIndex] = line;
      } else {
        _lines.add(line);
      }
      _resetEditor();
    });
    _focusLater(_nameF);
  }

  void _editLine(int i) {
    if (_saved) return;
    final l = _lines[i];
    setState(() {
      _editIndex = i;
      _sel = _variants.firstWhere((v) => v.id == l.variantId);
      _nameC.text = l.name;
      _qtyC.text = '${l.qty}';
      _sellC.text = money(l.selling);
    });
    _focusLater(_qtyF);
  }

  Future<void> _deleteLine(int i) async {
    if (_saved) return;
    final ok = await confirmDelete(context, title: 'Ondoa ${_lines[i].name}?', message: 'Mstari huu utaondolewa kwenye mauzo ya leo.');
    if (ok) setState(() => _lines.removeAt(i));
  }

  // ------------------------------------------------------------ mhariri wa gharama
  void _resetExp() {
    _expIndex = -1;
    _eNameC.clear();
    _eAmtC.clear();
  }

  void _commitExp([String? _]) {
    final n = _eNameC.text.trim();
    final a = parseMoney(_eAmtC.text);
    if (n.isEmpty) return _eNameF.requestFocus();
    if (a <= 0) return _eAmtF.requestFocus();
    setState(() {
      final e = Expense(name: n[0].toUpperCase() + n.substring(1), amount: a);
      if (_expIndex >= 0) {
        _exps[_expIndex] = e;
      } else {
        _exps.add(e);
      }
      _resetExp();
    });
    _eNameF.requestFocus();
  }

  // ------------------------------------------------------------ hifadhi / hariri
  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final d = await Future.wait([Api.i.saveDaily(_day, _lines, _exps), Future.delayed(const Duration(milliseconds: 700))]);
      final p = await Api.i.products();
      _variants = p.expand((x) => x.variants).toList();
      setState(() => _apply(d[0] as DailySheet));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ------------------------------------------------------------ UI
  static const _w = <double?>[20, null, 40, 70, 58, 62];

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      appBar: pageBar('Mauzo ya leo', subtitle: dateLong(_day)),
      body: _loading
          ? const Loading()
          : _error != null
              ? ErrorView(_error!, onRetry: _load)
              : Column(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
                        const SectionTitle('Bidhaa zilizouzwa', padding: EdgeInsets.fromLTRB(2, 18, 2, 6)),
                        const TableHead(['#', 'BIDHAA', 'IDADI', 'SELLING', 'BUYING', 'PROFIT'], _w),
                        for (var i = 0; i < _receiptLines.length; i++) _row(i + 1, _receiptLines[i]),
                        for (var i = 0; i < _lines.length; i++)
                          if (i == _editIndex && !_saved) _editorRow(_receiptLines.length + i + 1) else _row(_receiptLines.length + i + 1, _lines[i], onTap: () => _editLine(i), onLong: () => _deleteLine(i)),
                        if (!_saved && _editIndex == -1) _editorRow(_all.length + 1),
                        if (!_saved && (_nameF.hasFocus) && _matches.isNotEmpty) _dropdown(),
                        _totalRow(),
                        const SectionTitle('Gharama'),
                        const TableHead(['#', 'JINA', 'KIASI'], [20, null, 110]),
                        for (var i = 0; i < _exps.length; i++)
                          if (i == _expIndex && !_saved) _expEditor(i + 1) else _expRow(i + 1, _exps[i], i),
                        if (!_saved && _expIndex == -1) _expEditor(_exps.length + 1),
                        if (!_saved && _eNameF.hasFocus) _expChips(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                          child: Row(children: [
                            const Expanded(child: Text('Jumla', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800))),
                            Text(money(_expenses), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, fontFeatures: tabular)),
                          ]),
                        ),
                        const SectionTitle('Hesabu ya leo'),
                        Statement(sales: _sales, capital: _capital, expenses: _expenses),
                        const SizedBox(height: 12),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          SmallButton(_saved ? 'Hariri' : 'Hifadhi', busy: _saving, color: _saved ? C.text2 : C.blue, onTap: _saved ? () => setState(() => _saved = false) : _save),
                        ]),
                      ]),
                    ),
                  ),
                  if (kb) _liveBar(),
                ]),
    );
  }

  Widget _num(double? w, String t, {bool bold = false, Color? color}) => tableCell(
      w, Text(t, textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w400, color: color, fontFeatures: tabular)));

  Widget _row(int n, SaleLine l, {VoidCallback? onTap, VoidCallback? onLong}) => InkWell(
        onTap: onTap,
        onLongPress: onLong,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.blueLine))),
          child: Row(children: [
            tableCell(_w[0], Text('$n', style: const TextStyle(fontSize: 11, color: C.faint))),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.name, maxLines: 2, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                if (l.fromReceipt) Text('risiti ${l.receiptNo}', style: const TextStyle(fontSize: 10.5, color: C.faint)),
              ]),
            ),
            _num(_w[2], '${l.qty}'),
            _num(_w[3], money(l.selling)),
            _num(_w[4], money(l.buying), color: C.text2),
            _num(_w[5], money(l.profit), bold: true),
          ]),
        ),
      );

  Widget _editorRow(int n) {
    final v = _sel;
    final q = parseMoney(_qtyC.text);
    final s = parseMoney(_sellC.text);
    return Container(
      decoration: const BoxDecoration(color: C.blue3, border: Border(bottom: BorderSide(color: C.blueLine))),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(children: [
        tableCell(_w[0], Text('$n', style: const TextStyle(fontSize: 11, color: C.faint))),
        if (v == null)
          Expanded(
            child: InlineInput(
              controller: _nameC,
              focus: _nameF,
              outlined: true,
              align: TextAlign.left,
              hint: 'Andika jina la bidhaa…',
              onChanged: (_) => setState(() {}),
              onSubmitted: _onNameSubmit,
            ),
          )
        else ...[
          Expanded(
            child: InkWell(
              // gusa jina kubadilisha bidhaa
              onTap: () {
                setState(() {
                  _sel = null;
                  _qtyC.clear();
                  _sellC.clear();
                });
                _focusLater(_nameF);
              },
              child: Text(v.name, maxLines: 2, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
          ),
          tableCell(_w[2], InlineInput(controller: _qtyC, focus: _qtyF, number: true, align: TextAlign.center, onChanged: (_) => setState(() {}), onSubmitted: _onQtySubmit)),
          tableCell(_w[3], InlineInput(controller: _sellC, focus: _sellF, number: true, onChanged: (_) => setState(() {}), onSubmitted: _commitLine)),
          _num(_w[4], money(v.buying), color: C.text2),
          _num(_w[5], q > 0 && s > 0 ? money(q * (s - v.buying)) : '', bold: true),
        ],
      ]),
    );
  }

  /// orodha ya aina inashuka CHINI ya mstari unaoandikwa
  Widget _dropdown() => Container(
        margin: const EdgeInsets.fromLTRB(24, 2, 0, 8),
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

  Widget _totalRow() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.text, width: 1.5))),
        child: Row(children: [
          tableCell(_w[0], const SizedBox()),
          const Expanded(child: Text('Jumla', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800))),
          _num(_w[2], '${_all.fold<int>(0, (a, l) => a + l.qty)}', bold: true),
          tableCell(190, Text(money(_sales - _capital), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: C.blue, fontFeatures: tabular))),
        ]),
      );

  Widget _expRow(int n, Expense e, int i) => InkWell(
        onTap: _saved
            ? null
            : () => setState(() {
                  _expIndex = i;
                  _eNameC.text = e.name;
                  _eAmtC.text = money(e.amount);
                  _eAmtF.requestFocus();
                }),
        onLongPress: _saved
            ? null
            : () async {
                if (await confirmDelete(context, title: 'Ondoa ${e.name}?', message: 'Gharama hii itaondolewa.')) setState(() => _exps.removeAt(i));
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.blueLine))),
          child: Row(children: [
            tableCell(20, Text('$n', style: const TextStyle(fontSize: 11, color: C.faint))),
            Expanded(child: Text(e.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
            SizedBox(width: 110, child: Text(money(e.amount), textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFeatures: tabular))),
          ]),
        ),
      );

  Widget _expEditor(int n) => Container(
        decoration: const BoxDecoration(color: C.blue3, border: Border(bottom: BorderSide(color: C.blueLine))),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(children: [
          tableCell(20, Text('$n', style: const TextStyle(fontSize: 11, color: C.faint))),
          Expanded(
            child: InlineInput(
              controller: _eNameC,
              focus: _eNameF,
              outlined: true,
              align: TextAlign.left,
              hint: 'Mf. Usafirishaji, Bando…',
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _eAmtF.requestFocus(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 110, child: InlineInput(controller: _eAmtC, focus: _eAmtF, number: true, outlined: true, hint: 'Kiasi', onSubmitted: _commitExp)),
        ]),
      );

  Widget _expChips() {
    final q = _eNameC.text.toLowerCase();
    final names = _expNames.where((n) => q.isEmpty || n.toLowerCase().startsWith(q)).take(6).toList();
    if (names.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 0, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Gusa jina, au andika jipya', style: TextStyle(fontSize: 11.5, color: C.muted)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final n in names)
            InkWell(
              onTap: () {
                _eNameC.text = n;
                _eAmtF.requestFocus();
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
                child: Text(n, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: C.text2)),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _liveBar() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
        child: Row(children: [
          Expanded(child: Text('Mauzo ${money(_sales)}', style: const TextStyle(fontSize: 12.5, color: C.muted, fontFeatures: tabular))),
          Text('Faida ${money(_sales - _capital)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: C.blue, fontFeatures: tabular)),
        ]),
      );
}
