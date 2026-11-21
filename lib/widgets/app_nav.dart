import 'package:flutter/material.dart';

import '../theme.dart';
import 'app_icons.dart';

/// Menyu ya chini: Nyumbani · Mauzo · Stock · Ripoti · Risiti.
/// Inatumika kwenye [Shell] na pia kwenye kurasa za ndani (Historia, siku ya
/// historia) ili menyu isitokee kama kwenye muundo.
class AppNav extends StatelessWidget {
  final int index;
  const AppNav({super.key, required this.index});

  /// Shell inaweka hapa kazi ya kubadili tab; kurasa za ndani huitumia baada ya kufunga.
  static void Function(int)? onSelect;

  static const items = [
    ('Nyumbani', AppIcons.house),
    ('Mauzo', AppIcons.pencil),
    ('Stock', AppIcons.package),
    ('Ripoti', AppIcons.chart),
    ('Risiti', AppIcons.fileText),
  ];

  void _tap(BuildContext c, int i) {
    Navigator.of(c).popUntil((r) => r.isFirst);
    if (i != index) onSelect?.call(i);
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 70,
            child: Row(children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => _tap(context, i),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        height: 30,
                        decoration: BoxDecoration(color: i == index ? C.blue2 : Colors.transparent, borderRadius: BorderRadius.circular(15)),
                        child: Center(child: AppIcon(items[i].$2, size: 22, color: i == index ? C.blue : const Color(0xFF4B5563))),
                      ),
                      const SizedBox(height: 4),
                      Text(items[i].$1,
                          style: TextStyle(fontSize: 12, fontWeight: i == index ? FontWeight.w700 : FontWeight.w600, color: i == index ? C.blue : C.muted)),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      );
}
