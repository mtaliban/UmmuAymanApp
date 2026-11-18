import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api.dart';
import '../config.dart';
import '../theme.dart';
import '../services/notifications.dart';
import 'shell.dart';

/// PIN (muundo namba 6): duara kubwa katikati lenye kufuli, vidoti vikubwa, vitufe vya jedwali.
/// Ukimaliza namba 4 inajikagua yenyewe (hakuna kitufe cha Ingia):
///  - duara linajichora (bluu) -> sahihi: kijani + tiki -> Nyumbani
///  - si sahihi: nyekundu + kutikisika + "PIN si sahihi" -> vidoti vinajifuta
class PinScreen extends StatefulWidget {
  const PinScreen({super.key});
  @override
  State<PinScreen> createState() => _PinScreenState();
}

enum _St { typing, checking, ok, bad }

class _PinScreenState extends State<PinScreen> with TickerProviderStateMixin {
  String _pin = '';
  _St _st = _St.typing;
  late final _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));

  @override
  void dispose() {
    _ring.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _press(String k) {
    if (_st != _St.typing) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (k == 'del') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < kPinLength) {
        _pin += k;
      }
    });
    if (_pin.length == kPinLength) _check();
  }

  Future<void> _check() async {
    setState(() => _st = _St.checking);
    _ring.forward(from: 0);
    try {
      await Future.wait([Api.i.loginPin(_pin), Future.delayed(const Duration(milliseconds: 700))]);
      if (!mounted) return;
      setState(() => _st = _St.ok);
      Notifications.registerAfterLogin();
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 550));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, __, ___) => const Shell(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: SlideTransition(position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(a), child: child),
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _st = _St.bad);
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 1300));
      if (!mounted) return;
      _ring.value = 0;
      setState(() {
        _pin = '';
        _st = _St.typing;
      });
    }
  }

  Color get _color => switch (_st) { _St.ok => C.green, _St.bad => C.red, _ => C.blue };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_ring, _shake]),
                builder: (_, __) {
                  final dx = _shake.isAnimating ? math.sin(_shake.value * math.pi * 10) * 10 * (1 - _shake.value) : 0.0;
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: 172,
                        height: 172,
                        child: CustomPaint(
                          painter: _RingPainter(progress: _st == _St.typing ? 0 : (_st == _St.checking ? _ring.value : 1), color: _color),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: _st == _St.ok
                                  ? const Icon(Icons.check_rounded, key: ValueKey('ok'), size: 64, color: C.green)
                                  : Icon(Icons.lock_outline_rounded, key: const ValueKey('lock'), size: 54, color: _st == _St.bad ? C.red : C.text),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 34),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(kPinLength, (i) {
                          final filled = i < _pin.length;
                          final c = _st == _St.ok ? C.green : _st == _St.bad ? C.red : (filled ? C.text : const Color(0xFFE5E7EB));
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                          );
                        }),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 22,
                        child: _st == _St.checking
                            ? const Text('Inakagua…', style: TextStyle(fontSize: 15, color: C.muted, fontWeight: FontWeight.w600))
                            : _st == _St.bad
                                ? const Text('PIN si sahihi', style: TextStyle(fontSize: 15, color: C.red, fontWeight: FontWeight.w600))
                                : null,
                      ),
                    ]),
                  );
                },
              ),
            ),
          ),
          _Keypad(onKey: _press),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter({required this.progress, required this.color});
  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2 - 8;
    final center = Offset(s.width / 2, s.height / 2);
    c.drawCircle(center, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = const Color(0xFFEEF0F3));
    if (progress > 0) {
      c.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, 2 * math.pi * progress, false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) => o.progress != progress || o.color != color;
}

/// Vitufe vya jedwali (mistari hafifu)
class _Keypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  const _Keypad({required this.onKey});
  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.75,
        children: [
          for (var i = 0; i < keys.length; i++)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  right: i % 3 < 2 ? const BorderSide(color: C.line) : BorderSide.none,
                  bottom: const BorderSide(color: C.line),
                ),
              ),
              child: keys[i].isEmpty
                  ? const SizedBox()
                  : InkWell(
                      onTap: () => onKey(keys[i]),
                      highlightColor: C.blue3,
                      splashColor: C.blue2,
                      child: Center(
                        child: keys[i] == 'del'
                            ? const Icon(Icons.backspace_outlined, size: 24, color: C.text2)
                            : Text(keys[i], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500)),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
