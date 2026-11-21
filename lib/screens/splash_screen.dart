import 'package:flutter/material.dart';

import '../theme.dart';
import 'pin_screen.dart';
import 'shell.dart';

/// Splash ya app: nembo inajijenga (kutoka ndogo hadi ukubwa kamili) halafu mstari
/// mwembamba wa bluu unajaa chini. Ikikamilika unaenda moja kwa moja kwenye PIN
/// (au Nyumbani kama tayari una session).
class SplashScreen extends StatefulWidget {
  final bool logged;
  const SplashScreen({super.key, required this.logged});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  );

  late final Animation<double> _in = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _pop = Tween<double>(begin: 0.82, end: 1.0).animate(
    CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)),
  );
  late final Animation<double> _bar = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.18, 1.0, curve: Curves.easeInOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
    _go();
  }

  Future<void> _go() async {
    await Future.delayed(const Duration(milliseconds: 2300));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, __, ___) => widget.logged ? const Shell() : const PinScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _in,
              child: ScaleTransition(
                scale: _pop,
                child: Image.asset(
                  'assets/brand/logo.png',
                  width: 168,
                  height: 168,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 118,
              height: 3,
              child: AnimatedBuilder(
                animation: _bar,
                builder: (_, __) => Stack(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(color: C.cardLine, borderRadius: BorderRadius.circular(3)),
                      child: const SizedBox.expand(),
                    ),
                    FractionallySizedBox(
                      widthFactor: _bar.value,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(3)),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
