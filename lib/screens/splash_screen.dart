import 'package:flutter/material.dart';

import 'pin_screen.dart';
import 'shell.dart';

/// Splash ya app: nembo inajijenga kutoka katikati kwenda nje, kisha jina
/// "Ummu Ayman" linaandikwa kushoto kwenda kulia na "OUTFIT" linapanda chini
/// yake. Ikikamilika unaenda kwenye PIN (au Nyumbani kama tayari una session).
class SplashScreen extends StatefulWidget {
  final bool logged;
  const SplashScreen({super.key, required this.logged});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5000),
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(_go);
  }

  Future<void> _go() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
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

  // Inabadilisha v (0..1 ya muda wote) kuwa maendeleo ya hatua moja
  double _step(double v, double a, double b, [Curve c = Curves.easeOut]) =>
      c.transform(((v - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final v = _c.value;
            final iconT = (v / 0.76).clamp(0.0, 1.0); // nembo: 0 – 3.8s
            final write = _step(v, 0.70, 0.92, Curves.easeInOut); // jina linaandikwa
            final sub = _step(v, 0.86, 0.98); // OUTFIT

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 200,
                  height: 206,
                  child: CustomPaint(painter: _IconPainter(iconT)),
                ),
                const SizedBox(height: 20),

                // "Ummu Ayman" inaandikwa kutoka kushoto kwenda kulia
                ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => LinearGradient(
                    colors: const [Colors.white, Colors.white, Colors.transparent],
                    stops: [0.0, write, (write + 0.12).clamp(0.0, 1.0)],
                  ).createShader(rect),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'Ummu Ayman',
                      style: const TextStyle(
                        fontFamily: 'GreatVibes',
                        fontSize: 46,
                        height: 1.25,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),

                // "OUTFIT" inapanda taratibu
                Opacity(
                  opacity: sub,
                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - sub)),
                    child: const Text(
                      'OUTFIT',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontVariations: [FontVariation('wght', 500)],
                        letterSpacing: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  final double t;
  _IconPainter(this.t);

  // Inabadilisha t (0..1) kuwa maendeleo ya hatua moja (a hadi b)
  double _seg(double a, double b, [Curve c = Curves.easeOut]) =>
      c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 484);
    const center = Offset(242, 215);

    final body = Path()
      ..moveTo(242, 5)
      ..cubicTo(170, 5, 115, 65, 112, 160)
      ..lineTo(108, 240)
      ..cubicTo(106, 270, 90, 285, 68, 297)
      ..cubicTo(35, 320, 14, 385, 14, 500)
      ..lineTo(470, 500)
      ..cubicTo(470, 385, 450, 320, 418, 297)
      ..cubicTo(396, 285, 380, 270, 378, 240)
      ..lineTo(372, 160)
      ..cubicTo(369, 65, 314, 5, 242, 5)
      ..close();

    final face = Path()
      ..moveTo(158, 130)
      ..lineTo(326, 130)
      ..lineTo(326, 210)
      ..cubicTo(326, 260, 290, 300, 242, 300)
      ..cubicTo(195, 300, 158, 260, 158, 210)
      ..close();

    final lines = [
      Path()
        ..moveTo(25, 375)
        ..quadraticBezierTo(140, 450, 242, 482)
        ..quadraticBezierTo(350, 450, 455, 368),
      Path()
        ..moveTo(75, 305)
        ..quadraticBezierTo(140, 340, 205, 363),
      Path()
        ..moveTo(405, 285)
        ..quadraticBezierTo(390, 310, 365, 322),
    ];

    // 1. Mawimbi: duara hafifu linalopanuka na kufifia
    final rp = _seg(0.0, 0.37, Curves.linear);
    if (rp > 0 && rp < 1) {
      canvas.drawCircle(
        center,
        340 * rp,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.black.withAlpha((255 * 0.45 * (1 - rp)).round()),
      );
    }

    // Pumzi ya mwisho: nembo inakua kidogo na kurudi
    final k = _seg(0.82, 1.0, Curves.linear);
    final breathe = 1 + 0.05 * (k < 0.5 ? k / 0.5 : (1 - k) / 0.5);
    canvas.translate(center.dx, center.dy);
    canvas.scale(breathe);
    canvas.translate(-center.dx, -center.dy);

    // 2. Mwili unafunuka kwa duara linalokua kutoka katikati
    final reveal = _seg(0.0, 0.40, Curves.easeInOut);
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: 420 * reveal)),
    );
    canvas.drawPath(body, Paint()..color = Colors.black);
    canvas.restore();

    // 3. Uso unachomoza kwa mdundo
    final fp = _seg(0.34, 0.49, Curves.easeOutBack);
    if (fp > 0) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(fp);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawPath(face, Paint()..color = Colors.white);
      canvas.restore();
    }

    // 4. Mstari wa macho unakua kutoka katikati kwenda pande zote
    final bp = _seg(0.50, 0.63);
    if (bp > 0) {
      canvas.drawRect(
        Rect.fromCenter(
          center: const Offset(242.5, 148),
          width: 155 * bp,
          height: 20,
        ),
        Paint()..color = Colors.black,
      );
    }

    // 5. Mistari myeupe inatokea taratibu
    final lp = _seg(0.63, 0.80);
    final white = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withAlpha((255 * lp).round());
    for (final p in lines) {
      canvas.drawPath(p, white);
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) => old.t != t;
}
