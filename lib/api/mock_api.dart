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

  // ------------------------------------------------------------------ ripoti
  @override
  Future<Report> report(Period period, DateTime anchor) async {
    final a = dayOnly(anchor);
    late DateTime start, end;
    late String label;
    final rows = <ReportRow>[];

    Summary sumRange(DateTime s, DateTime e) {
      var sales = 0, cap = 0, exp = 0;
      for (var d = s; !d.isAfter(e) && !d.isAfter(_today); d = d.add(const Duration(days: 1))) {
        final x = _summary(d);
        sales += x.sales;
        cap += x.capital;
        exp += x.expenses;
      }
      return Summary(sales: sales, capital: cap, expenses: exp);
    }

    if (period == Period.week) {
      start = a.subtract(Duration(days: a.weekday - 1)); // Jumatatu
      end = start.add(const Duration(days: 6));
      label = '${start.day} ${monthsShort[start.month - 1]} – ${end.day} ${monthsShort[end.month - 1]} ${end.year}';
      for (var d = start; !d.isAfter(end) && !d.isAfter(_today); d = d.add(const Duration(days: 1))) {
        rows.add(ReportRow(
          key: iso(d),
          label: daysSw[d.weekday - 1],
          sub: '${d.day} ${monthsShort[d.month - 1]}',
          short: daysShort[d.weekday - 1],
          best: '${daysSw[d.weekday - 1]} ${d.day}',
          s: _summary(d),
          current: _same(d, _today),
        ));
      }
    } else if (period == Period.month) {
      start = DateTime(a.year, a.month, 1);
      end = DateTime(a.year, a.month + 1, 0);
      label = '${monthsSw[a.month - 1]} ${a.year}';
      var w = 1;
      for (var s = start; !s.isAfter(end) && !s.isAfter(_today); s = s.add(const Duration(days: 7)), w++) {
        var e = s.add(const Duration(days: 6));
        if (e.isAfter(end)) e = end;
        final cur = !_today.isBefore(s) && !_today.isAfter(e);
        final last = cur ? _today : e;
        rows.add(ReportRow(key: iso(s), label: 'Wiki $w', sub: '${s.day} – ${last.day}', short: 'W$w', best: 'Wiki $w', s: sumRange(s, e), current: cur));
      }
    } else {
      start = DateTime(a.year, 1, 1);
      end = DateTime(a.year, 12, 31);
      label = '${a.year}';
      for (var m = 1; m <= 12; m++) {
        final s = DateTime(a.year, m, 1);
        if (s.isAfter(_today)) break;
        final e = DateTime(a.year, m + 1, 0);
        rows.add(ReportRow(key: '${a.year}-${m.toString().padLeft(2, '0')}', label: monthsSw[m - 1], sub: '', short: monthsShort[m - 1], best: monthsSw[m - 1], s: sumRange(s, e), current: s.year == _today.year && m == _today.month));
      }
    }

    // bidhaa za kipindi
    final agg = <String, List<int>>{}; // jina -> [qty, profit]
    final soldIds = <String>{};
    for (var d = start; !d.isAfter(end) && !d.isAfter(_today); d = d.add(const Duration(days: 1))) {
      for (final l in _allLines(d)) {
        final x = agg.putIfAbsent(l.name, () => [0, 0]);
        x[0] += l.qty;
        x[1] += l.profit;
        soldIds.add(l.variantId);
      }
    }
    final sorted = agg.entries.map((e) => NameQty(name: e.key, qty: e.value[0], profit: e.value[1])).toList()..sort((x, y) => y.qty.compareTo(x.qty));
    final top = sorted.take(3).toList();
    final low = sorted.length > 3 ? sorted.reversed.take(min(3, sorted.length - 3)).toList() : <NameQty>[];
    final unsold = _allVariants.where((v) => v.qty > 0 && !soldIds.contains(v.id)).map((v) => NameQty(name: v.name, qty: v.qty)).toList();

    final total = Summary(
      sales: rows.fold(0, (x, r) => x + r.s.sales),
      capital: rows.fold(0, (x, r) => x + r.s.capital),
      expenses: rows.fold(0, (x, r) => x + r.s.expenses),
    );
    return _d(Report(
      period: period,
      label: label,
      anchor: a,
      summary: total,
      rows: rows,
      top: top,
      low: low,
      unsold: unsold.take(5).toList(),
      capitalInShop: _products.fold(0, (x, p) => x + p.capital),
      purchases: (total.capital * 0.8).round(),
      hasNext: end.isBefore(_today),
    ));
  }

  @override
  Future<DayDetail> day(DateTime date) {
    final agg = <String, List<int>>{};
    for (final l in _allLines(date)) {
      final x = agg.putIfAbsent(l.name, () => [0, 0]);
      x[0] += l.qty;
      x[1] += l.profit;
    }
    final items = agg.entries.map((e) => NameQty(name: e.key, qty: e.value[0], profit: e.value[1])).toList()..sort((a, b) => b.profit.compareTo(a.profit));
    return _d(DayDetail(date: date, label: '${daysSw[date.weekday - 1]}, ${date.day} ${monthsShort[date.month - 1]}', items: items, summary: _summary(date)));
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
