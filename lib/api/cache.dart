import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Kashe ya majibu ya GET: kumbukumbu (RAM) + diski (shared_preferences).
///
/// - Jibu la GET linahifadhiwa; ndani ya [ttl] hakuna ombi jipya kwa server.
/// - Bila mtandao, jibu la mwisho linatumika (hata limepitwa na [ttl]),
///   kwa hiyo kurasa zinaonyesha data iliyopakiwa awali.
/// - Ombi lolote la kuandika (POST/PUT/PATCH/DELETE) linafuta kashe yote,
///   hivyo data mpya inasomwa tena mara moja.
class ApiCache {
  ApiCache._();

  /// Muda ambao jibu la GET linachukuliwa kuwa safi (hakuna kupakua tena).
  static const Duration ttl = Duration(minutes: 5);
  static const String _prefix = 'api_cache:';

  static final Map<String, _Entry> _mem = {};
  static bool _loaded = false;

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final sp = await SharedPreferences.getInstance();
      for (final k in sp.getKeys()) {
        if (!k.startsWith(_prefix)) continue;
        final raw = sp.getString(k);
        if (raw == null) continue;
        final e = _Entry.decode(raw);
        if (e != null) _mem[k.substring(_prefix.length)] = e;
      }
    } catch (_) {}
  }

  /// Jibu lililohifadhiwa (`stale` = limepitwa na [ttl]).
  static Future<({dynamic data, bool stale})?> read(String key) async {
    await _ensureLoaded();
    final e = _mem[key];
    if (e == null) return null;
    return (data: e.data, stale: e.stale);
  }

  static Future<void> write(String key, dynamic data) async {
    final e = _Entry(data, DateTime.now().millisecondsSinceEpoch);
    _mem[key] = e;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('$_prefix$key', e.encode());
    } catch (_) {}
  }

  /// Futa kashe yote (baada ya kuandika, au kutoka).
  static Future<void> clear() async {
    _mem.clear();
    try {
      final sp = await SharedPreferences.getInstance();
      for (final k in sp.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
        await sp.remove(k);
      }
    } catch (_) {}
  }
}

class _Entry {
  final dynamic data;
  final int at; // millisecondsSinceEpoch
  const _Entry(this.data, this.at);

  bool get stale => DateTime.now().millisecondsSinceEpoch - at > ApiCache.ttl.inMilliseconds;

  String encode() => jsonEncode({'at': at, 'd': data});

  static _Entry? decode(String raw) {
    try {
      final m = jsonDecode(raw) as Map;
      return _Entry(m['d'], (m['at'] as num).toInt());
    } catch (_) {
      return null;
    }
  }
}
