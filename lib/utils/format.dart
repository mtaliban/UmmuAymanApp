import 'package:intl/intl.dart';

final _nf = NumberFormat('#,##0', 'en');

/// 364000 -> "364,000"
String money(num v) => _nf.format(v.round());

/// Kwa jedwali la mwaka: 6200000 -> "6.20M", 61000 -> "61k"
String moneyShort(num v) {
  if (v.abs() >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
  if (v.abs() >= 1000) return '${(v / 1000).round()}k';
  return '${v.round()}';
}

/// Juu ya nguzo za grafu: 142000 -> "142k", 2400000 -> "2.4M"
String moneyBar(num v) {
  if (v == 0) return '0';
  if (v.abs() >= 1000000) return '${(v / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
  return '${(v / 1000).round()}k';
}

/// 128000 -> "Laki 1 na elfu 28"
/// 1238000 -> "Milioni 1, laki 2 na elfu 38"
String amountInWords(int n) {
  if (n == 0) return 'Sifuri';
  if (n < 0) return 'Hasi ${amountInWords(-n)}';
  final m = n ~/ 1000000;
  final r = n % 1000000;
  final laki = r ~/ 100000;
  final elfu = (r % 100000) ~/ 1000;
  final parts = <String>[];
  if (m > 0) parts.add('Milioni $m');
  if (laki > 0) parts.add('${parts.isEmpty ? 'Laki' : 'laki'} $laki');
  if (elfu > 0) parts.add('${parts.isEmpty ? 'Elfu' : 'elfu'} $elfu');
  if (parts.isEmpty) return money(n);
  if (parts.length == 1) return parts.first;
  return '${parts.sublist(0, parts.length - 1).join(', ')} na ${parts.last}';
}

int parseMoney(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

const daysSw = ['Jumatatu', 'Jumanne', 'Jumatano', 'Alhamisi', 'Ijumaa', 'Jumamosi', 'Jumapili'];
const daysShort = ['Jtt', 'Jne', 'Jtn', 'Alh', 'Iju', 'Jmo', 'Jpi'];
const monthsSw = ['Januari', 'Februari', 'Machi', 'Aprili', 'Mei', 'Juni', 'Julai', 'Agosti', 'Septemba', 'Oktoba', 'Novemba', 'Desemba'];
const monthsShort = ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des'];

/// "Jumanne, 17 Nov 2026"
String dateLong(DateTime d) => '${daysSw[d.weekday - 1]}, ${d.day} ${monthsShort[d.month - 1]} ${d.year}';

/// "Ijumaa, 20 Nov"
String dateShortDay(DateTime d) => '${daysSw[d.weekday - 1]}, ${d.day} ${monthsShort[d.month - 1]}';

/// "20 Nov"
String dayMonth(DateTime d) => '${d.day} ${monthsShort[d.month - 1]}';

/// "20 Nov 2026, 21:40"
String dateTimeShort(DateTime d) => '${d.day} ${monthsShort[d.month - 1]} ${d.year}, ${hhmm(d)}';

/// "2026-11-20" -> "20-Nov-2026" (jina la faili la PDF)
String fileDate(String isoDate) {
  final d = DateTime.tryParse(isoDate);
  return d == null ? isoDate : '${d.day}-${monthsShort[d.month - 1]}-${d.year}';
}

/// Tarehe ya leo kama "2026-11-20"
String todayIso() => iso(dayOnly(DateTime.now()));

/// "17 Nov 2026"
String dateShort(DateTime d) => '${d.day} ${monthsShort[d.month - 1]} ${d.year}';

/// "2026-11-17"
String iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String hhmm(DateTime d) => DateFormat('HH:mm').format(d);

/// 0712 445 900 -> 255712445900 (WhatsApp)
String waPhone(String phone) {
  var p = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (p.startsWith('0')) p = '255${p.substring(1)}';
  if (p.length == 9) p = '255$p';
  return p;
}

/// Kutafuta kwa maneno ya mwanzo: "aba ny" -> "Abaya nyeusi"
bool nameMatches(String name, String query) {
  final q = query.toLowerCase().trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final words = name.toLowerCase().split(RegExp(r'\s+'));
  for (final w in q) {
    if (!words.any((x) => x.startsWith(w)) && !name.toLowerCase().contains(w)) return false;
  }
  return true;
}
