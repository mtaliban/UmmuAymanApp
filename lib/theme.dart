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
  static const cardLine = Color(0xFFE5E7EB); // mpaka wa kadi (Mauzo, Risiti, Historia)
  static const softLine = Color(0xFFF1F2F5); // mistari myepesi ndani ya kadi
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

  // --- Rangi za maandishi, jedwali na alama (palette ya Nyumbani) ---
  static const ink = text; // #111827 — maandishi makuu na namba kubwa
  static const label = Color(0xFF4B5563); // labels ndogo: IDADI, SELLING, BUYING, FAIDA, "Sh"
  static const heading = text2; // #374151 — vichwa vya sehemu na safu
  static const profit = Color(0xFF075985); // faida (bluu)
  static const loss = Color(0xFFB91C1C); // hasara (nyekundu)
  static const rule = field; // #D1D5DB — mistari ya kadi na jedwali
  static const headBg = Color(0xFFF3F4F6); // background ya kichwa cha jedwali
  static const netBg = blueLine; // #DBEAFE — mstari wa FAIDA HALISI
  static const netInk = Color(0xFF1E3A8A); // maandishi ya FAIDA HALISI
  static const rankBg = cardLine; // #E5E7EB — duara la namba

  // --- Ripoti: chati, vidoti vya safu na mistari ya maendeleo ---
  static const bar = Color(0xFF4F8FC4); // nguzo yenye data / mstari wa faida
  static const barLoss = Color(0xFFEF4444); // mstari wa hasara
  static const dotSales = Color(0xFF2563A8); // doti ya Mauzo
  static const dotCapital = Color(0xFFC2410C); // doti ya Mtaji
  static const dotExpense = Color(0xFFA16207); // doti ya Gharama
}

/// Maandishi: ukubwa, unene na rangi zote mahali pamoja.
/// Hutumika Nyumbani; zinaweza kutumika kurasa zote (Mauzo, Stock, Ripoti, Risiti).
class Txt {
  /// Labels ndogo: IDADI · SELLING · BUYING · FAIDA · "Sh"
  static const label = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.label, letterSpacing: .3);

  /// Namba za thamani: idadi, selling, buying, faida
  static const value = TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: C.ink, fontFeatures: tabular);

  /// Majina ya bidhaa
  static const name = TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: C.ink);

  /// Vichwa vya sehemu: MAUZO YA BIDHAA · GHARAMA · HESABU YA FAIDA
  static const section = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.heading, letterSpacing: .5);

  /// Kichwa cha safu ya jedwali: GHARAMA · KIASI (SH)
  static const column = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.heading, letterSpacing: .4);

  /// Maandishi ya jedwali
  static const cell = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: C.ink);

  /// Kiasi cha jedwali
  static const amount = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink, fontFeatures: tabular);

  /// Namba kubwa ya FAIDA HALISI
  static const big = TextStyle(
      fontSize: 41, fontWeight: FontWeight.w700, color: C.profit, letterSpacing: -.5, height: 1.1, fontFeatures: tabular);

  /// Namba ya duara (1, 2, 3 …)
  static const rank = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.ink, fontFeatures: tabular);

  /// Majina ya bidhaa na tarehe za siku kwenye kadi
  static const title = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: C.ink);

  /// Namba za thamani kwenye kadi (SIKU · MAUZO · FAIDA HALISI)
  static const stat = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink, fontFeatures: tabular);

  /// Chip ya risiti kwenye kadi ya bidhaa
  static const chip = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.profit);

  /// Majina ya bidhaa na aina kwenye Stock (kadi za bidhaa, aina)
  static const item = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: C.ink);

  /// "aina N" juu kulia kwenye kadi ya bidhaa
  static const tag = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.heading);

  /// "mtaji ..." chini ya namba kwenye kadi ya bidhaa
  static const meta = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: C.heading);

  /// Namba kubwa ya idadi kwenye kadi ya bidhaa
  static const tally =
      TextStyle(fontSize: 29, fontWeight: FontWeight.w700, color: C.ink, height: 1.15, fontFeatures: tabular);

  /// Namba ndani ya duara la kadi ya aina
  static const badge = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.ink, fontFeatures: tabular);

  /// Maandishi ndani ya kisanduku cha kutafuta
  static const searchIn = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: C.ink);

  /// Placeholder ya kisanduku cha kutafuta
  static const searchHint = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: C.label);

  // --- Ripoti ---

  /// Tab za Ripoti (Siku · Wiki · Mwezi · Mwaka)
  static const tab = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.heading);
  static const tabOn = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.profit);

  /// Tarehe ya kipindi: "‹ 22 – 28 Novemba 2026 ›"
  static const period = TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: C.ink);

  /// Namba kubwa ya faida halisi kwenye Ripoti
  static const big44 = TextStyle(
      fontSize: 44, fontWeight: FontWeight.w700, color: C.profit, height: 1.05, fontFeatures: tabular);

  /// Jina la safu ya kadi (Mauzo · Mtaji · Gharama)
  static const metric = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: C.ink);

  /// Thamani ya safu ya kadi (17 w700)
  static const metricValue = TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink, fontFeatures: tabular);

  /// Maelezo madogo chini ya namba au jina (14)
  static const note = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: C.label);

  /// Namba na majina kwenye chati (13 w600)
  static const chart = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.heading, fontFeatures: tabular);

  /// Kichwa cha sehemu chenye nguvu (Ripoti): 13 w700
  static const sectionStrong =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.heading, letterSpacing: .5);

  /// Kichwa cha safu ya jedwali la bidhaa: BIDHAA · IDADI · FAIDA
  static const tableHead =
      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.heading, letterSpacing: .4);

  /// Jina la bidhaa kwenye jedwali (mistari 2)
  static const row = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.ink, height: 1.2);

  /// Faida kwenye jedwali la bidhaa
  static const rowProfit = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.profit, fontFeatures: tabular);

  /// Idadi kwenye kidonge cha jedwali
  static const qty = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink, fontFeatures: tabular);
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
