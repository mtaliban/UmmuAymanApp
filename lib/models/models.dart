/// MODELS — majina ya fields yanalingana na API-FASTAPI-MONGODB.md (snake_case kwenye JSON).

int _i(dynamic v) => v == null ? 0 : (v is num ? v.round() : int.tryParse('$v') ?? 0);
String _s(dynamic v) => v == null ? '' : '$v';
List<T> _l<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    ((v ?? []) as List).map((e) => f(Map<String, dynamic>.from(e as Map))).toList();

class Shop {
  final String name, phone, email;
  Shop({required this.name, required this.phone, required this.email});
  factory Shop.fromJson(Map<String, dynamic> j) => Shop(name: _s(j['name']), phone: _s(j['phone']), email: _s(j['email']));
}

/// Aina ya bidhaa (mf. "Alfurqan Kanzu" ndani ya "Kanzu").
/// Bidhaa isiyo na aina ina aina MOJA yenye jina sawa na bidhaa.
class Variant {
  final String id;
  final String productId;
  final String productName;
  String name;
  int qty;
  int buying;
  int selling;
  final int soldToday; // Nyumbani tu
  final int profitToday; // Nyumbani tu

  Variant({
    required this.id,
    required this.productId,
    required this.productName,
    required this.name,
    required this.qty,
    required this.buying,
    required this.selling,
    this.soldToday = 0,
    this.profitToday = 0,
  });

  int get profitEach => selling - buying;
  int get capital => qty * buying;
  int get profitAll => qty * (selling - buying);

  factory Variant.fromJson(Map<String, dynamic> j) => Variant(
        id: _s(j['id']),
        productId: _s(j['product_id']),
        productName: _s(j['product_name']),
        name: _s(j['name']),
        qty: _i(j['qty']),
        buying: _i(j['buying']),
        selling: _i(j['selling']),
        soldToday: _i(j['sold_today']),
        profitToday: _i(j['profit_today']),
      );

  Variant copy() => Variant(id: id, productId: productId, productName: productName, name: name, qty: qty, buying: buying, selling: selling, soldToday: soldToday, profitToday: profitToday);
}

/// Bidhaa / kundi (mf. "Kanzu", au "Udi" isiyo na aina)
class Product {
  final String id;
  String name;
  bool hasTypes;
  List<Variant> variants;
  Product({required this.id, required this.name, required this.hasTypes, required this.variants});

  int get qty => variants.fold(0, (a, v) => a + v.qty);
  int get capital => variants.fold(0, (a, v) => a + v.capital);
  int get profitAll => variants.fold(0, (a, v) => a + v.profitAll);
  int get soldToday => variants.fold(0, (a, v) => a + v.soldToday);
  int get profitToday => variants.fold(0, (a, v) => a + v.profitToday);

  factory Product.fromJson(Map<String, dynamic> j) =>
      Product(id: _s(j['id']), name: _s(j['name']), hasTypes: j['has_types'] == true, variants: _l(j['variants'], Variant.fromJson));
}

/// Mstari mmoja wa mauzo (kwenye Mauzo ya leo)
/// `variantId` = '' kama bidhaa haikuwa kwenye orodha ya stock.
class SaleLine {
  final String id; // l_8f2a / rc_0001_0
  final String variantId;
  final String name;
  int qty;
  int selling; // bei aliyouza (inaweza kuwa tofauti na ya stock)
  final int buying; // kutoka stock
  final int stockSelling;
  final String? receiptNo; // kama imetoka kwenye risiti
  final String? receiptId;

  SaleLine({
    this.id = '',
    required this.variantId,
    required this.name,
    required this.qty,
    required this.selling,
    required this.buying,
    int? stockSelling,
    this.receiptNo,
    this.receiptId,
  }) : stockSelling = stockSelling ?? selling;

  int get sales => qty * selling;
  int get capital => qty * buying;
  int get profit => qty * (selling - buying);
  bool get fromReceipt => receiptNo != null && receiptNo!.isNotEmpty;
  bool get fromStock => variantId.isNotEmpty;

  factory SaleLine.fromJson(Map<String, dynamic> j) => SaleLine(
        id: _s(j['id']),
        variantId: j['variant_id'] == null ? '' : _s(j['variant_id']),
        name: _s(j['name']),
        qty: _i(j['qty']),
        selling: _i(j['selling']),
        buying: _i(j['buying']),
        stockSelling: j['stock_selling'] == null ? null : _i(j['stock_selling']),
        receiptNo: j['receipt_no'] == null ? null : _s(j['receipt_no']),
        receiptId: j['receipt_id'] == null ? null : _s(j['receipt_id']),
      );

  Map<String, dynamic> toJson() => {'variant_id': variantId.isEmpty ? null : variantId, 'qty': qty, 'selling': selling};
}

/// Gharama — jina lolote (unstructured). Fields za ziada zinahifadhiwa kama zilivyo.
class Expense {
  final String id; // e_77c0
  String name;
  int amount;
  final Map<String, dynamic> extra;
  Expense({this.id = '', required this.name, required this.amount, Map<String, dynamic>? extra}) : extra = extra ?? {};
  factory Expense.fromJson(Map<String, dynamic> j) {
    final x = Map<String, dynamic>.from(j)..remove('id')..remove('name')..remove('amount');
    return Expense(id: _s(j['id']), name: _s(j['name']), amount: _i(j['amount']), extra: x);
  }
  Map<String, dynamic> toJson() => {...extra, 'name': name, 'amount': amount};
}

class Summary {
  final int sales, capital, expenses;
  Summary({required this.sales, required this.capital, required this.expenses});
  int get productProfit => sales - capital;
  int get net => sales - capital - expenses;
  factory Summary.fromJson(Map<String, dynamic>? j) =>
      Summary(sales: _i(j?['sales']), capital: _i(j?['capital']), expenses: _i(j?['expenses']));
  static Summary zero() => Summary(sales: 0, capital: 0, expenses: 0);
}

class DailySheet {
  final DateTime date;
  final List<SaleLine> receiptLines; // zimeingia zenyewe kutoka risiti
  final List<SaleLine> lines; // alizoandika mwenyewe
  final List<Expense> expenses;
  final DateTime? savedAt;
  final Summary? summary; // hutumwa na server; ikiwa null tunahesabu wenyewe
  DailySheet({required this.date, required this.receiptLines, required this.lines, required this.expenses, this.savedAt, this.summary});
  factory DailySheet.fromJson(Map<String, dynamic> j) => DailySheet(
        date: DateTime.tryParse(_s(j['date'])) ?? DateTime.now(),
        receiptLines: _l(j['receipt_lines'], SaleLine.fromJson),
        lines: _l(j['lines'], SaleLine.fromJson),
        expenses: _l(j['expenses'], Expense.fromJson),
        savedAt: j['saved_at'] == null ? null : DateTime.tryParse(_s(j['saved_at']))?.toLocal(),
        summary: j['summary'] is Map ? Summary.fromJson(Map<String, dynamic>.from(j['summary'] as Map)) : null,
      );

  List<SaleLine> get all => [...receiptLines, ...lines];
  int get qty => all.fold(0, (a, l) => a + l.qty);

  /// Muhtasari wa server; ikiwa haukutumwa, tunahesabu kutoka mistari.
  Summary get totals =>
      summary ??
      Summary(
        sales: all.fold(0, (a, l) => a + l.sales),
        capital: all.fold(0, (a, l) => a + l.capital),
        expenses: expenses.fold(0, (a, e) => a + e.amount),
      );
}

/// Historia ya mauzo (GET /daily/history) — siku zilizopita kwa miezi.
class HistoryDay {
  final String date; // 2026-11-19
  final String label; // Alhamisi, 19 Nov
  final int sales, items, net;
  HistoryDay({required this.date, required this.label, required this.sales, required this.items, required this.net});
  factory HistoryDay.fromJson(Map<String, dynamic> j) =>
      HistoryDay(date: _s(j['date']), label: _s(j['label']), sales: _i(j['sales']), items: _i(j['items']), net: _i(j['net']));
}

class HistoryMonth {
  final String label; // NOVEMBA 2026
  final List<HistoryDay> days;
  HistoryMonth({required this.label, required this.days});
  factory HistoryMonth.fromJson(Map<String, dynamic> j) => HistoryMonth(label: _s(j['label']), days: _l(j['days'], HistoryDay.fromJson));
}

class History {
  final List<HistoryMonth> months;
  final String? nextBefore;
  History({required this.months, this.nextBefore});
  factory History.fromJson(Map<String, dynamic> j) =>
      History(months: _l(j['months'], HistoryMonth.fromJson), nextBefore: j['next_before'] == null ? null : _s(j['next_before']));
}

/// Bidhaa iliyouzwa siku hiyo (Nyumbani -> BIDHAA ZILIZOUZIKA ZAIDI).
/// Server imeshapanga kwa faida kubwa kwanza.
class TopItem {
  final String name;
  final int qty, selling, sales, capital, profit;
  final bool outOfStock;
  TopItem({required this.name, required this.qty, required this.selling, required this.sales, required this.capital, required this.profit, this.outOfStock = false});
  factory TopItem.fromJson(Map<String, dynamic> j) {
    final qty = _i(j['qty']);
    final selling = _i(j['selling']);
    // Majibu ya zamani hayana `sales`/`capital` — tunazihesabu kutoka qty.
    final sales = j['sales'] == null ? qty * selling : _i(j['sales']);
    final capital = j['capital'] == null ? qty * _i(j['buying']) : _i(j['capital']);
    return TopItem(
      name: _s(j['name']),
      qty: qty,
      selling: selling,
      sales: sales,
      capital: capital,
      profit: j['profit'] == null ? sales - capital : _i(j['profit']),
      outOfStock: j['out_of_stock'] == true,
    );
  }
}

/// Jibu la GET /home — Nyumbani unaita API hii pekee.
/// `day == null` = hakuna mauzo yoyote bado (H1).
class HomeData {
  final DateTime? day;
  final Summary summary;
  final List<TopItem> top;
  final List<Expense> expenses;
  HomeData({required this.day, required this.summary, required this.top, required this.expenses});
  static HomeData empty() => HomeData(day: null, summary: Summary.zero(), top: <TopItem>[], expenses: <Expense>[]);
  factory HomeData.fromJson(Map<String, dynamic> j) {
    final d = DateTime.tryParse(_s(j['day'] ?? j['date']));
    if (d == null) return HomeData.empty();
    return HomeData(
      day: d,
      summary: Summary.fromJson(j['summary'] is Map ? Map<String, dynamic>.from(j['summary'] as Map) : null),
      top: _l(j['top'] ?? j['sold_today'], TopItem.fromJson),
      expenses: _l(j['expenses'], Expense.fromJson),
    );
  }
}

class ReceiptItem {
  final String variantId;
  final String name;
  int qty;
  int price;
  int discount; // kwa kila kimoja
  final int buying;
  ReceiptItem({required this.variantId, required this.name, required this.qty, required this.price, this.discount = 0, required this.buying});
  int get gross => qty * price;
  int get discountTotal => qty * discount;
  int get amount => qty * (price - discount);
  factory ReceiptItem.fromJson(Map<String, dynamic> j) => ReceiptItem(
      variantId: _s(j['variant_id']), name: _s(j['name']), qty: _i(j['qty']), price: _i(j['price']), discount: _i(j['discount']), buying: _i(j['buying']));
  Map<String, dynamic> toJson() => {'variant_id': variantId, 'qty': qty, 'price': price, 'discount': discount};
}

class Receipt {
  final String id;
  final String number;
  final DateTime createdAt;
  final String customerName;
  final String customerPhone;
  final List<ReceiptItem> items;
  Receipt({required this.id, required this.number, required this.createdAt, required this.customerName, required this.customerPhone, required this.items});
  int get gross => items.fold(0, (a, b) => a + b.gross);
  int get discountTotal => items.fold(0, (a, b) => a + b.discountTotal);
  int get paid => items.fold(0, (a, b) => a + b.amount);
  int get qty => items.fold(0, (a, b) => a + b.qty);
  String get itemsText => items.map((e) => '${e.name} ${e.qty}').join(' · ');
  factory Receipt.fromJson(Map<String, dynamic> j) {
    final c = Map<String, dynamic>.from((j['customer'] ?? {}) as Map);
    return Receipt(
      id: _s(j['id']),
      number: _s(j['number']),
      createdAt: DateTime.tryParse(_s(j['created_at'])) ?? DateTime.now(),
      customerName: _s(c['name']),
      customerPhone: _s(c['phone']),
      items: _l(j['items'], ReceiptItem.fromJson),
    );
  }
}

/// RIPOTI (P1 – P4) — jibu moja kwa vipindi vyote: siku · wiki · mwezi · mwaka.
/// Majina ya fields yanalingana na JSON ya API (snake_case).
class RProduct {
  final String name;
  final int qty, sales, profit;
  RProduct({required this.name, required this.qty, required this.sales, required this.profit});
  factory RProduct.fromJson(Map<String, dynamic> j) =>
      RProduct(name: _s(j['name']), qty: _i(j['qty']), sales: _i(j['sales']), profit: _i(j['profit']));
}

/// Bidhaa iliyo kwenye stock lakini haikuzwa hata moja kwenye kipindi.
class RUnsold {
  final String name;
  final int qty, capital;
  RUnsold({required this.name, required this.qty, required this.capital});
  factory RUnsold.fromJson(Map<String, dynamic> j) =>
      RUnsold(name: _s(j['name']), qty: _i(j['qty']), capital: _i(j['capital']));
}

/// Nguzo ya grafu. `net == null` = kipindi bado hakijafika (haigusiki).
class RBar {
  final String key, label;
  final int? net;
  RBar({required this.key, required this.label, this.net});
  bool get future => net == null;
  factory RBar.fromJson(Map<String, dynamic> j) =>
      RBar(key: _s(j['key']), label: _s(j['label']), net: j['net'] == null ? null : _i(j['net']));
}

/// Jibu la P1 (siku) na P2–P4 (wiki/mwezi/mwaka).
class Report {
  final String period; // day | week | month | year
  final String label, shortLabel;
  final String? date, start, end;
  final bool hasPrev, hasNext;
  final Summary summary;
  final List<RProduct> products, top, low;
  final List<RUnsold> unsold;
  final List<RBar> bars;
  final int totalQty;

  Report({
    required this.period,
    required this.label,
    required this.shortLabel,
    this.date,
    this.start,
    this.end,
    required this.hasPrev,
    required this.hasNext,
    required this.summary,
    required this.products,
    required this.top,
    required this.low,
    required this.unsold,
    required this.bars,
    required this.totalQty,
  });

  bool get isDay => period == 'day';

  /// "siku" / "wiki" / "mwezi" / "mwaka"
  String get title => const {'day': 'siku', 'week': 'wiki', 'month': 'mwezi', 'year': 'mwaka'}[period] ?? period;

  /// Aina ya ripoti inayofunguliwa kwa kugusa nguzo: wiki → siku, mwezi → wiki, mwaka → mwezi.
  String? get childPeriod => const {'week': 'day', 'month': 'week', 'year': 'month'}[period];

  factory Report.fromJson(Map<String, dynamic> j) => Report(
        period: _s(j['period']),
        label: _s(j['label']),
        shortLabel: _s(j['short_label']).isEmpty ? _s(j['label']) : _s(j['short_label']),
        date: j['date'] == null ? null : _s(j['date']),
        start: j['start'] == null ? null : _s(j['start']),
        end: j['end'] == null ? null : _s(j['end']),
        hasPrev: j['has_prev'] == true,
        hasNext: j['has_next'] == true,
        summary: Summary.fromJson(j['summary'] is Map ? Map<String, dynamic>.from(j['summary'] as Map) : null),
        products: _l(j['products'], RProduct.fromJson),
        top: _l(j['top'], RProduct.fromJson),
        low: _l(j['low'], RProduct.fromJson),
        unsold: _l(j['unsold'], RUnsold.fromJson),
        bars: _l(j['bars'], RBar.fromJson),
        totalQty: _i(j['totals'] is Map ? (j['totals'] as Map)['qty'] : null),
      );
}

// ======================================================================= STOCK (K0 – K4)

/// Mstari wa kadi kwenye orodha ya Stock (K0).
class StockItem {
  final String id, name;
  final bool hasVariants;
  final int variants, qty, capital;
  StockItem({required this.id, required this.name, required this.hasVariants, required this.variants, required this.qty, required this.capital});
  factory StockItem.fromJson(Map<String, dynamic> j) => StockItem(
        id: _s(j['id']),
        name: _s(j['name']),
        hasVariants: j['has_variants'] == true,
        variants: _i(j['variants']),
        qty: _i(j['qty']),
        capital: _i(j['capital']),
      );
}

/// Jibu la K0: muhtasari + bidhaa zilizopangwa kwa jina (A → Z).
class StockList {
  final int products, variants, qty, capital;
  final List<StockItem> items;
  StockList({required this.products, required this.variants, required this.qty, required this.capital, required this.items});
  factory StockList.fromJson(Map<String, dynamic> j) {
    final s = j['summary'] is Map ? Map<String, dynamic>.from(j['summary'] as Map) : <String, dynamic>{};
    return StockList(
      products: _i(s['products']),
      variants: _i(s['variants']),
      qty: _i(s['qty']),
      capital: _i(s['capital']),
      items: _l(j['products'], StockItem.fromJson),
    );
  }
}

/// Aina ya bidhaa kwenye ukurasa wa bidhaa (K1, K3, K4).
class StockVariant {
  final String id, name;
  final int qty, buying, selling;
  StockVariant({required this.id, required this.name, required this.qty, required this.buying, required this.selling});
  int get profitEach => selling - buying;
  factory StockVariant.fromJson(Map<String, dynamic> j) =>
      StockVariant(id: _s(j['id']), name: _s(j['name']), qty: _i(j['qty']), buying: _i(j['buying']), selling: _i(j['selling']));
}

/// Jibu la K1–K4: bidhaa + muhtasari wake + aina zake (zipo kubwa kwanza).
class StockProduct {
  final String id, name;
  final bool hasVariants;
  final int qty, capital, profitIfSold;
  final List<StockVariant> variants;
  StockProduct({required this.id, required this.name, required this.hasVariants, required this.qty, required this.capital, required this.profitIfSold, required this.variants});
  factory StockProduct.fromJson(Map<String, dynamic> j) {
    final s = j['summary'] is Map ? Map<String, dynamic>.from(j['summary'] as Map) : <String, dynamic>{};
    return StockProduct(
      id: _s(j['id']),
      name: _s(j['name']),
      hasVariants: j['has_variants'] == true,
      qty: _i(s['qty']),
      capital: _i(s['capital']),
      profitIfSold: _i(s['profit_if_sold']),
      variants: _l(j['variants'], StockVariant.fromJson),
    );
  }
}
