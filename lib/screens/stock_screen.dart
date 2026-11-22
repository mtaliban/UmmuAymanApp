import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';
import 'product_screen.dart';

/// STOCK (K0 · S01, S02, S06, S10, S11)
///  - Kichwa: "Stock" + "Bidhaa 9 · aina 22" + "+ Bidhaa"
///  - Kutafuta kunachuja orodha papo hapo (hakuna API), muhtasari unafichwa
///  - Gridi kadi 2 kwa mstari: jina · aina N · zipo · mtaji
///  - Gusa kadi → ukurasa wa bidhaa; bidhaa mpya yenye aina → ukurasa wake
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  late Future<StockList> _f = Api.i.stock();
  final _q = TextEditingController();
  String? _newId;

  void _reload() => setState(() => _f = Api.i.stock());

  Future<void> _new() async {
    final p = await showEntryDialog<StockProduct>(context, builder: (_) => const NewProductDialog());
    if (p == null || !mounted) return;
    setState(() => _newId = p.id);
    _reload();
    if (p.hasVariants) {
      // S07: fungua bidhaa mpya ili kuongeza aina
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductScreen(productId: p.id, initial: p)));
      _reload();
    }
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _newId = null);
    });
  }

  Future<void> _open(StockItem p) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductScreen(productId: p.id)));
    _reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<StockList>(
        future: _f,
        builder: (c, s) {
          final list = s.connectionState == ConnectionState.done ? s.data : null;
          return Scaffold(
            appBar: pageBar(
              'Stock',
              subtitle: list == null ? null : 'Bidhaa ${list.products} · aina ${list.variants}',
              drop: true,
              // Kitufe chenye maandishi: "+ Bidhaa" (outline ya accent, 40 juu).
              action: HeaderButton('+ Bidhaa', onTap: _new),
            ),
            body: s.hasError
                ? ErrorView(s.error!, onRetry: _reload)
                : list == null
                    ? const Loading()
                    : _body(list),
          );
        },
      );

  Widget _body(StockList list) {
    final q = _q.text.trim().toLowerCase();
    final searching = q.isNotEmpty;
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final shown = searching
        ? list.items.where((p) {
            final n = p.name.toLowerCase().split(RegExp(r'\s+'));
            return words.every((w) => n.any((x) => x.startsWith(w)));
          }).toList()
        : list.items;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 140), children: [
      _SearchField(controller: _q, onChanged: () => setState(() {})),
      if (!searching) ...[
        const SizedBox(height: 12),
        _TwoStat(a: ('Jumla ya bidhaa', '${list.qty}'), b: ('Mtaji dukani', money(list.capital))),
      ],
      SectionTitle(searching ? 'Matokeo' : 'Bidhaa', trailing: '${shown.length}', padding: const EdgeInsets.fromLTRB(2, 18, 2, 10)),
      if (shown.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(child: Text('Hakuna bidhaa inayolingana', style: TextStyle(fontSize: 13, color: C.muted))),
        )
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: shown.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 106),
          itemBuilder: (_, i) => _tile(shown[i]),
        ),
    ]);
  }

  Widget _tile(StockItem p) {
    final hl = p.id == _newId;
    return Box(
      radius: 14,
      color: hl ? C.blue3 : null,
      border: hl ? C.blue : C.cardLine,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () => _open(p),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(p.name,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: C.text)),
          ),
          if (p.hasVariants) Text('aina ${p.variants}', style: const TextStyle(fontSize: 11, color: C.muted)),
        ]),
        const SizedBox(height: 6),
        Text('${p.qty}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500, color: C.text, fontFeatures: tabular)),
        Text('mtaji ${money(p.capital)}', style: const TextStyle(fontSize: 12, color: C.muted)),
      ]),
    );
  }
}

/// Kisanduku cha kutafuta: 44 juu, radius 12, icon ya kioo
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  const _SearchField({required this.controller, required this.onChanged});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: C.text),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Tafuta bidhaa...',
            hintStyle: const TextStyle(fontSize: 13.5, color: C.faint, fontWeight: FontWeight.w400),
            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: C.muted),
            prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 18),
            contentPadding: const EdgeInsets.fromLTRB(0, 13, 12, 13),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.cardLine, width: 1)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.blue, width: 1.5)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.cardLine, width: 1)),
          ),
        ),
      );
}

/// Kadi ya muhtasari: Jumla ya bidhaa · Mtaji dukani (20/w800, bluu)
class _TwoStat extends StatelessWidget {
  final (String, String) a, b;
  const _TwoStat({required this.a, required this.b});
  @override
  Widget build(BuildContext context) => Box(
        radius: 14,
        border: C.cardLine,
        child: IntrinsicHeight(
          child: Row(children: [
            Expanded(child: _cell(a, false)),
            const VerticalDivider(width: 1, color: C.line),
            Expanded(child: _cell(b, true)),
          ]),
        ),
      );

  Widget _cell((String, String) x, bool blue) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(x.$1, style: const TextStyle(fontSize: 11, color: C.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(x.$2,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: blue ? C.blue : C.text, fontFeatures: tabular)),
          ),
        ]),
      );
}

/// Dirisha: Bidhaa mpya (K2 · S06 / S10)
class NewProductDialog extends StatefulWidget {
  const NewProductDialog({super.key});
  @override
  State<NewProductDialog> createState() => _NewProductDialogState();
}

class _NewProductDialogState extends State<NewProductDialog> {
  final _name = TextEditingController(), _qty = TextEditingController(), _buy = TextEditingController(), _sell = TextEditingController();
  final _fName = FocusNode(), _fQty = FocusNode(), _fBuy = FocusNode(), _fSell = FocusNode();
  bool _has = true, _busy = false;
  String? _error;

  bool get _canSave => !_busy && _name.text.trim().isNotEmpty && (_has || (_qty.text.isNotEmpty && _buy.text.isNotEmpty && parseMoney(_sell.text) > 0));

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await Api.i.addStockProduct(
        name: _name.text.trim(),
        hasVariants: _has,
        qty: parseMoney(_qty.text),
        buying: parseMoney(_buy.text),
        selling: parseMoney(_sell.text),
      );
      if (mounted) Navigator.pop(context, p);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final example = _name.text.trim().isEmpty ? 'Mtandio' : _name.text.trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const EntryHeader('Bidhaa mpya'),
        const SizedBox(height: 14),
        DialogField(
          controller: _name,
          focus: _fName,
          hint: 'Jina la bidhaa…',
          autofocus: true,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (_has) {
              _save();
            } else {
              _fQty.requestFocus();
            }
          },
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _ChoiceBtn('Ina aina', selected: _has, onTap: () => setState(() => _has = true))),
          const SizedBox(width: 6),
          Expanded(child: _ChoiceBtn('Haina aina', selected: !_has, onTap: () => setState(() => _has = false))),
        ]),
        if (_has)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Mf. $example → ya hariri, ya pamba… Aina utaziongeza ndani.',
                style: const TextStyle(fontSize: 11.5, color: C.muted, height: 1.4)),
          ),
        const SizedBox(height: 12),
        // Mstari wa kwanza: Idadi · Buying. Mstari wa pili: Selling · Hifadhi.
        if (!_has) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: DialogField(
                  label: 'Idadi', controller: _qty, focus: _fQty, number: true, hint: '0', align: TextAlign.center, onChanged: (_) => setState(() {}), onSubmitted: (_) => _fBuy.requestFocus()),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DialogField(
                  label: 'Buying', controller: _buy, focus: _fBuy, money: true, hint: '0', align: TextAlign.center, onChanged: (_) => setState(() {}), onSubmitted: (_) => _fSell.requestFocus()),
            ),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: DialogField(
                  label: 'Selling', controller: _sell, focus: _fSell, money: true, hint: '0', align: TextAlign.center, onChanged: (_) => setState(() {}), onSubmitted: (_) => _save()),
            ),
            const SizedBox(width: 10),
            PrimaryButton('Hifadhi', onTap: _canSave ? _save : null, busy: _busy),
          ]),
        ] else
          Align(
            alignment: Alignment.centerRight,
            child: PrimaryButton('Hifadhi', onTap: _canSave ? _save : null, busy: _busy),
          ),
        if (_error != null) ErrorText(_error!),
      ]),
    );
  }
}

/// Kitufe cha kuchagua (Ina aina / Haina aina)
class _ChoiceBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceBtn(this.label, {required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? C.blue3 : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? C.blue : const Color(0xFFD1D5DB), width: selected ? 1.5 : 1),
          ),
          child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: selected ? C.blue : C.muted)),
        ),
      );
}
