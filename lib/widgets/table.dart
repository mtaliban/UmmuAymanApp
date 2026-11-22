import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Kichwa kidogo cha jedwali: jina kushoto (herufi kubwa, kijivu),
/// maelezo upande wa kulia — kama kwenye muundo.
class TblHead extends StatelessWidget {
  final String left;
  final String? right;
  const TblHead(this.left, {super.key, this.right});

  static const _title = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.muted, letterSpacing: .9);

  /// Kichwa cha safu wima (GHARAMA, KIASI (SH) …).
  static const col = TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: C.muted, letterSpacing: .4);
  static const amount = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: C.muted, letterSpacing: .4);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(child: Text(left.toUpperCase(), style: _title)),
          if (right != null) Text(right!, style: const TextStyle(fontSize: 12.5, color: C.muted)),
        ]),
      );
}

/// Fremu na safu za jedwali (kona za mraba, mistari myembamba).
class Tbl {
  static Widget frame(List<Widget> rows) => Container(
        decoration: BoxDecoration(border: Border.all(color: C.cardLine)),
        child: Column(children: rows),
      );

  /// Safu yenye nafasi sawa kwa kila safu wima (flex) na mistari wima kati.
  static Widget row(List<Widget> cells, List<int> flex,
      {Color? bg, Border? border, double vpad = 12}) {
    return Container(
      decoration: BoxDecoration(color: bg, border: border),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: flex[i],
              child: Container(
                padding: EdgeInsets.fromLTRB(i == 0 ? 10 : 5, vpad, i == cells.length - 1 ? 10 : 5, vpad),
                alignment: i == 0 ? Alignment.centerLeft : Alignment.centerRight,
                decoration: i == 0 ? null : const BoxDecoration(border: Border(left: BorderSide(color: C.line))),
                child: cells[i],
              ),
            ),
        ]),
      ),
    );
  }

  /// Safu ya safu mbili: jina kushoto, kiasi kulia (upana 104).
  static Widget pair(Widget label, String amount, TextStyle amountStyle,
      {Key? key, Color? bg, Border? border, double vpad = 13}) {
    return Container(
      key: key,
      decoration: BoxDecoration(color: bg, border: border),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, vpad, 6, vpad),
              child: Align(alignment: Alignment.centerLeft, child: label),
            ),
          ),
          Container(
            width: 104,
            padding: EdgeInsets.fromLTRB(4, vpad, 10, vpad),
            alignment: Alignment.centerRight,
            decoration: const BoxDecoration(border: Border(left: BorderSide(color: C.line))),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(amount, maxLines: 1, style: amountStyle),
            ),
          ),
        ]),
      ),
    );
  }
}

/// GHARAMA: jedwali la gharama — GHARAMA · KIASI (SH), jumla chini.
///
/// Nyumbani linaonyesha gharama za siku; Mauzo linaonyesha zile zile,
/// na mstari ukigusa unamruhusu mtumiaji kuirekebisha.
class ExpenseTable extends StatelessWidget {
  final List<Expense> rows;
  final int total;
  final String title;
  final String totalLabel;
  final Key? totalKey;
  final Set<String?> highlight;
  final ValueChanged<Expense>? onTap;
  const ExpenseTable({
    super.key,
    required this.rows,
    required this.total,
    this.title = 'Gharama',
    this.totalLabel = 'Jumla ya gharama',
    this.totalKey,
    this.highlight = const {},
    this.onTap,
  });

  static const _cell = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.text, height: 1.25);
  static const _amount = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.text, fontFeatures: tabular);

  @override
  Widget build(BuildContext context) {
    const bottom = Border(bottom: BorderSide(color: C.line));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TblHead(title),
      Tbl.frame([
        Tbl.pair(const Text('GHARAMA', style: TblHead.col), 'KIASI (SH)', TblHead.amount,
            bg: C.head, border: bottom, vpad: 10),
        for (final (i, e) in rows.indexed) _row(e, i, bottom),
        Tbl.pair(
            Text(totalLabel, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            money(total),
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFeatures: tabular),
            key: totalKey,
            bg: C.soft,
            border: const Border(top: BorderSide(color: C.cardLine, width: 1.5)),
            vpad: 14),
      ]),
    ]);
  }

  Widget _row(Expense e, int i, Border bottom) {
    final row = Tbl.pair(
      Row(children: [
        SizedBox(width: 20, child: Text('${i + 1}.', style: const TextStyle(fontSize: 13, color: C.muted))),
        Expanded(child: Text(e.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: _cell)),
      ]),
      money(e.amount),
      _amount,
      bg: highlight.contains(e.id) ? C.blue3 : null,
      border: bottom,
    );
    if (onTap == null) return row;
    return InkWell(onTap: () => onTap!(e), child: row);
  }
}
