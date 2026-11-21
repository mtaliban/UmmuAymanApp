import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../services/day_pdf.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/home_bus.dart';
import '../widgets/app_icons.dart';
import '../widgets/app_nav.dart';
import '../widgets/ui.dart';
import 'history_screen.dart';
import 'pin_screen.dart';
import 'receipts_screen.dart';

/// MAUZO (M01–M13) — leo na siku ya Historia.
///
/// API: S1 GET /daily/{date} · S0 GET /products/search-list · S2 POST lines ·
/// S3 PATCH lines/{id} · S4 POST expenses · S5 PATCH expenses/{id} ·
/// S6 close (Hifadhi) · S7 reopen (Hariri). Kila jibu linachorwa moja kwa moja.
///
/// Hakuna kufuta, hakuna "nje ya stock", hakuna ukaguzi wa idadi dhidi ya zipo.
class SalesScreen extends StatefulWidget {
  final String? date; // null = leo · "YYYY-MM-DD" = siku ya Historia
  const SalesScreen({super.key, this.date});
  @override
  State<SalesScreen> createState() => _SalesState();
}

enum _Tab { bidhaa, gharama }

class _SalesState extends State<SalesScreen> with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _winKey = GlobalKey(), _totKey = GlobalKey(), _expKey = GlobalKey();
  late String _day = widget.date ?? todayIso();
  bool get _isToday => widget.date == null;

  DailySheet? _d;
  List<Variant> _stock = [];
  Shop? _shop;
  Object? _loadError;
  bool _loading = true;

  bool _open = false, _busy = false, _pdfBusy = false;
  Timer? _midnight;
  _Tab _tab = _Tab.bidhaa;
  SaleLine? _editLine;
  Expense? _editExp;
  String? _newLineId, _newExpId, _error;
  Variant? _sel;

  final _q = TextEditingController();
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _buy = TextEditingController();
  final _eName = TextEditingController();
  final _eAmt = TextEditingController();
  final _qF = FocusNode(), _qtyF = FocusNode(), _eF = FocusNode(), _eAmtF = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _scheduleMidnight();
    Api.i.shop().then((s) {
      if (mounted) setState(() => _shop = s);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    _scroll.dispose();
    for (final c in [_q, _qty, _price, _buy, _eName, _eAmt]) {
      c.dispose();
    }
    for (final f in [_qF, _qtyF, _eF, _eAmtF]) {
      f.dispose();
    }
    super.dispose();
  }

  /// App ikirudi kutoka background: siku imebadilika? pakia upya.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed) return;
    if (_isToday && todayIso() != _day) {
      _close();
      setState(() {
        _day = todayIso();
        _d = null;
      });
    }
    _load();
    _scheduleMidnight();
  }

  /// Saa 6 usiku (usiku wa manane) -> siku mpya tupu bila kubonyeza kitu.
  void _scheduleMidnight() {
    _midnight?.cancel();
    if (!_isToday) return;
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now) + const Duration(seconds: 1), () {
      if (!mounted) return;
      _close();
      setState(() {
        _day = todayIso();
        _d = null;
        _loading = true;
      });
      _load();
      _scheduleMidnight();
    });
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([Api.i.daySheet(_day), Api.i.searchList()]);
      if (!mounted) return;
      setState(() {
        _d = r[0] as DailySheet;
        _stock = r[1] as List<Variant>;
        _loading = false;
        _loadError = null;
      });
    } on ApiException catch (e) {
      if (e.status == 401) {
        _toPin();
        return;
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e;
        });
      }
    }
  }

  void _toPin() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const PinScreen()), (_) => false);
  }

  // ------------------------------------------------------------ hali
  bool get _saved => _d?.savedAt != null;
  bool get _hasLines => (_d?.lines.isNotEmpty ?? false) || (_d?.receiptLines.isNotEmpty ?? false);
  bool get _hasExp => _d?.expenses.isNotEmpty ?? false;
  bool get _filled => !_open && !_saved && (_hasLines || _hasExp);

  List<Variant> get _matches {
    final q = _q.text.trim().toLowerCase();
    if (q.isEmpty || _sel != null) return [];
    final words = q.split(RegExp(r'\s+'));
    return _stock.where((v) {
      final n = v.name.toLowerCase().split(RegExp(r'\s+'));
      return words.every((w) => n.any((x) => x.startsWith(w)));
    }).take(6).toList();
  }

  bool get _newName => _sel == null && _editLine == null && _q.text.trim().length >= 2 && _matches.isEmpty;

  bool get _canNext {
    if (_busy) return false;
    if (_editExp != null || (_tab == _Tab.gharama && _editLine == null)) {
      return _eName.text.trim().isNotEmpty && parseMoney(_eAmt.text) > 0;
    }
    final q = parseMoney(_qty.text), p = parseMoney(_price.text);
    if (_editLine != null) return q > 0 && p > 0 && (_editLine!.fromStock || _buy.text.trim().isNotEmpty);
    if (_sel != null) return q > 0 && p > 0;
    if (_newName) return q > 0 && p > 0 && _buy.text.trim().isNotEmpty;
    return false;
  }

  // ------------------------------------------------------------ vitendo
  void _openAdd() {
    if (_saved) return;
    setState(() {
      _open = true;
      _tab = _Tab.bidhaa;
      _editLine = null;
      _editExp = null;
      _sel = null;
      _error = null;
    });
    _focusSoon(_qF);
    _keepAbove();
  }

  /// Focus baada ya dirisha kujengwa (requestFocus kabla haijulikani haifanyi kazi).
  void _focusSoon(FocusNode f) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _open) f.requestFocus();
      });

  void _openEditLine(SaleLine l) {
    setState(() {
      _open = true;
      _editLine = l;
      _editExp = null;
      _tab = _Tab.bidhaa;
      _error = null;
      _q.text = l.name;
      _qty.text = '${l.qty}';
      _price.text = money(l.selling);
      _buy.text = money(l.buying);
    });
    _focusSoon(_qtyF);
    _keepAbove();
  }

  void _openEditExp(Expense e) {
    setState(() {
      _open = true;
      _editExp = e;
      _editLine = null;
      _tab = _Tab.gharama;
      _error = null;
      _eName.text = e.name;
      _eAmt.text = money(e.amount);
    });
    _focusSoon(_eF);
    _keepAbove(target: _expKey);
  }

  void _close() {
    setState(() {
      _open = false;
      _sel = null;
      _editLine = null;
      _editExp = null;
      _error = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    for (final c in [_q, _qty, _price, _buy, _eName, _eAmt]) {
      c.clear();
    }
  }

  Future<bool> _run(Future<DailySheet> Function() call) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = await call();
      if (mounted) setState(() => _d = d);
      HomeBus.refresh();
      return true;
    } on ApiException catch (e) {
      if (e.status == 401) {
        _toPin();
        return false;
      }
      if (mounted) setState(() => _error = e.message);
      return false;
    } catch (_) {
      if (mounted) setState(() => _error = 'Hakuna mtandao — jaribu tena');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

  Future<void> _next() async {
    if (!_canNext) return;

    // M11 Rekebisha bidhaa -> S3
    if (_editLine != null) {
      final l = _editLine!;
      final ok = await _run(() => Api.i.updateLine(
            _day,
            l.id,
            qty: parseMoney(_qty.text),
            selling: parseMoney(_price.text),
            buying: l.fromStock ? null : parseMoney(_buy.text),
          ));
      if (ok) _close();
      return;
    }

    // Rekebisha gharama -> S5
    if (_editExp != null) {
      final e = _editExp!;
      final ok = await _run(() => Api.i.updateExpense(_day, e.id, name: _eName.text.trim(), amount: parseMoney(_eAmt.text)));
      if (ok) _close();
      return;
    }

    // M08–M09 Gharama -> S4
    if (_tab == _Tab.gharama) {
      final ok = await _run(() => Api.i.addExpense(_day, _eName.text.trim(), parseMoney(_eAmt.text)));
      if (ok) {
        setState(() {
          _newExpId = _d!.expenses.last.id;
          _eName.clear();
          _eAmt.clear();
        });
        _eF.requestFocus();
        _keepAbove(target: _expKey);
      }
      return;
    }

    // M05 / M07 Bidhaa -> S2
    final ok = await _run(() => Api.i.addLine(
          _day,
          variantId: _sel?.id,
          name: _sel?.name ?? _q.text.trim(),
          qty: parseMoney(_qty.text),
          selling: parseMoney(_price.text),
          buying: _sel == null ? parseMoney(_buy.text) : null,
        ));
    if (!ok) return;
    setState(() {
      _newLineId = _d!.lines.last.id;
      _sel = null;
      _q.clear();
      _qty.clear();
      _price.clear();
      _buy.clear();
    });
    _qF.requestFocus();
    _keepAbove();
    Api.i.searchList().then((v) {
      if (mounted) setState(() => _stock = v);
    }).catchError((_) {});
  }

  Future<void> _closeDay() => _run(() => Api.i.closeDay(_day));
  Future<void> _reopen() => _run(() => Api.i.reopenDay(_day));

  Future<void> _openHistory() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
    if (mounted) _load();
  }

  /// Gusa kadi ya risiti -> ukurasa mzima wa risiti (T09).
  Future<void> _openReceipt(String? id) async {
    if (id == null || id.isEmpty) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(id: id)));
    if (mounted) _load(); // risiti ikighairiwa, siku inabadilika
  }

  // ------------------------------------------------------------ PDF / shiriki
  Future<void> _pdf(Future<void> Function(DailySheet, Shop) run) async {
    final d = _d;
    if (d == null || _pdfBusy) return;
    setState(() => _pdfBusy = true);
    try {
      final shop = _shop ?? await Api.i.shop();
      if (mounted) setState(() => _shop = shop);
      await run(d, shop);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  /// Jumla ikae 10px juu ya dirisha (M05, M07, M09).
  Future<void> _keepAbove({GlobalKey? target}) async {
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted || !_scroll.hasClients) return;
    final w = _winKey.currentContext?.findRenderObject() as RenderBox?;
    final t = (target ?? _totKey).currentContext?.findRenderObject() as RenderBox?;
    if (w == null || t == null) return;
    final winTop = w.localToGlobal(Offset.zero).dy;
    final bottom = t.localToGlobal(Offset(0, t.size.height)).dy;
    final to = (_scroll.offset + bottom - (winTop - 10)).clamp(0.0, _scroll.position.maxScrollExtent);
    await _scroll.animateTo(to, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  /// Kadi za bidhaa kwa mpangilio mmoja: za risiti kwanza, kisha za mkono —
  /// namba inaendelea 1, 2, 3 … kama kwenye muundo.
  List<Widget> _cards(DailySheet d) {
    final out = <Widget>[];
    var n = 0;
    for (final l in d.receiptLines) {
      out.add(_InfoCard(
        rank: _isToday ? ++n : null,
        title: l.name,
        tag: 'Risiti ${l.receiptNo}',
        bg: _isToday ? C.receiptBg : null,
        profit: l.profit,
        cols: _cols(l),
        onTap: () => _openReceipt(l.receiptId),
      ));
    }
    for (final l in d.lines) {
      out.add(_InfoCard(
        rank: _isToday ? ++n : null,
        title: l.name,
        profit: l.profit,
        cols: _cols(l),
        highlight: l.id == _newLineId || l.id == _editLine?.id,
        onTap: _filled ? () => _openEditLine(l) : null,
      ));
    }
    return out;
  }

  List<(String, String)> _cols(SaleLine l) => [
        ('IDADI', '${l.qty}'),
        ('SELLING', money(l.selling)),
        ('BUYING', money(l.buying)),
        ('FAIDA', money(l.profit)),
      ];

  // ------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    final d = _d;
    final when = DateTime.parse(_day);
    final title = _isToday ? 'Mauzo ya leo' : dateShortDay(when);
    final sub = _isToday
        ? (_saved ? '${dayMonth(when)} · imehifadhiwa ${hhmm(d!.savedAt!)}' : dateLong(when))
        : (_saved ? 'Historia · imehifadhiwa' : 'Historia');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: pageBar(
        title,
        subtitle: sub,
        back: !_isToday,
        boxBack: !_isToday,
        // Siku ya historia imehifadhiwa: hakuna vitufe kichwani, kama kwenye muundo.
        action: !_isToday
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: [
                _IconBtn(svg: AppIcons.history, round: true, onTap: _openHistory),
                const SizedBox(width: 8),
                if (_saved)
                  SmallButton('Hariri', color: C.text2, borderColor: C.faint, height: 32, onTap: _busy ? null : _reopen)
                else
                  _IconBtn(icon: Icons.add_rounded, filled: true, onTap: _openAdd),
              ]),
      ),
      bottomNavigationBar: _isToday ? null : const AppNav(index: 1),
      body: _loading
          ? const SizedBox.expand()
          : _loadError != null
              ? ErrorView(_loadError!, onRetry: _load)
              : Stack(children: [
                  if (!_hasLines && !_hasExp && !_open)
                    const Center(child: _NoSales())
                  else
                    ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      children: [
                        ..._cards(d!),
                        if (_hasLines)
                          _SumCard(
                            key: _totKey,
                            items: [
                              (_isToday ? 'Jumla' : 'Idadi', '${d.qty}'),
                              ('Mauzo', money(d.totals.sales)),
                              ('Faida', money(d.totals.productProfit)),
                            ],
                          ),
                        if (_hasExp) ...[
                          const SectionTitle('Gharama', padding: EdgeInsets.fromLTRB(2, 20, 2, 8)),
                          _ExpensesCard(
                            items: d.expenses,
                            total: d.totals.expenses,
                            totalKey: _expKey,
                            highlight: {_newExpId, _editExp?.id},
                            onTap: _filled ? _openEditExp : null,
                          ),
                        ],
                        if (!_open && (_hasLines || _hasExp)) ...[
                          SectionTitle(_isToday ? 'Hesabu ya leo' : 'Hesabu ya siku', padding: const EdgeInsets.fromLTRB(2, 20, 2, 8)),
                          Statement(
                            sales: d.totals.sales,
                            capital: d.totals.capital,
                            expenses: d.totals.expenses,
                            netLabel: _isToday ? 'Faida halisi ya leo' : 'Faida halisi',
                          ),
                          const SizedBox(height: 12),
                          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            _IconBtn(svg: AppIcons.download, onTap: _pdfBusy ? null : () => _pdf(downloadDayPdf)),
                            const SizedBox(width: 8),
                            _IconBtn(svg: AppIcons.share2, onTap: _pdfBusy ? null : () => _pdf(shareDayPdf)),
                            if (!_saved) ...[
                              const SizedBox(width: 8),
                              _IconBtn(svg: AppIcons.fileText, filled: true, onTap: _busy ? null : _closeDay),
                            ],
                          ]),
                          const SizedBox(height: 120),
                        ],
                        if (_open) const SizedBox(height: 420),
                      ],
                    ),
                  if (_open) _window(),
                ]),
    );
  }

  // ------------------------------------------------------------ dirisha (M02–M11)
  Widget _window() {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    final editing = _editLine != null || _editExp != null;
    final expMode = _editExp != null || (!editing && _tab == _Tab.gharama);
    final header = editing
        ? const Text('Rekebisha', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))
        : _tabs();

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
          Row(children: [Expanded(child: header), _closeX()]),
          const SizedBox(height: 12),
          if (expMode) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                flex: 4,
                child: _labelled(
                  'Jina la gharama',
                  _WinField(controller: _eName, focus: _eF, onChanged: (_) => setState(() {}), onSubmitted: (_) => _next()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _labelled(
                  'Kiasi',
                  _WinField(
                    controller: _eAmt,
                    focus: _eAmtF,
                    number: true,
                    align: TextAlign.right,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _next(),
                  ),
                ),
              ),
            ]),
            _nextRow(editing),
          ] else
            _bidhaaForm(editing),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_error!, style: const TextStyle(fontSize: 12.5, color: C.red, fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
    );
  }

  Widget _bidhaaForm(bool editing) {
    final stock = _sel ?? _stockOf(_editLine);
    final showFields = _sel != null || _newName || _editLine != null;
    final showBuying = _newName || (_editLine != null && !_editLine!.fromStock);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _WinField(
        controller: _q,
        focus: _qF,
        hint: 'Tafuta bidhaa…',
        readOnly: _editLine != null,
        suffix: stock == null ? null : Text('zipo ${stock.qty}', style: const TextStyle(fontSize: 12, color: C.muted)),
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
                    Text('zipo ${v.qty} · ${money(v.selling)}', style: const TextStyle(fontSize: 12, color: C.muted)),
                  ]),
                ),
              ),
          ]),
        ),
      if (showFields) ...[
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            flex: 3,
            child: _labelled('Idadi',
                _WinField(controller: _qty, focus: _qtyF, number: true, align: TextAlign.center, onChanged: (_) => setState(() {}))),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: showBuying ? 4 : 5,
            child: _labelled(
              showBuying ? 'Selling' : 'Bei',
              _WinField(
                controller: _price,
                number: true,
                align: TextAlign.right,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          if (showBuying) ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: _labelled(
                'Buying',
                _WinField(controller: _buy, number: true, align: TextAlign.right, onChanged: (_) => setState(() {})),
              ),
            ),
          ],
        ]),
        _nextRow(editing),
      ] else
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _NextBtn(onTap: null),
          ),
        ),
    ]);
  }

  /// Next/Hifadhi chini ya kisanduku: namba zipate upana wote wa dirisha.
  Widget _nextRow(bool editing) => Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _NextBtn(label: editing ? 'Hifadhi' : 'Next', onTap: _canNext ? _next : null),
        ),
      );

  Variant? _stockOf(SaleLine? l) {
    if (l == null || !l.fromStock) return null;
    for (final v in _stock) {
      if (v.id == l.variantId) return v;
    }
    return null;
  }

  Widget _labelled(String label, Widget field) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: C.muted)),
          const SizedBox(height: 4),
          field,
        ],
      );

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

  Widget _tabs() => Row(children: [
        for (final (i, label) in const ['Bidhaa', 'Gharama'].indexed)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _tab = _Tab.values[i];
                _error = null;
              });
              _focusSoon(i == 0 ? _qF : _eF);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 18),
              padding: const EdgeInsets.only(bottom: 3),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: _tab.index == i ? C.blue : Colors.transparent, width: 2)),
              ),
              child: Text(label,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _tab.index == i ? C.blue : C.faint)),
            ),
          ),
      ]);

  Widget _closeX() => InkWell(
        onTap: _close,
        customBorder: const CircleBorder(),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: C.soft, shape: BoxShape.circle, border: Border.all(color: C.line)),
          child: const Icon(Icons.close_rounded, size: 16, color: C.text),
        ),
      );
}

// ======================================================================= vipande

/// M01 — hakuna mauzo leo
class _NoSales extends StatelessWidget {
  const _NoSales();
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: C.blue2, shape: BoxShape.circle),
          child: const Center(child: AppIcon(AppIcons.pencil, size: 28, color: C.text)),
        ),
        const SizedBox(height: 16),
        const Text('Hakuna mauzo leo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ]);
}

/// Kadi ya bidhaa: namba · jina · IDADI · SELLING · BUYING · FAIDA
class _InfoCard extends StatelessWidget {
  final int? rank;
  final String title;
  final String? tag;
  final List<(String, String)> cols;
  final Color? bg;
  final bool highlight;
  final int? profit;
  final VoidCallback? onTap;
  const _InfoCard({required this.title, required this.cols, this.rank, this.tag, this.bg, this.highlight = false, this.profit, this.onTap});

  @override
  Widget build(BuildContext context) {
    const flex = [62, 100, 100, 100];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Box(
        radius: 12,
        onTap: onTap,
        color: highlight ? C.blue3 : bg,
        border: highlight ? C.blue : C.cardLine,
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (rank != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('$rank', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.text2)),
              ),
            Expanded(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            ),
            if (tag != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: C.blue2, borderRadius: BorderRadius.circular(6)),
                child: Text(tag!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: C.blue)),
              ),
          ]),
          const SizedBox(height: 7),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < cols.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                flex: flex[i],
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cols[i].$1, style: const TextStyle(fontSize: 11, color: C.muted)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      cols[i].$2,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: i == cols.length - 1 ? FontWeight.w800 : FontWeight.w700,
                        color: i != cols.length - 1 ? C.text : ((profit ?? 0) < 0 ? C.red : C.blue),
                        fontFeatures: tabular,
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

/// Jumla ya mauzo: kadi yenye seli JUMLA · MAUZO · FAIDA
class _SumCard extends StatelessWidget {
  final List<(String, String)> items;
  const _SumCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.cardLine)),
        child: Row(children: [
          for (final (i, x) in items.indexed)
            Expanded(
              child: Container(
                padding: EdgeInsets.fromLTRB(i == 0 ? 14 : 12, 0, 12, 0),
                decoration: BoxDecoration(border: i == 0 ? null : const Border(left: BorderSide(color: C.line))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(x.$1.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: C.muted, letterSpacing: .5)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(x.$2,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: i == items.length - 1 ? C.blue : C.text,
                          fontFeatures: tabular,
                        )),
                  ),
                ]),
              ),
            ),
        ]),
      );
}

/// Kadi ya GHARAMA: namba · jina · kiasi, mstari mnene, kisha "Jumla ya gharama".
class _ExpensesCard extends StatelessWidget {
  final List<Expense> items;
  final int total;
  final Key? totalKey;
  final Set<String?> highlight;
  final ValueChanged<Expense>? onTap;
  const _ExpensesCard({required this.items, required this.total, this.totalKey, this.highlight = const {}, this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.cardLine),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (i, e) in items.indexed) ...[
              if (i > 0) const Divider(height: 1, thickness: 1, color: C.softLine),
              InkWell(
                onTap: onTap == null ? null : () => onTap!(e),
                child: Container(
                  color: highlight.contains(e.id) ? C.blue3 : null,
                  padding: const EdgeInsets.fromLTRB(15, 15, 16, 15),
                  child: Row(children: [
                    SizedBox(
                      width: 36,
                      child: Text('${i + 1}.',
                          style: const TextStyle(fontSize: 15, height: 1.1, fontWeight: FontWeight.w700, color: C.faint, fontFeatures: tabular)),
                    ),
                    Expanded(
                      child: Text(e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, height: 1.1, fontWeight: FontWeight.w700, color: C.text)),
                    ),
                    const SizedBox(width: 10),
                    Text(money(e.amount),
                        style: const TextStyle(fontSize: 15, height: 1.1, fontWeight: FontWeight.w800, color: C.text, fontFeatures: tabular)),
                  ]),
                ),
              ),
            ],
            Container(height: 3, color: C.field),
            Container(
              key: totalKey,
              color: C.soft,
              padding: const EdgeInsets.fromLTRB(15, 16, 16, 16),
              child: Row(children: [
                const Expanded(
                  child: Text('Jumla ya gharama',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.text)),
                ),
                Text(money(total),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.text, fontFeatures: tabular)),
              ]),
            ),
          ]),
        ),
      );
}

/// Kitufe cha ikoni (Historia, +, Pakua, Shiriki, Hifadhi)
class _IconBtn extends StatelessWidget {
  final String? svg;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool filled;
  final bool round;
  const _IconBtn({this.svg, this.icon, this.onTap, this.filled = false, this.round = false});

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : C.text2;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(round ? 17 : 9),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: filled ? C.blue : Colors.white,
          shape: round ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: round ? null : BorderRadius.circular(9),
          border: Border.all(color: filled ? C.blue : C.cardLine),
        ),
        child: Center(
          child: svg != null
              ? AppIcon(svg!, size: 17, color: fg)
              : Icon(icon, size: 20, color: fg),
        ),
      ),
    );
  }
}

class _NextBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _NextBtn({this.label = 'Next', this.onTap});

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
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
          ]),
        ),
      ),
    );
  }
}

/// Kisanduku cha dirisha: urefu 38, radius 7, mpaka #D1D5DB (bluu 1.5 ukiwa umegusa)
class _WinField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focus;
  final String hint;
  final bool number;
  final bool readOnly;
  final TextAlign align;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  const _WinField({
    required this.controller,
    this.focus,
    this.hint = '',
    this.number = false,
    this.readOnly = false,
    this.align = TextAlign.left,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: c, width: w));
    return SizedBox(
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
          enabledBorder: b(C.field, 1),
          focusedBorder: b(C.blue, 1.5),
          border: b(C.field, 1),
        ),
      ),
    );
  }
}
