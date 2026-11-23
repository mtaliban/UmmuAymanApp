import 'package:flutter/material.dart';

import '../theme.dart';
import 'ui.dart';

/// Kadi ya bidhaa: namba yenye duara hafifu · jina · IDADI · SELLING · BUYING · FAIDA.
///
/// Inatumika Mauzo (pamoja na risiti) na Nyumbani — muundo mmoja sehemu zote.
class SaleCard extends StatelessWidget {
  final int? rank;
  final String title;
  final String? tag;
  final List<(String, String)> cols;
  final Color? bg;
  final bool highlight;
  final int? profit;
  final VoidCallback? onTap;
  const SaleCard({
    super.key,
    required this.title,
    required this.cols,
    this.rank,
    this.tag,
    this.bg,
    this.highlight = false,
    this.profit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Box(
        radius: 12,
        onTap: onTap,
        color: highlight ? C.blue3 : bg,
        border: highlight ? C.blue : C.rule,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (rank != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: C.rankBg, shape: BoxShape.circle),
                  child: Text('$rank', style: Txt.rank),
                ),
              ),
            Expanded(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.name),
            ),
            if (tag != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: C.netBg, borderRadius: BorderRadius.circular(6)),
                child: Text(tag!, style: Txt.chip),
              ),
          ]),
          const SizedBox(height: 9),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < cols.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cols[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.label),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      cols[i].$2,
                      maxLines: 1,
                      style: Txt.value.copyWith(
                        color: i != cols.length - 1 ? C.ink : ((profit ?? 0) < 0 ? C.loss : C.profit),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}
