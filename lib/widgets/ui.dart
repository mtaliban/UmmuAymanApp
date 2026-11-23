import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../utils/format.dart';
import 'app_icons.dart';

// ======================================================================= vipande vidogo

/// Kichwa cha ukurasa (Chaguo A):
///  - nafasi nyeupe juu (chini ya saa/betri)
///  - jina la ukurasa + kitufe vimekaa CHINI, juu kidogo ya mstari mwembamba
///  - mstari wa kijivu #E5E7EB unatenganisha kichwa na maudhui
///  - ukurasa wenye kurudi (Historia, siku ya historia): kitufe cha kurudi kiko
///    JUU ya jina, jina kubwa chini yake, kama kwenye muundo.
const double kHeaderHeight = 96; // urefu wa kichwa chini ya status bar
const double kHeaderBackHeight = 118; // urefu ukiwa na kitufe cha kurudi juu
const double kHeaderFlatHeight = 110; // kurudi 42 kando ya jina (Historia)
const double kHeaderBottomGap = 10; // nafasi kati ya maneno na mstari

PreferredSizeWidget pageBar(String title,
        {String? subtitle,
        Widget? action,
        bool back = false,
        bool boxBack = false,
        bool flatBack = false,
        bool light = false,
        bool drop = false,
        bool center = false}) =>
    _PageHeader(
        title: title,
        subtitle: subtitle,
        action: action,
        back: back,
        boxBack: boxBack,
        flatBack: flatBack,
        light: light,
        drop: drop,
        center: center);

class _PageHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final bool back;
  final bool boxBack;
  final bool flatBack;
  final bool light;

  /// true = maudhui ya kichwa yanashuka 44px chini ya eneo salama (Stock, Abaya).
  final bool drop;

  /// true = jina na vitufe vimekatikati kwa wima (Risiti).
  final bool center;
  const _PageHeader(
      {required this.title,
      this.subtitle,
      this.action,
      this.back = false,
      this.boxBack = false,
      this.flatBack = false,
      this.light = false,
      this.drop = false,
      this.center = false});

  bool get _stacked => back && boxBack;

  @override
  Size get preferredSize => Size.fromHeight(
      (flatBack ? kHeaderFlatHeight : (_stacked ? kHeaderBackHeight : kHeaderHeight)) + (drop && !flatBack ? 44 : 0) + 1);

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
        child: Material(
          color: Colors.white,
          child: SafeArea(
            bottom: false,
            child: flatBack ? _flatBar(context) : (_stacked ? _stackedBar(context) : _inlineBar(context)),
          ),
        ),
      );

  /// Historia / siku ya historia: [<-] juu, jina kubwa chini yake.
  Widget _stackedBar(BuildContext context) => Container(
        height: kHeaderBackHeight + 1,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, kHeaderBottomGap),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [_backBox(context), const Spacer(), if (action != null) action!]),
            const SizedBox(height: 10),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 25, height: 1.1, fontWeight: FontWeight.w800, color: C.text)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: C.muted)),
              ),
          ],
        ),
      );

  /// Historia / siku ya historia: kitufe 42 kando ya jina, kila kitu kimeshuka
  /// 44px kutoka juu ya eneo salama.
  Widget _flatBar(BuildContext context) => Container(
        height: kHeaderFlatHeight + 1,
        padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.cardLine))),
        child: Row(children: [
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(border: Border.all(color: C.faint), borderRadius: BorderRadius.circular(8)),
              child: const Center(child: AppIcon(AppIcons.chevronLeft, size: 24, color: C.text)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 24, height: 1.15, fontWeight: FontWeight.w500, color: C.text)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: C.label)),
                ),
            ]),
          ),
          if (action != null) ...[const SizedBox(width: 14), action!],
        ]),
      );

  Widget _backBox(BuildContext context) => InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(border: Border.all(color: C.faint), borderRadius: BorderRadius.circular(10)),
          child: const Center(child: AppIcon(AppIcons.arrowLeft, size: 20, color: C.text)),
        ),
      );

  Widget _inlineBar(BuildContext context) => Container(
        // drop: 44 juu (chini ya saa/betri) + 16 chini ya maneno kabla ya mstari.
        // Urefu ni ule ule wa kichwa cha Historia (110) ili maudhui yaanze sawa.
        height: (drop ? kHeaderFlatHeight : kHeaderHeight) + 1,
        padding: EdgeInsets.fromLTRB(back ? 6 : 18, drop ? 44 : 0, 16, drop ? 16 : kHeaderBottomGap),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.cardLine))),
        child: Row(crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.end, children: [
          if (back)
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded, color: C.text, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 30),
              visualDensity: VisualDensity.compact,
            ),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: light ? 20 : (drop ? 24 : 22),
                    height: 1.15,
                    fontWeight: light || drop ? FontWeight.w500 : FontWeight.w800,
                    color: C.text,
                  )),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: light ? 12 : 13.5,
                          fontWeight: light ? FontWeight.w400 : FontWeight.w500,
                          color: light ? C.muted : C.label)),
                ),
            ]),
          ),
          if (action != null) ...[const SizedBox(width: 12), action!],
        ]),
      );
}

/// "ZINAZOUZIKA ZAIDI" / "GHARAMA" n.k.
class SectionTitle extends StatelessWidget {
  final String text;
  final String? trailing;
  final Color color;
  final FontWeight weight;
  final EdgeInsets padding;
  const SectionTitle(this.text,
      {super.key,
      this.trailing,
      this.color = C.heading,
      this.weight = FontWeight.w600,
      this.padding = const EdgeInsets.fromLTRB(2, 24, 2, 8)});
  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(children: [
          Expanded(
              child: Text(text.toUpperCase(),
                  style: Txt.section.copyWith(color: color, fontWeight: weight))),
          if (trailing != null)
            Text(trailing!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.label)),
        ]),
      );
}

/// Kadi nyeupe yenye mpaka hafifu
class Box extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? border;
  final double radius;
  final VoidCallback? onTap;
  const Box({super.key, required this.child, this.padding = EdgeInsets.zero, this.color, this.border, this.radius = 14, this.onTap});
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final content = Padding(padding: padding, child: child);
    return Material(
      color: color ?? Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: r, side: BorderSide(color: border ?? C.line)),
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// Vidoti vitatu vinavyocheza (badala ya mzunguko)
class DotsLoader extends StatefulWidget {
  final Color color;
  final double size;
  const DotsLoader({super.key, this.color = C.blue, this.size = 6});
  @override
  State<DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<DotsLoader> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final y = -4.0 * math.max(0.0, math.sin(_c.value * 2 * math.pi - i * .8));
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.size * .35),
              child: Transform.translate(
                offset: Offset(0, y),
                child: Container(width: widget.size, height: widget.size, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
              ),
            );
          }),
        ),
      );
}

/// Kitufe KIDOGO chembamba (Hifadhi / Hariri / Tengeneza risiti / Pakua PDF)
class SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  final Color color;
  final Widget? icon;
  final bool filled; // true = bluu iliyojaa, maandishi meupe
  final double height;
  final Color? borderColor;
  const SmallButton(this.label,
      {super.key, this.onTap, this.busy = false, this.color = C.blue, this.icon, this.filled = false, this.height = 30, this.borderColor});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: height,
          constraints: const BoxConstraints(minWidth: 70),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor ?? color),
            color: filled ? color : null,
          ),
          alignment: Alignment.center,
          child: busy
              ? DotsLoader(color: filled ? Colors.white : color)
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 6)],
                  Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: filled ? Colors.white : color)),
                ]),
        ),
      );
}

/// Kitufe cha juu kulia chenye MAANDISHI ("+ Bidhaa", "+ Aina", "+ Risiti"):
/// mpaka wa accent 1.5px, radius 10, urefu 40, padding 0 14, 16/w700.
class HeaderButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  /// Rangi ya maandishi na mpaka (kitufe cha pili kwenye kichwa: kijivu).
  final Color color;
  final double height;
  final double borderWidth;
  final double padding;
  final double fontSize;
  final FontWeight weight;
  const HeaderButton(this.label,
      {super.key,
      this.onTap,
      this.color = C.blue,
      this.height = 40,
      this.borderWidth = 1.5,
      this.padding = 14,
      this.fontSize = 16,
      this.weight = FontWeight.w700});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: padding),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: borderWidth),
          ),
          child: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: weight, color: color)),
        ),
      );
}

/// Kitufe cha ikoni kwenye kichwa: MRABA 42, radius 10, mpaka mwembamba.
class HeaderIconButton extends StatelessWidget {
  final String svg;
  final VoidCallback? onTap;
  final Color color;
  const HeaderIconButton(this.svg, {super.key, this.onTap, this.color = C.text});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: C.cardLine),
          ),
          child: Center(child: AppIcon(svg, size: 21, color: color)),
        ),
      );
}

/// Kitufe cha juu kulia ("+ Bidhaa mpya", "+ Aina", "+ Risiti mpya")
class TopButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const TopButton(this.label, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: C.blue, width: 1.3)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add, size: 17, color: C.blue),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: C.blue)),
          ]),
        ),
      );
}

/// Vichupo vya kijivu (Wiki/Mwezi/Mwaka) — kidonge cheupe kinateleza
class Segmented extends StatelessWidget {
  final List<String> items;
  final int index;
  final ValueChanged<int> onChanged;
  const Segmented({super.key, required this.items, required this.index, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: C.rankBg, borderRadius: BorderRadius.circular(12)),
        child: LayoutBuilder(builder: (c, b) {
          final w = b.maxWidth / items.length;
          return Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: w * index,
              top: 0,
              bottom: 0,
              width: w,
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1))]),
              ),
            ),
            Row(children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Text(items[i],
                          textAlign: TextAlign.center,
                          style: i == index ? Txt.tabOn : Txt.tab),
                    ),
                  ),
                ),
            ]),
          ]);
        }),
      );
}

/// Kichupo chenye mstari chini (Stock | Vilivyouzwa leo)
class UnderlineTabs extends StatelessWidget {
  final List<String> items;
  final List<String?> counts;
  final int index;
  final ValueChanged<int> onChanged;
  const UnderlineTabs({super.key, required this.items, required this.counts, required this.index, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
        child: LayoutBuilder(builder: (c, b) {
          final w = b.maxWidth / items.length;
          return Stack(children: [
            Row(children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: items[i]),
                          if (counts[i] != null) TextSpan(text: '  ${counts[i]}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14.5, fontWeight: i == index ? FontWeight.w800 : FontWeight.w600, color: i == index ? C.blue : C.muted),
                      ),
                    ),
                  ),
                ),
            ]),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              left: w * index,
              bottom: 0,
              width: w,
              child: Container(height: 2.5, color: C.blue),
            ),
          ]);
        }),
      );
}

/// Mstari wa hesabu (Mauzo ... 364,000)
class StatRow extends StatelessWidget {
  final String label;
  final int value;
  final bool bold;
  final bool topLine; // mstari mweusi juu (jumla)
  final bool blue;
  final bool doubleUnder;
  final String? sub;
  final double size;
  const StatRow(this.label, this.value, {super.key, this.bold = false, this.topLine = false, this.blue = false, this.doubleUnder = false, this.sub, this.size = 14.5});
  @override
  Widget build(BuildContext context) {
    final v = Text(money(value),
        style: TextStyle(fontSize: size, fontWeight: bold ? FontWeight.w800 : FontWeight.w400, color: blue ? C.blue : (bold ? C.text : C.text2), fontFeatures: tabular));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: topLine ? C.text : C.line))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: size, fontWeight: bold ? FontWeight.w800 : FontWeight.w400, color: bold ? C.text : C.text2)),
            if (sub != null) Text(sub!, style: const TextStyle(fontSize: 11, color: C.muted)),
          ]),
        ),
        doubleUnder
            ? Container(
                padding: const EdgeInsets.only(bottom: 2),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.blue, width: 3, style: BorderStyle.solid))),
                child: v,
              )
            : v,
      ]),
    );
  }
}

/// Hesabu rasmi: Mauzo -> Mtaji -> Faida ya bidhaa -> Gharama -> Faida halisi
class Statement extends StatelessWidget {
  final int sales, capital, expenses;
  final String netLabel;
  final String? salesSub;
  const Statement({super.key, required this.sales, required this.capital, required this.expenses, this.netLabel = 'Faida halisi ya leo', this.salesSub});
  @override
  Widget build(BuildContext context) {
    final rows = <(String, int)>[
      ('Mauzo', sales),
      ('Mtaji wa vilivyouzwa', capital),
      ('Faida ya bidhaa', sales - capital),
      ('Gharama', expenses),
      (netLabel, sales - capital - expenses),
    ];
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.cardLine)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (final (i, r) in rows.indexed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: i == rows.length - 1 ? C.blue3 : null,
              border: i == 0 ? null : Border(top: BorderSide(color: i == rows.length - 1 ? C.blueLine : C.line)),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  r.$1,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: i == rows.length - 1 ? FontWeight.w700 : FontWeight.w500,
                    color: i == rows.length - 1 ? C.blue : C.text2,
                  ),
                ),
              ),
              Text(
                money(r.$2),
                style: TextStyle(
                  fontSize: i == rows.length - 1 ? 15.5 : 14.5,
                  fontWeight: i == rows.length - 1 ? FontWeight.w800 : FontWeight.w600,
                  // Gharama 0 inaonekana kijivu kama kwenye muundo
                  color: i == rows.length - 1 ? C.blue : (r.$2 == 0 ? C.muted : C.text),
                  fontFeatures: tabular,
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

/// Kichwa cha jedwali (bluu, mstari mweusi chini)
class TableHead extends StatelessWidget {
  final List<String> cols;
  final List<double?> widths; // null = Expanded
  const TableHead(this.cols, this.widths, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.text, width: 1.5))),
        child: Row(children: [
          for (var i = 0; i < cols.length; i++)
            _cell(widths[i], Text(cols[i], textAlign: (i == 0 || widths[i] == null) ? TextAlign.left : TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: C.blue, letterSpacing: .4))),
        ]),
      );
}

Widget _cell(double? w, Widget child) => w == null ? Expanded(child: child) : SizedBox(width: w, child: child);
Widget tableCell(double? w, Widget child) => _cell(w, child);

/// Kisanduku cha kuandika (dirisha, mteja n.k.)
class Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode? focus;
  final String hint;
  final bool number;
  final bool money;
  final bool readOnly;
  final TextInputAction action;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool showLabel; // false = hakuna lebo juu, hint tu ndani ya kisanduku
  const Field({
    super.key,
    required this.label,
    required this.controller,
    this.focus,
    this.hint = '',
    this.number = false,
    this.money = false,
    this.readOnly = false,
    this.action = TextInputAction.next,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
    this.showLabel = true,
  });
  @override
  Widget build(BuildContext context) {
    final b = OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: C.field, width: 1.2));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (showLabel) ...[
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.text2)),
        const SizedBox(height: 6),
      ],
      TextField(
        controller: controller,
        focusNode: focus,
        readOnly: readOnly,
        autofocus: autofocus,
        textInputAction: action,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        keyboardType: number || money ? TextInputType.number : TextInputType.text,
        textCapitalization: number || money ? TextCapitalization.none : TextCapitalization.sentences,
        inputFormatters: [if (number) FilteringTextInputFormatter.digitsOnly, if (money) MoneyInput()],
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: readOnly ? C.muted : C.text, fontFeatures: tabular),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(color: C.faint, fontWeight: FontWeight.w500),
          filled: true,
          fillColor: readOnly ? const Color(0xFFF6F7F9) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
          enabledBorder: b,
          border: b,
          focusedBorder: b.copyWith(borderSide: const BorderSide(color: C.blue, width: 1.8)),
        ),
      ),
    ]);
  }
}

/// 25000 -> "25,000" wakati wa kuandika
class MoneyInput extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final s = money(int.parse(digits));
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

/// Kisanduku kidogo ndani ya mstari wa daftari (mpaka wa bluu)
class InlineInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final bool number;
  final TextAlign align;
  final String hint;

  /// true = kisanduku kinaonekana hata kisipoguswa (mstari wa kijivu). false = kinaonekana kama maandishi tu mpaka ukiguse.
  final bool outlined;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  const InlineInput({super.key, required this.controller, required this.focus, this.number = false, this.align = TextAlign.right, this.hint = '', this.outlined = false, this.onChanged, this.onSubmitted});
  @override
  Widget build(BuildContext context) {
    final on = OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C.blue, width: 1.6));
    final idle = OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: outlined ? C.field : Colors.transparent, width: 1));
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        focusNode: focus,
        textAlign: align,
        textInputAction: TextInputAction.next,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        textCapitalization: number ? TextCapitalization.none : TextCapitalization.sentences,
        inputFormatters: [if (number) MoneyInput()],
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFeatures: tabular),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(color: C.faint, fontWeight: FontWeight.w400),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          filled: true,
          // kisanduku cheupe tu kikiwa kinaandikwa au kikiwa "outlined"; vinginevyo kinachanganyika na mstari
          fillColor: (focus.hasFocus || outlined) ? Colors.white : Colors.transparent,
          enabledBorder: idle,
          border: idle,
          focusedBorder: on,
        ),
      ),
    );
  }
}

// ======================================================================= dirisha katikati

/// Dirisha la katikati lenye ✕ (linakaa katikati juu ya keyboard)
Future<T?> showCenterDialog<T>(BuildContext context,
    {required WidgetBuilder builder, bool dismissible = true, double radius = 22, Color? border}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'funga',
    barrierColor: const Color(0x730B1220),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, a1, a2) => _CenterShell(radius: radius, border: border, child: builder(ctx)),
    transitionBuilder: (ctx, a, b, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: c, child: ScaleTransition(scale: Tween(begin: .92, end: 1.0).animate(c), child: child));
    },
  );
}

class _CenterShell extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color? border;
  const _CenterShell({required this.child, this.radius = 22, this.border});
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom, top: mq.padding.top + 8),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(color: border ?? Colors.transparent, width: border == null ? 0 : 1.2),
            ),
            elevation: 18,
            shadowColor: const Color(0x33000000),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 520, maxHeight: mq.size.height - mq.viewInsets.bottom - mq.padding.top - 40),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dirisha la chini (kama Mauzo/Risiti): hukaa 10px juu ya kibodi.
Future<T?> showEntryDialog<T>(BuildContext context,
    {required WidgetBuilder builder, double radius = 14, Color border = C.winBorder}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'funga',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, a1, a2) => _EntryShell(radius: radius, border: border, child: builder(ctx)),
    transitionBuilder: (ctx, a, b, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: c,
        child: SlideTransition(position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(c), child: child),
      );
    },
  );
}

class _EntryShell extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color border;
  const _EntryShell({required this.child, this.radius = 14, this.border = C.winBorder});
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(12, mq.padding.top + 16, 12, mq.viewInsets.bottom + 10),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: math.max(200, mq.size.height - mq.padding.top - mq.viewInsets.bottom - 26),
          ),
          child: Material(
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: border)),
            elevation: 18,
            shadowColor: const Color(0x33000000),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Kichwa cha dirisha la chini: jina 15.5/w700 + ✕ 30
class EntryHeader extends StatelessWidget {
  final String title;
  final String? sub;
  const EntryHeader(this.title, {super.key, this.sub});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
            if (sub != null) Text(sub!, style: const TextStyle(fontSize: 11.5, color: C.muted)),
          ]),
        ),
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.line)),
            child: const Icon(Icons.close_rounded, size: 16, color: C.text),
          ),
        ),
      ]);
}

/// Kichwa cha dirisha: jina + ✕
class DialogHeader extends StatelessWidget {
  final String title;
  final String? over; // maandishi madogo juu ya jina (mf. "KANZU")
  final String? sub;
  const DialogHeader(this.title, {super.key, this.over, this.sub});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (over != null) Text(over!.toUpperCase(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.muted, letterSpacing: .6)),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub!, style: const TextStyle(fontSize: 13, color: C.muted))),
          ]),
        ),
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(8),
          child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.close, size: 18, color: C.text2)),
        ),
      ]);
}

/// Thibitisha kufuta (Ghairi / Futa)
Future<bool> confirmDelete(BuildContext context, {required String title, required String message}) async {
  final r = await showCenterDialog<bool>(
    context,
    builder: (c) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 18, 12),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(message, style: const TextStyle(fontSize: 14, color: C.muted, height: 1.45)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Ghairi', style: TextStyle(color: C.muted, fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Futa', style: TextStyle(color: C.red, fontWeight: FontWeight.w700))),
        ]),
      ]),
    ),
  );
  return r == true;
}

/// Ujumbe mdogo wa kosa (bila toast kubwa)
void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.white,
      elevation: 4,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: C.redLine)),
      content: Text('$e', style: const TextStyle(color: C.red, fontWeight: FontWeight.w600)),
    ));
}

/// Ukurasa tupu (Chaguo A): duara la bluu hafifu + icon nyeusi, kichwa, maelezo, vitufe vidogo
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final List<Widget> actions;
  const EmptyState({super.key, required this.icon, required this.title, required this.text, this.actions = const []});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 46, 20, 24),
        child: Column(children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: C.blue2, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: C.text),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: C.muted, height: 1.5)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: actions),
          ],
        ]),
      );
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(40), child: DotsLoader(size: 8)));
}

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorView(this.error, {super.key, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$error', textAlign: TextAlign.center, style: const TextStyle(color: C.red)),
            const SizedBox(height: 12),
            SmallButton('Jaribu tena', onTap: onRetry),
          ]),
        ),
      );
}

/// Maandishi ya kosa ndani ya dirisha (nyekundu 12.5/w600) — hakuna toast
class ErrorText extends StatelessWidget {
  final String text;
  const ErrorText(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.red)),
      );
}

/// Kadi ya takwimu ndogo (ZIPO / BUYING ...)
class MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const MiniStat(this.label, this.value, {super.key, this.bold = false, this.color});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: .4, fontWeight: FontWeight.w500, color: C.muted)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color ?? (value == '–' ? const Color(0xFFCBD5E1) : C.text), fontFeatures: tabular)),
      ]);
}

/// Kisanduku cha fomu kionekane juu ya kibodi.
/// Uiite kwenye listener ya FocusNode; fomu inajisogeza yenyewe hadi
/// kisanduku kilichogusiwa (pamoja na kitufe cha Hifadhi) kionekane.
void keepFieldInView(FocusNode node, {double alignment = .35}) {
  if (!node.hasFocus) return;
  void run() {
    final c = node.context;
    if (c == null || !c.mounted) return;
    Scrollable.ensureVisible(c,
        alignment: alignment, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
  }

  WidgetsBinding.instance.addPostFrameCallback((_) => run());
  // Kibodi huchukua muda kupanda; tunasogeza tena baada ya kupanda.
  Future.delayed(const Duration(milliseconds: 320), run);
}

/// Kisanduku kidogo cha dirisha: lebo juu (11.5), kisanduku cha urefu 38, radius 8
class DialogField extends StatelessWidget {
  final String? label;
  final TextEditingController controller;
  final FocusNode? focus;
  final String hint;
  final bool number;
  final bool money;
  final TextAlign align;
  final double? width;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  const DialogField({
    super.key,
    this.label,
    required this.controller,
    this.focus,
    this.hint = '',
    this.number = false,
    this.money = false,
    this.align = TextAlign.left,
    this.width,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: c, width: w));
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label != null) ...[
        Text(label!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: C.muted)),
        const SizedBox(height: 4),
      ],
      SizedBox(
        width: width,
        height: 38,
        child: TextField(
          controller: controller,
          focusNode: focus,
          autofocus: autofocus,
          textAlign: align,
          // Kisanduku cha fedha (kulia) hupanga maandishi RTL ili mshale uanze
          // upande wa kulia hata kisanduku kikiwa kitupu; namba zinaonekana
          // sawa sawa (40,000) kwa sababu zinabaki LTR.
          textDirection: align == TextAlign.right ? TextDirection.rtl : TextDirection.ltr,
          textInputAction: TextInputAction.next,
          keyboardType: number || money ? TextInputType.number : TextInputType.text,
          textCapitalization: number || money ? TextCapitalization.none : TextCapitalization.sentences,
          inputFormatters: [if (number) FilteringTextInputFormatter.digitsOnly, if (money) MoneyInput()],
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, fontFeatures: tabular),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(color: C.faint, fontWeight: FontWeight.w400),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            enabledBorder: b(C.field, 1),
            focusedBorder: b(C.blue, 1.5),
            border: b(C.field, 1),
          ),
        ),
      ),
    ]);
  }
}

/// Kitufe kikuu cha bluu (Hifadhi ›) — kinafifia kama sehemu hazijajaa
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  const PrimaryButton(this.label, {super.key, this.onTap, this.busy = false});
  @override
  Widget build(BuildContext context) {
    final on = onTap != null && !busy;
    return Opacity(
      opacity: on || busy ? 1 : .4,
      child: InkWell(
        onTap: on ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 34,
          padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
          decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(width: 2),
            if (busy)
              const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: DotsLoader(color: Colors.white, size: 4))
            else
              const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
          ]),
        ),
      ),
    );
  }
}

/// Mstari wa hesabu ndogo (Mtaji 776,000 · Faida 278,000)
class CalcStrip extends StatelessWidget {
  final String a;
  final String b;
  const CalcStrip(this.a, this.b, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Expanded(child: Text(a, style: const TextStyle(fontSize: 13.5, color: C.muted, fontFeatures: tabular))),
          Text(b, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, fontFeatures: tabular)),
        ]),
      );
}
