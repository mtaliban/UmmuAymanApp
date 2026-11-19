import 'package:flutter/material.dart';

/// Rangi: nyeupe inayong'aa + bluu ya bahari moja.
/// Kijani = sahihi/faida (PIN), Nyekundu = kosa / imeisha / futa tu.
class C {
  static const blue = Color(0xFF0369A1); // bluu ya bahari (namba 2)
  static const blue2 = Color(0xFFE0F2FE); // hafifu sana
  static const blue3 = Color(0xFFF0F9FF); // background ya mstari unaoandikwa
  static const blueLine = Color(0xFFDBEAFE); // mistari ya daftari
  static const text = Color(0xFF111827);
  static const text2 = Color(0xFF374151);
  static const muted = Color(0xFF6B7280);
  static const faint = Color(0xFF9CA3AF);
  static const line = Color(0xFFECEEF2);
  static const field = Color(0xFFD1D5DB);
  static const winBorder = Color(0xFFCBD5E1); // mpaka wa dirisha la kujaza
  static const receiptBg = Color(0xFFFAFBFC); // kadi za "kutoka risiti"
  static const soft = Color(0xFFF8F9FB);
  static const head = Color(0xFFFAFBFC);
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);
  static const redSoft = Color(0xFFFEF2F2);
  static const redLine = Color(0xFFFECACA);
  static const dark = Color(0xFF1F2937);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(seedColor: C.blue, primary: C.blue, surface: Colors.white),
    scaffoldBackgroundColor: Colors.white,
    splashFactory: InkRipple.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Inter', bodyColor: C.text, displayColor: C.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: C.text,
      centerTitle: false,
    ),
    dividerColor: C.line,
    textSelectionTheme: const TextSelectionThemeData(cursorColor: C.blue),
  );
}

const tabular = [FontFeature.tabularFigures()];
