import 'dart:async';

/// Arifa ndogo ya Nyumbani.
/// Mauzo (na kurasa nyingine zinazobadilisha mauzo) zinaita [refresh]
/// ili Nyumbani ipakie `GET /home` upya mara moja.
class HomeBus {
  HomeBus._();
  static final StreamController<void> _c = StreamController<void>.broadcast();
  static Stream<void> get stream => _c.stream;
  static void refresh() {
    if (!_c.isClosed) _c.add(null);
  }
}
