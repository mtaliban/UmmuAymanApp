import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/models.dart';
import '../utils/format.dart';
import 'mock_api.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

/// Kila skrini inaongea na `Api.i`.
/// kUseMock=true -> MockApi (data za mfano), kUseMock=false -> HttpApi (FastAPI).
/// Endpoints zote zimeelezwa kwenye API-FASTAPI-MONGODB.md (zipo 27).
abstract class Api {
  static final Api i = kUseMock ? MockApi() : HttpApi();

  // Auth
  Future<bool> hasSession();
  Future<void> loginPin(String pin); // inatupa ApiException ikiwa si sahihi
  Future<void> logout();
  Future<void> changePin(String oldPin, String newPin);
  Future<Shop> shop();
  Future<void> registerDevice(String fcmToken, String platform);

  // Nyumbani — API moja tu: GET /home
  Future<HomeData> home();
  Future<HomeData?> lastHome(); // kumbukumbu ya mwisho (bila mtandao)

  // Stock
  Future<List<Product>> products();
  Future<Product> createProduct({required String name, required bool hasTypes, int qty = 0, int buying = 0, int selling = 0});
  Future<void> renameProduct(String id, String name);
  Future<void> deleteProduct(String id);
  Future<Variant> addVariant(String productId, {required String name, required int qty, required int buying, required int selling});
  Future<Variant> updateVariant(String id, {int addQty = 0, int? buying, int? selling, String? name});
  Future<void> deleteVariant(String id);

  // Mauzo ya leo
  Future<DailySheet> daily(DateTime date);
  Future<DailySheet> saveDaily(DateTime date, List<SaleLine> lines, List<Expense> expenses);
  Future<List<String>> expenseNames();

  // Risiti
  Future<List<Receipt>> receipts(DateTime date);
  Future<Receipt> createReceipt({required String name, required String phone, required List<ReceiptItem> items});
  Future<Receipt> receipt(String id);
  Future<void> cancelReceipt(String id);

  // Ripoti
  Future<Report> report(Period period, DateTime anchor);
  Future<DayDetail> day(DateTime date);
}

class HttpApi extends Api {
  String? _token;

  Future<String?> _getToken() async {
    if (_token != null) return _token;
    final sp = await SharedPreferences.getInstance();
    _token = sp.getString('token');
    return _token;
  }

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query}) async {
    final t = await _getToken();
    final uri = Uri.parse('$kBaseUrl$path').replace(queryParameters: query);
    final headers = {'Content-Type': 'application/json', if (t != null) 'Authorization': 'Bearer $t'};
    http.Response r;
    try {
      switch (method) {
        case 'GET':
          r = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));
          break;
        case 'POST':
          r = await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 20));
          break;
        case 'PUT':
          r = await http.put(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 20));
          break;
        case 'PATCH':
          r = await http.patch(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 20));
          break;
        case 'DELETE':
          r = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 20));
          break;
        default:
          throw ApiException('Method si sahihi');
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Hakuna mtandao. Jaribu tena.');
    }
    final txt = utf8.decode(r.bodyBytes);
    final data = txt.isEmpty ? null : jsonDecode(txt);
    if (r.statusCode >= 400) {
      final msg = (data is Map && data['detail'] is String) ? data['detail'] as String : 'Kuna tatizo (${r.statusCode})';
      throw ApiException(msg, r.statusCode);
    }
    return data;
  }

  Map<String, dynamic> _m(dynamic d) => Map<String, dynamic>.from(d as Map);
  List<Map<String, dynamic>> _list(dynamic d) => (d as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  @override
  Future<bool> hasSession() async => (await _getToken()) != null;

  @override
  Future<void> loginPin(String pin) async {
    final d = await _send('POST', '/auth/pin', body: {'pin': pin});
    _token = d['token'] as String;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('token', _token!);
  }

  @override
  Future<void> logout() async {
    try {
      await _send('POST', '/auth/logout');
    } catch (_) {}
    _token = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove('token');
  }

  @override
  Future<void> changePin(String oldPin, String newPin) async => _send('PUT', '/auth/pin', body: {'old_pin': oldPin, 'new_pin': newPin});

  @override
  Future<Shop> shop() async => Shop.fromJson(_m(await _send('GET', '/me')));

  @override
  Future<void> registerDevice(String fcmToken, String platform) async => _send('POST', '/devices', body: {'fcm_token': fcmToken, 'platform': platform});

  static const _homeCacheKey = 'home_cache';

  @override
  Future<HomeData> home() async {
    final d = _m(await _send('GET', '/home'));
    final h = HomeData.fromJson(d);
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_homeCacheKey, jsonEncode(d));
    } catch (_) {}
    return h;
  }

  @override
  Future<HomeData?> lastHome() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final s = sp.getString(_homeCacheKey);
      if (s == null || s.isEmpty) return null;
      return HomeData.fromJson(_m(jsonDecode(s)));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Product>> products() async => _list(await _send('GET', '/products')).map(Product.fromJson).toList();

  @override
  Future<Product> createProduct({required String name, required bool hasTypes, int qty = 0, int buying = 0, int selling = 0}) async =>
      Product.fromJson(_m(await _send('POST', '/products', body: {
        'name': name,
        'has_types': hasTypes,
        if (!hasTypes) ...{'qty': qty, 'buying': buying, 'selling': selling},
      })));

  @override
  Future<void> renameProduct(String id, String name) async => _send('PATCH', '/products/$id', body: {'name': name});

  @override
  Future<void> deleteProduct(String id) async => _send('DELETE', '/products/$id');

  @override
  Future<Variant> addVariant(String productId, {required String name, required int qty, required int buying, required int selling}) async =>
      Variant.fromJson(_m(await _send('POST', '/products/$productId/variants', body: {'name': name, 'qty': qty, 'buying': buying, 'selling': selling})));

  @override
  Future<Variant> updateVariant(String id, {int addQty = 0, int? buying, int? selling, String? name}) async =>
      Variant.fromJson(_m(await _send('PATCH', '/variants/$id', body: {
        'add_qty': addQty,
        if (buying != null) 'buying': buying,
        if (selling != null) 'selling': selling,
        if (name != null) 'name': name,
      })));

  @override
  Future<void> deleteVariant(String id) async => _send('DELETE', '/variants/$id');

  @override
  Future<DailySheet> daily(DateTime date) async => DailySheet.fromJson(_m(await _send('GET', '/daily/${iso(date)}')));

  @override
  Future<DailySheet> saveDaily(DateTime date, List<SaleLine> lines, List<Expense> expenses) async => DailySheet.fromJson(_m(await _send('PUT', '/daily/${iso(date)}', body: {
        'lines': lines.map((e) => e.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
      })));

  @override
  Future<List<String>> expenseNames() async => ((await _send('GET', '/expenses/names')) as List).map((e) => '$e').toList();

  @override
  Future<List<Receipt>> receipts(DateTime date) async => _list(await _send('GET', '/receipts', query: {'date': iso(date)})).map(Receipt.fromJson).toList();

  @override
  Future<Receipt> createReceipt({required String name, required String phone, required List<ReceiptItem> items}) async => Receipt.fromJson(_m(await _send('POST', '/receipts', body: {
        'customer': {'name': name, 'phone': phone},
        'items': items.map((e) => e.toJson()).toList(),
      })));

  @override
  Future<Receipt> receipt(String id) async => Receipt.fromJson(_m(await _send('GET', '/receipts/$id')));

  @override
  Future<void> cancelReceipt(String id) async => _send('POST', '/receipts/$id/cancel');

  @override
  Future<Report> report(Period period, DateTime anchor) async => Report.fromJson(_m(await _send('GET', '/reports/${period.api}', query: {'date': iso(anchor)})));

  @override
  Future<DayDetail> day(DateTime date) async => DayDetail.fromJson(_m(await _send('GET', '/reports/day/${iso(date)}')));
}
