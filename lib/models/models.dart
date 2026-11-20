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
class SaleLine {
  final String variantId;
  final String name;
  int qty;
  int selling; // bei aliyouza (inaweza kuwa tofauti na ya stock)
  final int buying; // kutoka stock
  final int stockSelling;
  final String? receiptNo; // kama imetoka kwenye risiti

  SaleLine({required this.variantId, required this.name, required this.qty, required this.selling, required this.buying, int? stockSelling, this.receiptNo})
      : stockSelling = stockSelling ?? selling;

  int get sales => qty * selling;
  int get capital => qty * buying;
  int get profit => qty * (selling - buying);
  bool get fromReceipt => receiptNo != null && receiptNo!.isNotEmpty;

  factory SaleLine.fromJson(Map<String, dynamic> j) => SaleLine(
        variantId: _s(j['variant_id']),
        name: _s(j['name']),
        qty: _i(j['qty']),
        selling: _i(j['selling']),
        buying: _i(j['buying']),
        stockSelling: j['stock_selling'] == null ? null : _i(j['stock_selling']),
        receiptNo: j['receipt_no'] == null ? null : _s(j['receipt_no']),
      );

  Map<String, dynamic> toJson() => {'variant_id': variantId, 'qty': qty, 'selling': selling};
}

/// Gharama — jina lolote (unstructured). Fields za ziada zinahifadhiwa kama zilivyo.
class Expense {
  String name;
  int amount;
  final Map<String, dynamic> extra;
  Expense({required this.name, required this.amount, Map<String, dynamic>? extra}) : extra = extra ?? {};
  factory Expense.fromJson(Map<String, dynamic> j) {
    final x = Map<String, dynamic>.from(j)..remove('name')..remove('amount');
    return Expense(name: _s(j['name']), amount: _i(j['amount']), extra: x);
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
  DailySheet({required this.date, required this.receiptLines, required this.lines, required this.expenses, this.savedAt});
  factory DailySheet.fromJson(Map<String, dynamic> j) => DailySheet(
        date: DateTime.tryParse(_s(j['date'])) ?? DateTime.now(),
        receiptLines: _l(j['receipt_lines'], SaleLine.fromJson),
        lines: _l(j['lines'], SaleLine.fromJson),
        expenses: _l(j['expenses'], Expense.fromJson),
        savedAt: j['saved_at'] == null ? null : DateTime.tryParse(_s(j['saved_at'])),
      );
}

/// Kilichouzwa leo (Nyumbani -> kichupo "Vilivyouzwa leo")
class SoldRow {
  final String name;
  final int qty, buying, selling, profit;
  final bool outOfStock;
  SoldRow({required this.name, required this.qty, required this.buying, required this.selling, required this.profit, this.outOfStock = false});
  factory SoldRow.fromJson(Map<String, dynamic> j) =>
      SoldRow(name: _s(j['name']), qty: _i(j['qty']), buying: _i(j['buying']), selling: _i(j['selling']), profit: _i(j['profit']), outOfStock: j['out_of_stock'] == true);
}

class HomeData {
  final DateTime date;
  final Summary summary;
  final List<Product> products;
  final List<SoldRow> soldToday;
  HomeData({required this.date, required this.summary, required this.products, required this.soldToday});
  int get totalQty => products.fold(0, (a, p) => a + p.qty);
  factory HomeData.fromJson(Map<String, dynamic> j) => HomeData(
        date: DateTime.tryParse(_s(j['date'])) ?? DateTime.now(),
        summary: Summary.fromJson(j['summary'] as Map<String, dynamic>?),
        products: _l(j['products'], Product.fromJson),
        soldToday: _l(j['sold_today'], SoldRow.fromJson),
      );
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

enum Period { week, month, year }

extension PeriodX on Period {
  String get api => const ['week', 'month', 'year'][index];
  String get label => const ['Wiki', 'Mwezi', 'Mwaka'][index];
  String get chartTitle => const ['Faida kila siku', 'Faida kila wiki', 'Faida kila mwezi'][index];
  String get bestLabel => const ['Siku bora', 'Wiki bora', 'Mwezi bora'][index];
  String get colLabel => const ['SIKU', 'WIKI', 'MWEZI'][index];
  String get byLabel => const ['KWA SIKU', 'KWA WIKI', 'KWA MWEZI'][index];
  String get noun => const ['wiki', 'mwezi', 'mwaka'][index];
}

class ReportRow {
  final String key; // wiki: "2026-11-15" ; mwezi: "2026-11-08" (siku ya kwanza ya wiki) ; mwaka: "2026-11"
  final String label; // "Jumapili" / "Wiki 2" / "Novemba"
  final String sub; // "15 Nov" / "8 – 14" / ""
  final String short; // chini ya nguzo: "Jpi" / "W2" / "Nov"
  final String best; // "Jumapili 15" / "Wiki 2" / "Novemba"
  final Summary s;
  final bool current; // leo / inaendelea
  ReportRow({required this.key, required this.label, required this.sub, required this.short, required this.best, required this.s, required this.current});
  factory ReportRow.fromJson(Map<String, dynamic> j) => ReportRow(
        key: _s(j['key']),
        label: _s(j['label']),
        sub: _s(j['sub']),
        short: _s(j['short']),
        best: _s(j['best_label'] ?? j['label']),
        s: Summary.fromJson(j),
        current: j['current'] == true,
      );
}

class NameQty {
  final String name;
  final int qty, profit;
  NameQty({required this.name, required this.qty, this.profit = 0});
  factory NameQty.fromJson(Map<String, dynamic> j) => NameQty(name: _s(j['name']), qty: _i(j['qty']), profit: _i(j['profit']));
}

class Report {
  final Period period;
  final String label; // "11 – 17 Nov 2026" / "Novemba 2026" / "2026"
  final DateTime anchor;
  final Summary summary;
  final List<ReportRow> rows;
  final List<NameQty> top, low, unsold;
  final int capitalInShop, purchases;
  final bool hasNext;
  Report({
    required this.period,
    required this.label,
    required this.anchor,
    required this.summary,
    required this.rows,
    required this.top,
    required this.low,
    required this.unsold,
    required this.capitalInShop,
    required this.purchases,
    required this.hasNext,
  });
  int get bestIndex {
    if (rows.isEmpty) return -1;
    var b = 0;
    for (var i = 1; i < rows.length; i++) {
      if (rows[i].s.net > rows[b].s.net) b = i;
    }
    return b;
  }

  factory Report.fromJson(Map<String, dynamic> j) => Report(
        period: Period.values.firstWhere((p) => p.api == j['period'], orElse: () => Period.week),
        label: _s(j['label']),
        anchor: DateTime.tryParse(_s(j['anchor'])) ?? DateTime.now(),
        summary: Summary.fromJson(j['summary'] as Map<String, dynamic>?),
        rows: _l(j['rows'], ReportRow.fromJson),
        top: _l(j['top'], NameQty.fromJson),
        low: _l(j['low'], NameQty.fromJson),
        unsold: _l(j['unsold'], NameQty.fromJson),
        capitalInShop: _i(j['capital_in_shop']),
        purchases: _i(j['purchases']),
        hasNext: j['has_next'] == true,
      );
}

class DayDetail {
  final DateTime date;
  final String label;
  final List<NameQty> items;
  final Summary summary;
  DayDetail({required this.date, required this.label, required this.items, required this.summary});
  factory DayDetail.fromJson(Map<String, dynamic> j) => DayDetail(
        date: DateTime.tryParse(_s(j['date'])) ?? DateTime.now(),
        label: _s(j['label']),
        items: _l(j['items'], NameQty.fromJson),
        summary: Summary.fromJson(j['summary'] as Map<String, dynamic>?),
      );
}
