import 'package:flutter/material.dart';

import '../theme.dart';
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
  Widget build(BuildContext context) {
    const items = [
      ('Nyumbani', Icons.home_outlined, Icons.home_rounded),
      ('Mauzo', Icons.edit_outlined, Icons.edit_rounded),
      ('Stock', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
      ('Ripoti', Icons.bar_chart_outlined, Icons.bar_chart_rounded),
      ('Risiti', Icons.description_outlined, Icons.description_rounded),
    ];
    return Scaffold(
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: _page()),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 70,
            child: Row(children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => go(i),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        height: 30,
                        decoration: BoxDecoration(color: i == _tab ? C.blue2 : Colors.transparent, borderRadius: BorderRadius.circular(15)),
                        child: Icon(i == _tab ? items[i].$3 : items[i].$2, size: 22, color: i == _tab ? C.blue : const Color(0xFF4B5563)),
                      ),
                      const SizedBox(height: 4),
                      Text(items[i].$1,
                          style: TextStyle(fontSize: 12, fontWeight: i == _tab ? FontWeight.w700 : FontWeight.w600, color: i == _tab ? C.blue : C.muted)),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
