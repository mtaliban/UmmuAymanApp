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
import '../widgets/table.dart';
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
  void _openAdd(_Tab tab) {
    if (_saved) return;
    setState(() {
      _open = true;
      _tab = tab;
      _editLine = null;
      _editExp = null;
      _sel = null;
      _error = null;
    });
    _focusSoon(tab == _Tab.gharama ? _eF : _qF);
    _keepAbove(target: tab == _Tab.gharama ? _expKey : null);
  }

  /// Kitufe cha +: fomu inafunguka moja kwa moja kwenye tabo ya Bidhaa.
  void _addProduct() => _openAdd(_Tab.bidhaa);

  /// Tabo za fomu: kubonyeza neno “Gharama” kunabadilisha fomu ya gharama.
  void _switchTab(_Tab tab) {
    if (_tab == tab || _busy) return;
    setState(() {
      _tab = tab;
      _error = null;
      _editLine = null;
      _editExp = null;
      _sel = null;
      _q.clear();
      _qty.clear();
      _price.clear();
      _buy.clear();
      _eName.clear();
      _eAmt.clear();
    });
    _focusSoon(tab == _Tab.gharama ? _eF : _qF);
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
        light: _isToday,
        // Historia / siku ya historia: kurudi kando ya jina, kila kitu kimeshuka.
        flatBack: !_isToday,
        // Siku ya historia imehifadhiwa: hakuna vitufe kichwani, kama kwenye muundo.
        action: !_isToday
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: [
                _IconBtn(svg: AppIcons.history, onTap: _openHistory),
                const SizedBox(width: 8),
                if (_saved)
                  SmallButton('Hariri', color: C.text2, borderColor: C.faint, height: 34, onTap: _busy ? null : _reopen)
                else
                  _IconBtn(icon: Icons.add_rounded, filled: true, onTap: _busy ? null : _addProduct),
              ]),
      ),
      bottomNavigationBar: _isToday ? null : const AppNav(index: 1),
      body: _loading
          ? const SizedBox.expand()
          : _loadError != null
              ? ErrorView(_loadError!, onRetry: _load)
              : Stack(children: [
                  if (!_hasLines && !_hasExp && !_open)
                    Center(child: _NoSales(_isToday))
                  else
                    ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                      children: [
                        ..._cards(d!),
                        if (_hasLines) _SumCard(key: _totKey, qty: d.qty, sales: d.totals.sales, profit: d.totals.productProfit),
                        // Gharama zilizoandikwa: jedwali lile lile la Nyumbani —
                        // mstari ukigusa unafungua fomu ya kuirekebisha.
                        if (_hasExp)
                          Padding(
                            padding: const EdgeInsets.only(top: 22),
                            child: ExpenseTable(
                              rows: d.expenses,
                              total: d.totals.expenses,
                              totalKey: _expKey,
                              highlight: {_newExpId, _editExp?.id},
                              onTap: _filled ? _openEditExp : null,
                            ),
                          ),
                        if (!_open && (_hasLines || _hasExp)) ...[
                          SectionTitle(_isToday ? 'Hesabu ya leo' : 'Hesabu ya siku'),
                          _StatementCard(
                            sales: d.totals.sales,
                            capital: d.totals.capital,
                            expenses: d.totals.expenses,
                            netLabel: _isToday ? 'Faida halisi ya leo' : 'Faida halisi',
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_open) const SizedBox(height: 420),
                      ],
                    ),
                  if (!_open && (_hasLines || _hasExp)) _actions(),
                  if (_open) _window(),
                ]),
    );
  }

  /// Upau wa vitendo: unakaa juu ya menyu ya chini, upande wa kulia.
  /// Siku ya historia: Pakua na Shiriki tu (hakuna Hifadhi).
  Widget _actions() => Positioned(
        right: 16,
        bottom: 12,
        child: Row(children: [
          _IconBtn(svg: AppIcons.download, size: 40, onTap: _pdfBusy ? null : () => _pdf(downloadDayPdf)),
          const SizedBox(width: 8),
          _IconBtn(svg: AppIcons.share2, size: 40, onTap: _pdfBusy ? null : () => _pdf(shareDayPdf)),
          if (_isToday && !_saved) ...[
            const SizedBox(width: 8),
            _IconBtn(svg: AppIcons.save, size: 40, filled: true, onTap: _busy ? null : _closeDay),
          ],
        ]),
      );

  // ------------------------------------------------------------ dirisha (M02–M11)
  Widget _window() {
    final editing = _editLine != null || _editExp != null;
    final expMode = _editExp != null || (!editing && _tab == _Tab.gharama);
    // + inafungua fomu moja kwa moja; ndani yake kuna tabo mbili — Bidhaa na
    // Gharama — hivyo gharama inafikiwa kwa kubonyeza neno lake.
    final Widget header = editing
        ? const Text('Rekebisha', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))
        : Row(children: [
            _tabWord('Bidhaa', _Tab.bidhaa),
            const SizedBox(width: 18),
            _tabWord('Gharama', _Tab.gharama),
          ]);

    // Scaffold yenyewe inapunguza ukurasa kwa urefu wa keyboard, hivyo
    // "bottom: 10" inatosha: fomu inakaa chini juu ya keyboard, sehemu zake
    // zote zinaonekana, na orodha iliyopo nyuma inasogea chini.
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      left: 12,
      right: 12,
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
            Expanded(child: header),
            _closeX(),
          ]),
          const SizedBox(height: 12),
          if (expMode) ...[
            // Jina la gharama peke yake mstari wa kwanza; Kiasi na Next mstari wa pili.
            _labelled(
              'Jina la gharama',
              _WinField(controller: _eName, focus: _eF, onChanged: (_) => setState(() {}), onSubmitted: (_) => _next()),
            ),
            const SizedBox(height: 10),
            _labelled(
              'Kiasi',
              _WinField(
                controller: _eAmt,
                focus: _eAmtF,
                number: true,
                align: TextAlign.center,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _next(),
              ),
            ),
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

  /// Neno la tabo ndani ya fomu (aktiv = bluu na mstari chini yake).
  Widget _tabWord(String label, _Tab tab) {
    final on = _tab == tab;
    return InkWell(
      onTap: _busy ? null : () => _switchTab(tab),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 1, 2, 3),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? C.blue : C.muted,
              )),
          const SizedBox(height: 3),
          Container(height: 2, width: 30, color: on ? C.blue : Colors.transparent),
        ]),
      ),
    );
  }

  Widget _bidhaaForm(bool editing) {
    final stock = _sel ?? _stockOf(_editLine);
    // Namba zilizoandikwa zisionekane tu kama zimefutwa: fields zikae wazi
    // mara tu mmoja wao akiwa na maandishi (hata jina likigonga bidhaa ya stock).
    final showFields = _sel != null ||
        _newName ||
        _editLine != null ||
        _qty.text.isNotEmpty ||
        _price.text.isNotEmpty ||
        _buy.text.isNotEmpty;
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
          // Orodha isizidi safu 3 — isisukume fields na Next chini ya dirisha.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 123),
            child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
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
        ),
      if (showFields) ...[
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            // Idadi ni namba ndogo; Selling/Buying zipate nafasi zaidi.
            flex: showBuying ? 2 : 3,
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
                align: TextAlign.center,
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
                _WinField(controller: _buy, number: true, align: TextAlign.center, onChanged: (_) => setState(() {})),
              ),
            ),
          ],
        ]),
        _nextRow(editing),
      ] else
        _nextRow(editing),
    ]);
  }

  /// Next/Hifadhi chini ya fields, upana wote wa dirisha.
  Widget _nextRow(bool editing) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: _NextBtn(label: editing ? 'Hifadhi' : 'Next', wide: true, onTap: _canNext ? _next : null),
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

  Widget _closeX() => InkWell(
        onTap: _close,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.line)),
          child: const Icon(Icons.close_rounded, size: 16, color: C.text),
        ),
      );
}

// ======================================================================= vipande

/// M01 — hakuna mauzo leo
class _NoSales extends StatelessWidget {
  final bool today;
  const _NoSales(this.today);
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: C.blue2, shape: BoxShape.circle),
          child: const Center(child: AppIcon(AppIcons.pencil, size: 28, color: C.text)),
        ),
        const SizedBox(height: 16),
        Text(today ? 'Hakuna mauzo leo' : 'Hakuna mauzo', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Box(
        radius: 12,
        onTap: onTap,
        color: highlight ? C.blue3 : bg,
        border: highlight ? C.blue : C.cardLine,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (rank != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(6)),
                  child: Text('$rank', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: C.text2, fontFeatures: tabular)),
                ),
              ),
            Expanded(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            if (tag != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: C.blue2, borderRadius: BorderRadius.circular(6)),
                child: Text(tag!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: C.blue)),
              ),
          ]),
          const SizedBox(height: 9),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < cols.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cols[i].$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: .4, color: C.muted)),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      cols[i].$2,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
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

/// Muhtasari: kadi moja yenye seli tatu sawa IDADI · MAUZO · FAIDA
class _SumCard extends StatelessWidget {
  final int qty, sales, profit;
  const _SumCard({super.key, required this.qty, required this.sales, required this.profit});

  @override
  Widget build(BuildContext context) {
    final cells = [('IDADI', '$qty', false), ('MAUZO', money(sales), false), ('FAIDA', money(profit), true)];
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.cardLine)),
      child: Row(children: [
        for (final (i, c) in cells.indexed)
          Expanded(
            child: Container(
              padding: EdgeInsets.fromLTRB(i == 0 ? 14 : 12, 12, 12, 12),
              decoration: BoxDecoration(border: i == 0 ? null : const Border(left: BorderSide(color: C.line))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: .4, color: C.muted)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(c.$2,
                      maxLines: 1,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: c.$3 ? C.blue : C.text, fontFeatures: tabular)),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// HESABU: kadi yenye mistari — Mauzo · Mtaji · Faida ya bidhaa · Gharama · Faida halisi
class _StatementCard extends StatelessWidget {
  final int sales, capital, expenses;
  final String netLabel;
  const _StatementCard({required this.sales, required this.capital, required this.expenses, required this.netLabel});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, int)>[
      ('Mauzo', sales),
      ('Mtaji wa vilivyouzwa', capital),
      ('Faida ya bidhaa', sales - capital),
      ('Gharama', expenses),
      (netLabel, sales - capital - expenses),
    ];
    final last = rows.length - 1;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.cardLine)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (final (i, r) in rows.indexed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: i == last ? C.blue3 : null,
              border: i == 0
                  ? null
                  : Border(top: BorderSide(color: i == 2 ? C.text : (i == last ? C.blueLine : C.line), width: i == 2 ? 1.5 : 1)),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  r.$1,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: i == last || i == 2 ? FontWeight.w500 : FontWeight.w400,
                    color: i == last ? C.blue : (i == 3 ? C.muted : C.text2),
                  ),
                ),
              ),
              Text(
                money(r.$2),
                style: TextStyle(
                  fontSize: i == last ? 18 : 14.5,
                  fontWeight: FontWeight.w500,
                  color: i == last ? C.blue : (i == 3 ? C.muted : C.text),
                  fontFeatures: tabular,
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

/// Kitufe cha ikoni — mara zote MRABA wenye pembe ndogo (Historia, +, Pakua,
/// Shiriki, Hifadhi). Hakuna vitufe vya duara.
class _IconBtn extends StatelessWidget {
  final String? svg;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool filled;
  final double size;
  const _IconBtn({this.svg, this.icon, this.onTap, this.filled = false, this.size = 38});

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : C.text2;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled ? C.blue : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: filled ? C.blue : C.cardLine),
        ),
        child: Center(
          child: svg != null
              ? AppIcon(svg!, size: size * .5, color: fg)
              : Icon(icon, size: size * .55, color: fg),
        ),
      ),
    );
  }
}


class _NextBtn extends StatelessWidget {
  final String label;
  final bool wide;
  final VoidCallback? onTap;
  const _NextBtn({this.label = 'Next', this.wide = false, this.onTap});

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
          width: wide ? double.infinity : null,
          padding: EdgeInsets.fromLTRB(wide ? 12 : 14, 0, wide ? 8 : 10, 0),
          decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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

  static const double _size = 14.5;

  /// Namba isiyotoshea kisanduku hupunguza fonti yake — hivyo namba yote
  /// inaonekana, badala ya mwanzo wake kufichwa na caret iliyo mwisho.
  double _fitNumber(BuildContext context, double maxWidth, String text) {
    if (text.isEmpty) return _size;
    // 8+8 padding, caret na nafasi ya mpaka — namba isigonge ukingo wa kulia.
    final avail = maxWidth - 30;
    if (avail <= 0) return _size;
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(fontSize: _size, fontWeight: FontWeight.w500, fontFeatures: tabular)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    if (tp.width <= avail) return _size;
    return (_size * avail / tp.width).clamp(10.0, _size);
  }

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: c, width: w));
    Widget box(double fontSize) => TextField(
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
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500, fontFeatures: tabular),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(color: C.faint, fontWeight: FontWeight.w400),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            suffixIcon: suffix == null ? null : Padding(padding: const EdgeInsets.only(right: 8), child: suffix),
            suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            enabledBorder: b(C.field, 1),
            focusedBorder: b(C.blue, 1.5),
            border: b(C.field, 1),
          ),
        );
    return SizedBox(
      height: 38,
      child: number
          ? LayoutBuilder(builder: (ctx, cons) => box(_fitNumber(ctx, cons.maxWidth, controller.text)))
          : box(_size),
    );
  }
}
