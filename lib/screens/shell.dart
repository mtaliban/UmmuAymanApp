import 'package:flutter/material.dart';

import '../widgets/app_nav.dart';
import 'home_screen.dart';
import 'receipts_screen.dart';
import 'reports_screen.dart';
import 'sales_screen.dart';
import 'stock_screen.dart';

/// Menyu ya chini: Nyumbani · Mauzo · Stock · Ripoti · Risiti
/// Ukibonyeza tab, ukurasa unapakia data upya.
class Shell extends StatefulWidget {
  const Shell({super.key});
  static ShellState? of(BuildContext c) => c.findAncestorStateOfType<ShellState>();
  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> {
  int _tab = 0;
  int _reload = 0;

  late final void Function(int) _link = go;

  @override
  void initState() {
    super.initState();
    AppNav.onSelect = _link;
  }

  @override
  void dispose() {
    if (identical(AppNav.onSelect, _link)) AppNav.onSelect = null;
    super.dispose();
  }

  void go(int i) => setState(() {
        _tab = i;
        _reload++;
      });

  Widget _page() {
    final k = ValueKey('$_tab-$_reload');
    switch (_tab) {
      case 1:
        return SalesScreen(key: k);
      case 2:
        return StockScreen(key: k);
      case 3:
        return ReportsScreen(key: k);
      case 4:
        return ReceiptsScreen(key: k);
      default:
        return HomeScreen(key: k);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: _page()),
        // Icons za mstari mwembamba (Chaguo B) — zinatofautishwa kwa rangi
        bottomNavigationBar: AppNav(index: _tab),
      );
}
