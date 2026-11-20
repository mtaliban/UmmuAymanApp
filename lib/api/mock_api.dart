import 'dart:math';

import '../models/models.dart';
import '../utils/format.dart';
import 'api.dart';

/// DATA ZA MFANO — app inafanya kazi yote bila server (kUseMock = true).
/// Hesabu zote zinapigwa hapa kama server itakavyozipiga (angalia API-FASTAPI-MONGODB.md).
/// PIN ya mfano: 1234
class MockApi extends Api {
  bool _logged = false;
  String _pin = '1234';
  int _seq = 100;
  int _receiptNo = 2;

  final List<Product> _products = [];
  final List<Receipt> _receipts = [];
  final Map<String, _Day> _daily = {};

  MockApi() {
    _seed();
  }

  // ------------------------------------------------------------------ seed
  void _p(String name, List<List<Object>> v, {bool types = true}) {
    final pid = 'p${_seq++}';
    _products.add(Product(
      id: pid,
      name: name,
      hasTypes: types,
      variants: v
          .map((x) => Variant(id: 'v${_seq++}', productId: pid, productName: name, name: x[0] as String, qty: x[1] as int, buying: x[2] as int, selling: x[3] as int))
          .toList(),
    ));
  }

  void _seed() {
    _p('Kanzu', [
      ['Alfurqan Kanzu', 8, 50000, 65000],
      ['Kanzu ya Oman', 6, 30000, 40000],
      ['Kanzu ya Saudia', 10, 10000, 15000],
      ['Kanzu watoto', 12, 8000, 12000],
    ]);
    _p('Abaya', [
      ['Abaya ya Kituruki', 16, 5000, 8000],
      ['Abaya nyeusi', 5, 7000, 11000],
      ['Abaya ya harusi', 3, 40000, 60000],
      ['Abaya Dubai', 8, 25000, 38000],
    ]);
    _p('Kofia', [
      ['Kofia nyeupe', 8, 20000, 25000],
      ['Kofia nyeusi', 6, 15000, 22000],
      ['Kofia ya bao', 5, 6000, 10000],
    ]);
    _p('Viatu', [
      ['Viatu vya kufunga', 7, 25000, 35000],
      ['Viatu vya ngozi', 4, 35000, 50000],
      ['Raba', 9, 18000, 26000],
    ]);
    _p('Hijab', [
      ['Hijab za chiffon', 12, 4000, 7000],
      ['Hijab za jezi', 9, 3500, 6000],
    ]);
    _p('Mikoba', [
      ['Mkoba wa ngozi', 3, 30000, 45000],
      ['Mkoba mdogo', 4, 10000, 16000],
    ]);
    _p('Udi', [
      ['Udi', 6, 15000, 25000]
    ], types: false);
    _p('Tasbihi', [
      ['Tasbihi', 12, 2000, 4000]
    ], types: false);

    // risiti mbili za leo (mchana)
    final now = DateTime.now();
    _makeReceipt('Abuu Firdaus', '0754 112 233', [_ri('Alfurqan Kanzu', 2, 65000), _ri('Kofia nyeupe', 1, 25000)], DateTime(now.year, now.month, now.day, 11, 40));
    _makeReceipt('Mwanaisha Juma', '0715 220 330', [_ri('Abaya ya Kituruki', 2, 8000)], DateTime(now.year, now.month, now.day, 14, 5));
  }

  Variant _vByName(String n) => _allVariants.firstWhere((v) => v.name == n);

  /// Namba ya risiti -> id yake
  String? _rid(String? no) {
    for (final r in _receipts) {
      if (r.number == no) return r.id;
    }
    return null;
  }
  Variant _v(String id) => _allVariants.firstWhere((v) => v.id == id, orElse: () => throw ApiException('Bidhaa haipo', 404));
  List<Variant> get _allVariants => _products.expand((p) => p.variants).toList();
  Product _prod(String id) => _products.firstWhere((p) => p.id == id, orElse: () => throw ApiException('Bidhaa haipo', 404));

  ReceiptItem _ri(String name, int qty, int price, [int disc = 0]) {
    final v = _vByName(name);
    return ReceiptItem(variantId: v.id, name: v.name, qty: qty, price: price, discount: disc, buying: v.buying);
  }

  Receipt _makeReceipt(String name, String phone, List<ReceiptItem> items, DateTime at) {
    for (final it in items) {
      final v = _v(it.variantId);
      if (v.qty < it.qty) throw ApiException('${v.name}: zipo ${v.qty} tu');
    }
    for (final it in items) {
      _v(it.variantId).qty -= it.qty;
    }
    _receiptNo++;
    final r = Receipt(id: 'r$_receiptNo', number: _receiptNo.toString().padLeft(4, '0'), createdAt: at, customerName: name, customerPhone: phone, items: items);
    _receipts.add(r);
    return r;
  }

  Future<T> _d<T>(T v) => Future.delayed(const Duration(milliseconds: 220), () => v);
  bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  DateTime get _today => dayOnly(DateTime.now());

  // ------------------------------------------------------------------ auth
  @override
  Future<bool> hasSession() async => _logged;

  @override
  Future<void> loginPin(String pin) async {
    await Future.delayed(const Duration(milliseconds: 650));
    if (pin != _pin) throw ApiException('PIN si sahihi', 401);
    _logged = true;
  }

  @override
  Future<void> logout() async {
    _logged = false;
  }

  @override
  Future<void> changePin(String oldPin, String newPin) async {
    if (oldPin != _pin) throw ApiException('PIN ya zamani si sahihi', 400);
    _pin = newPin;
  }

  @override
  Future<Shop> shop() => _d(Shop(name: 'UMMU AYMAN OUTFITS', phone: '0621 340 044', email: 'kambilatifah@gmail.com'));

  @override
  Future<void> registerDevice(String fcmToken, String platform) async {}

  // ------------------------------------------------------------------ siku moja (live)
  List<SaleLine> _receiptLines(DateTime date) => _receipts
      .where((r) => _same(r.createdAt, date))
      .expand((r) => r.items.map((it) => SaleLine(
            variantId: it.variantId,
            name: it.name,
            qty: it.qty,
            selling: it.price - it.discount,
            buying: it.buying,
            receiptNo: r.number,
          )))
      .toList();

  List<SaleLine> _allLines(DateTime date) {
    if (_same(date, _today)) return [..._receiptLines(date), ...(_daily[iso(date)]?.lines ?? [])];
    if (date.isAfter(_today)) return [];
    return _history(date).lines;
  }

  int _expenses(DateTime date) {
    if (_same(date, _today)) return (_daily[iso(date)]?.expenses ?? []).fold(0, (a, e) => a + e.amount);
    if (date.isAfter(_today)) return 0;
    return _history(date).exp;
  }

  Summary _summary(DateTime date) {
    final l = _allLines(date);
    return Summary(sales: l.fold(0, (a, x) => a + x.sales), capital: l.fold(0, (a, x) => a + x.capital), expenses: _expenses(date));
  }

  /// historia ya mfano kwa siku zilizopita (inajirudia sawa kila mara)
  final Map<String, _Hist> _hcache = {};
  _Hist _history(DateTime date) {
    final k = iso(date);
    return _hcache.putIfAbsent(k, () {
      final rnd = Random(date.year * 1000 + date.month * 40 + date.day);
      final vs = _allVariants;
      final n = 3 + rnd.nextInt(4);
      final lines = <SaleLine>[];
      final used = <int>{};
      for (var i = 0; i < n; i++) {
        final idx = rnd.nextInt(vs.length);
        if (!used.add(idx)) continue;
        final v = vs[idx];
        final q = 1 + rnd.nextInt(v.selling < 15000 ? 6 : 3);
        lines.add(SaleLine(variantId: v.id, name: v.name, qty: q, selling: v.selling, buying: v.buying));
      }
      return _Hist(lines, 1000 * (2 + rnd.nextInt(5)));
    });
  }

  // ------------------------------------------------------------------ nyumbani
  @override
  Future<HomeData?> lastHome() async => null;

  @override
  Future<HomeData> home() {
    // siku ya mwisho iliyoandikwa kitu (bidhaa, risiti au gharama)
    var day = _today;
    var found = _allLines(day).isNotEmpty || _expenses(day) > 0;
    for (var i = 1; i <= 60 && !found; i++) {
      day = _today.subtract(Duration(days: i));
      found = _allLines(day).isNotEmpty || _expenses(day) > 0;
    }
    if (!found) return _d(HomeData.empty());

    final acc = <String, List<int>>{}; // jina -> [idadi, mauzo, mtaji, faida]
    for (final l in _allLines(day)) {
      final a = acc.putIfAbsent(l.name, () => [0, 0, 0, 0]);
      a[0] += l.qty;
      a[1] += l.sales;
      a[2] += l.capital;
      a[3] += l.profit;
    }
    final top = [
      for (final e in acc.entries)
        TopItem(
          name: e.key,
          qty: e.value[0],
          selling: e.value[0] == 0 ? 0 : e.value[1] ~/ e.value[0],
          sales: e.value[1],
          capital: e.value[2],
          profit: e.value[3],
        ),
    ]..sort((a, b) => b.profit.compareTo(a.profit));

    return _d(HomeData(day: day, summary: _summary(day), top: top, expenses: _daily[iso(day)]?.expenses ?? <Expense>[]));
  }

  // ------------------------------------------------------------------ stock
  @override
  Future<List<Product>> products() => _d(_products.map((p) => Product(id: p.id, name: p.name, hasTypes: p.hasTypes, variants: p.variants.map((v) => v.copy()).toList())).toList());

  @override
  Future<Product> createProduct({required String name, required bool hasTypes, int qty = 0, int buying = 0, int selling = 0}) async {
    if (name.trim().isEmpty) throw ApiException('Andika jina la bidhaa');
    if (_products.any((p) => p.name.toLowerCase() == name.trim().toLowerCase())) throw ApiException('Bidhaa "$name" ipo tayari');
    final pid = 'p${_seq++}';
    final p = Product(id: pid, name: name.trim(), hasTypes: hasTypes, variants: []);
    if (!hasTypes) {
      p.variants.add(Variant(id: 'v${_seq++}', productId: pid, productName: p.name, name: p.name, qty: qty, buying: buying, selling: selling));
    }
    _products.add(p);
    return _d(p);
  }

  @override
  Future<void> renameProduct(String id, String name) async {
    final p = _prod(id);
    p.name = name;
    if (!p.hasTypes && p.variants.isNotEmpty) p.variants.first.name = name;
  }

  @override
  Future<void> deleteProduct(String id) async {
    _products.removeWhere((p) => p.id == id);
  }

  @override
  Future<Variant> addVariant(String productId, {required String name, required int qty, required int buying, required int selling}) async {
    final p = _prod(productId);
    if (name.trim().isEmpty) throw ApiException('Andika jina la aina');
    if (!p.hasTypes) {
      // bidhaa ilikuwa haina aina -> sasa inapata aina. Ile ya zamani inakuwa aina ya kwanza.
      p.hasTypes = true;
    }
    final v = Variant(id: 'v${_seq++}', productId: p.id, productName: p.name, name: name.trim(), qty: qty, buying: buying, selling: selling);
    p.variants.add(v);
    return _d(v);
  }

  @override
  Future<Variant> updateVariant(String id, {int addQty = 0, int? buying, int? selling, String? name}) async {
    final v = _v(id);
    v.qty += addQty;
    if (buying != null) v.buying = buying;
    if (selling != null) v.selling = selling;
    if (name != null && name.trim().isNotEmpty) v.name = name.trim();
    return _d(v.copy());
  }

  @override
  Future<void> deleteVariant(String id) async {
    for (final p in _products) {
      p.variants.removeWhere((v) => v.id == id);
    }
    _products.removeWhere((p) => p.variants.isEmpty && !p.hasTypes);
  }

  // ------------------------------------------------------------------ mauzo (S0–S8)
  DailySheet _sheet(String date) {
    final dt = DateTime.tryParse(date) ?? _today;
    final key = iso(dt);
    final d = _daily[key];
    final rl = _receiptLines(dt)
        .toList()
        .indexed
        .map((x) => SaleLine(
              id: 'rc_${x.$1}',
              variantId: x.$2.variantId,
              name: x.$2.name,
              qty: x.$2.qty,
              selling: x.$2.selling,
              buying: x.$2.buying,
              receiptNo: x.$2.receiptNo,
              receiptId: _rid(x.$2.receiptNo),
            ))
        .toList();
    final lines = (d?.lines ?? <SaleLine>[])
        .toList()
        .indexed
        .map((x) => SaleLine(
              id: 'l_${key}_${x.$1}',
              variantId: x.$2.variantId,
              name: x.$2.name,
              qty: x.$2.qty,
              selling: x.$2.selling,
              buying: x.$2.buying,
              stockSelling: x.$2.stockSelling,
            ))
        .toList();
    final exps = (d?.expenses ?? <Expense>[])
        .toList()
        .indexed
        .map((x) => Expense(id: 'e_${key}_${x.$1}', name: x.$2.name, amount: x.$2.amount, extra: x.$2.extra))
        .toList();
    return DailySheet(date: dt, receiptLines: rl, lines: lines, expenses: exps, savedAt: d?.savedAt);
  }

  @override
  Future<DailySheet> daily(DateTime date) => _d(_sheet(iso(date)));

  @override
  Future<DailySheet> daySheet(String date) => _d(_sheet(date));

  @override
  Future<List<Variant>> searchList() =>
      _d(_allVariants.map((v) => v.copy()).toList()..sort((a, b) => a.name.compareTo(b.name)));

  _Day _editable(String date) {
    final dt = DateTime.tryParse(date) ?? _today;
    if (dt.isAfter(_today)) throw ApiException('Huwezi kuandika siku ijayo', 400);
    final d = _daily.putIfAbsent(iso(dt), () => _Day([], [], null));
    if (d.savedAt != null) throw ApiException('Siku imehifadhiwa — bonyeza Hariri kwanza', 409);
    return d;
  }

  int _idx(String id) => int.tryParse(id.split('_').last) ?? -1;

  @override
  Future<DailySheet> addLine(String date, {String? variantId, required String name, required int qty, required int selling, int? buying}) async {
    final d = _editable(date);
    var nm = name.trim();
    var by = buying ?? 0;
    if (variantId != null) {
      final v = _v(variantId);
      nm = v.name;
      by = v.buying;
      // Stock inapungua lakini haishuki chini ya 0 — haizuii mauzo.
      v.qty -= min(qty, max(0, v.qty));
    } else if (nm.isEmpty) {
      throw ApiException('Jaza jina la bidhaa', 422);
    }
    d.lines.add(SaleLine(variantId: variantId ?? '', name: nm, qty: qty, selling: selling, buying: by, stockSelling: selling));
    return daySheet(date);
  }

  @override
  Future<DailySheet> updateLine(String date, String id, {int? qty, int? selling, int? buying}) async {
    final d = _editable(date);
    final i = _idx(id);
    if (i < 0 || i >= d.lines.length) throw ApiException('Haipo', 404);
    final l = d.lines[i];
    d.lines[i] = SaleLine(
      variantId: l.variantId,
      name: l.name,
      qty: qty ?? l.qty,
      selling: selling ?? l.selling,
      buying: (!l.fromStock && buying != null) ? buying : l.buying,
      stockSelling: l.stockSelling,
    );
    return daySheet(date);
  }

  @override
  Future<DailySheet> addExpense(String date, String name, int amount) async {
    final d = _editable(date);
    if (name.trim().isEmpty) throw ApiException('Jaza jina la gharama', 422);
    d.expenses.add(Expense(name: name.trim(), amount: amount));
    return daySheet(date);
  }

  @override
  Future<DailySheet> updateExpense(String date, String id, {String? name, int? amount}) async {
    final d = _editable(date);
    final i = _idx(id);
    if (i < 0 || i >= d.expenses.length) throw ApiException('Haipo', 404);
    final e = d.expenses[i];
    d.expenses[i] = Expense(name: (name ?? e.name).trim(), amount: amount ?? e.amount, extra: e.extra);
    return daySheet(date);
  }

  @override
  Future<DailySheet> closeDay(String date) async {
    final dt = DateTime.tryParse(date) ?? _today;
    final d = _daily.putIfAbsent(iso(dt), () => _Day([], [], null));
    d.savedAt = DateTime.now();
    return daySheet(date);
  }

  @override
  Future<DailySheet> reopenDay(String date) async {
    final dt = DateTime.tryParse(date) ?? _today;
    final d = _daily.putIfAbsent(iso(dt), () => _Day([], [], null));
    d.savedAt = null;
    return daySheet(date);
  }

  @override
  Future<History> history({String? before}) async {
    final end = before == null ? _today : (DateTime.tryParse(before) ?? _today);
    final days = <DateTime>[];
    for (var i = 1; i <= 40; i++) {
      final d = end.subtract(Duration(days: i));
      final key = iso(d);
      final has = (_daily[key]?.lines.isNotEmpty ?? false) ||
          (_daily[key]?.expenses.isNotEmpty ?? false) ||
          _receiptLines(d).isNotEmpty ||
          _history(d).lines.isNotEmpty;
      if (has) days.add(d);
    }
    final months = <HistoryMonth>[];
    for (final d in days) {
      final label = '${monthsSw[d.month - 1].toUpperCase()} ${d.year}';
      final s = _summary(d);
      final day = HistoryDay(
        date: iso(d),
        label: '${daysSw[d.weekday - 1]}, ${d.day} ${monthsShort[d.month - 1]}',
        sales: s.sales,
        items: _allLines(d).fold(0, (a, l) => a + l.qty),
        net: s.net,
      );
      if (months.isNotEmpty && months.last.label == label) {
        months.last.days.add(day);
      } else {
        months.add(HistoryMonth(label: label, days: [day]));
      }
    }
    return _d(History(months: months, nextBefore: days.length >= 40 ? iso(days.last.subtract(const Duration(days: 1))) : null));
  }

  @override
  Future<List<String>> expenseNames() => _d(['Usafirishaji', 'Bando', 'Chakula', 'Umeme', 'Kodi ya fremu', 'Mfuko']);

  // ------------------------------------------------------------------ risiti
  @override
  Future<List<Receipt>> receipts(DateTime date) {
    final l = _receipts.where((r) => _same(r.createdAt, date)).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _d(l);
  }

  @override
  Future<Receipt> createReceipt({required String name, required String phone, required List<ReceiptItem> items}) async {
    if (name.trim().isEmpty) throw ApiException('Andika jina la mteja');
    if (items.isEmpty) throw ApiException('Ongeza bidhaa');
    final fixed = items.map((it) => ReceiptItem(variantId: it.variantId, name: it.name, qty: it.qty, price: it.price, discount: it.discount, buying: _v(it.variantId).buying)).toList();
    return _d(_makeReceipt(name.trim(), phone.trim(), fixed, DateTime.now()));
  }

  @override
  Future<Receipt> receipt(String id) => _d(_receipts.firstWhere((r) => r.id == id));

  @override
  Future<void> cancelReceipt(String id) async {
    final r = _receipts.firstWhere((r) => r.id == id);
    for (final it in r.items) {
      _v(it.variantId).qty += it.qty;
    }
    _receipts.remove(r);
  }

  // ------------------------------------------------------------------ ripoti (P1 – P4)
  @override
  Future<Report> report(String period, DateTime date) {
    final d = dayOnly(date);
    return _d(switch (period) {
      'day' => _dayReport(d),
      'week' => _periodReport('week', d),
      'month' => _periodReport('month', d),
      'year' => _periodReport('year', d),
      _ => throw ApiException('Kipindi si sahihi'),
    });
  }

  /// Jumapili = mwanzo wa wiki
  DateTime _weekStart(DateTime d) => d.subtract(Duration(days: d.weekday % 7));

  List<SaleLine> _linesRange(DateTime a, DateTime b) {
    final out = <SaleLine>[];
    final end = b.isAfter(_today) ? _today : b;
    for (var d = a; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      out.addAll(_allLines(d));
    }
    return out;
  }

  Summary _sumRange(DateTime a, DateTime b) {
    final end = b.isAfter(_today) ? _today : b;
    var sales = 0, cap = 0, exp = 0;
    for (var d = a; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final s = _summary(d);
      sales += s.sales;
      cap += s.capital;
      exp += s.expenses;
    }
    return Summary(sales: sales, capital: cap, expenses: exp);
  }

  bool _hasDataBefore(DateTime d) {
    for (var i = 1; i <= 60; i++) {
      final x = d.subtract(Duration(days: i));
      if (_allLines(x).isNotEmpty || _expenses(x) > 0) return true;
    }
    return false;
  }

  List<RProduct> _byName(List<SaleLine> lines) {
    final agg = <String, (int, int, int)>{};
    for (final l in lines) {
      final p = agg[l.name] ?? (0, 0, 0);
      agg[l.name] = (p.$1 + l.qty, p.$2 + l.sales, p.$3 + l.profit);
    }
    return agg.entries.map((e) => RProduct(name: e.key, qty: e.value.$1, sales: e.value.$2, profit: e.value.$3)).toList()
      ..sort((a, b) => b.qty != a.qty ? b.qty.compareTo(a.qty) : b.sales.compareTo(a.sales));
  }

  List<RUnsold> _unsoldList(List<SaleLine> lines) {
    final ids = lines.map((l) => l.variantId).where((x) => x.isNotEmpty).toSet();
    final names = lines.map((l) => l.name.toLowerCase()).toSet();
    final out = <RUnsold>[];
    for (final v in _allVariants) {
      if (ids.contains(v.id) || names.contains(v.name.toLowerCase()) || v.qty <= 0) continue;
      out.add(RUnsold(name: v.name, qty: v.qty, capital: v.qty * v.buying));
    }
    return out..sort((a, b) => b.capital.compareTo(a.capital));
  }

  Report _dayReport(DateTime d) {
    final lines = _allLines(d);
    final products = _byName(lines);
    return Report(
      period: 'day',
      date: iso(d),
      label: '${daysSw[d.weekday - 1]}, ${d.day} ${monthsShort[d.month - 1]} ${d.year}',
      shortLabel: '${daysSw[d.weekday - 1]}, ${d.day} ${monthsShort[d.month - 1]}',
      hasPrev: _hasDataBefore(d),
      hasNext: d.isBefore(_today),
      summary: _summary(d),
      products: products,
      top: const [],
      low: const [],
      unsold: const [],
      bars: const [],
      totalQty: products.fold(0, (a, p) => a + p.qty),
    );
  }

  Report _periodReport(String period, DateTime d) {
    late DateTime a, b;
    late String label, short;
    final chunks = <(DateTime, String, DateTime, DateTime)>[];

    if (period == 'week') {
      a = _weekStart(d);
      b = a.add(const Duration(days: 6));
      for (var i = 0; i < 7; i++) {
        final x = a.add(Duration(days: i));
        chunks.add((x, daysShort[x.weekday - 1], x, x));
      }
      label = a.month == b.month
          ? '${a.day} – ${b.day} ${monthsSw[b.month - 1]} ${b.year}'
          : '${a.day} ${monthsShort[a.month - 1]} – ${b.day} ${monthsShort[b.month - 1]} ${b.year}';
      short = '${a.day} – ${b.day} ${monthsShort[b.month - 1]} ${b.year}';
    } else if (period == 'month') {
      a = DateTime(d.year, d.month, 1);
      b = DateTime(d.year, d.month + 1, 0);
      var x = a;
      while (!x.isAfter(b)) {
        var y = _weekStart(x).add(const Duration(days: 6));
        if (y.isAfter(b)) y = b;
        chunks.add((x, x.day == y.day ? '${x.day}' : '${x.day}–${y.day}', x, y));
        x = y.add(const Duration(days: 1));
      }
      label = '${monthsSw[a.month - 1]} ${a.year}';
      short = label;
    } else {
      a = DateTime(d.year, 1, 1);
      b = DateTime(d.year, 12, 31);
      for (var m = 1; m <= 12; m++) {
        chunks.add((DateTime(d.year, m, 1), monthsShort[m - 1], DateTime(d.year, m, 1), DateTime(d.year, m + 1, 0)));
      }
      label = '${d.year}';
      short = '${d.year}';
    }

    final bars = <RBar>[];
    for (final (key, lab, s0, e0) in chunks) {
      if (s0.isAfter(_today)) {
        bars.add(RBar(key: iso(key), label: lab));
      } else {
        bars.add(RBar(key: iso(key), label: lab, net: _sumRange(s0, e0).net));
      }
    }

    final lines = _linesRange(a, b);
    final products = _byName(lines);
    final top = products.take(5).toList();
    final rest = products.where((p) => !top.contains(p)).toList()
      ..sort((x, y) => x.qty != y.qty ? x.qty.compareTo(y.qty) : x.sales.compareTo(y.sales));

    return Report(
      period: period,
      start: iso(a),
      end: iso(b),
      label: label,
      shortLabel: short,
      hasPrev: _hasDataBefore(a),
      hasNext: b.isBefore(_today),
      summary: _sumRange(a, b),
      products: const [],
      top: top,
      low: rest.take(3).toList(),
      unsold: _unsoldList(lines).take(20).toList(),
      bars: bars,
      totalQty: 0,
    );
  }
}

class _Day {
  final List<SaleLine> lines;
  final List<Expense> expenses;
  DateTime? savedAt;
  _Day(this.lines, this.expenses, this.savedAt);
}

class _Hist {
  final List<SaleLine> lines;
  final int exp;
  _Hist(this.lines, this.exp);
}
