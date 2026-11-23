import 'package:flutter/material.dart';

import '../widgets/app_nav.dart';
import 'home_screen.dart';
import 'receipts_screen.dart';
import 'reports_screen.dart';
import 'sales_screen.dart';
import 'stock_screen.dart';

/// Menyu ya chini: Nyumbani · Mauzo · Stock · Ripoti · Risiti
/// Kurasa zinaundwa mara moja tu (IndexedStack) — kurudi kwenye tab
/// hakupakui data upya wala kufuta kile ulichokuwa umeandika.
class Shell extends StatefulWidget {
  const Shell({super.key});
  static ShellState? of(BuildContext c) => c.findAncestorStateOfType<ShellState>();
  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> {
  static const _count = 5;

  int _tab = 0;

  /// Kurasa zilizotembelewa; ile isiyotembelewa ni tupu (haipaki kitu mapema).
  final List<Widget?> _pages = List<Widget?>.filled(_count, null);

  late final void Function(int) _link = go;

  @override
  void initState() {
    super.initState();
    AppNav.onSelect = _link;
    _pages[0] = _build(0);
  }

  @override
  void dispose() {
    if (identical(AppNav.onSelect, _link)) AppNav.onSelect = null;
    super.dispose();
  }

  Widget _build(int i) {
    switch (i) {
      case 1:
        return const SalesScreen();
      case 2:
        return const StockScreen();
      case 3:
        return const ReportsScreen();
      case 4:
        return const ReceiptsScreen();
      default:
        return const HomeScreen();
    }
  }

  void go(int i) {
    if (i == _tab) return;
    setState(() {
      _tab = i;
      _pages[i] ??= _build(i); // mara ya kwanza pekee
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [for (var i = 0; i < _count; i++) _pages[i] ?? const SizedBox.shrink()],
        ),
        // Icons za mstari mwembamba (Chaguo B) — zinatofautishwa kwa rangi
        bottomNavigationBar: AppNav(index: _tab),
      );
}
