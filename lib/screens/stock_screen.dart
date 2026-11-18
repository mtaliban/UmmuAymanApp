import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';
import 'product_screen.dart';

/// STOCK
///  - Juu: Jumla ya bidhaa · Mtaji dukani
///  - Vigae vya bidhaa/makundi (jina, "aina 4", idadi, mtaji)
///  - "+ Bidhaa mpya" juu kulia -> dirisha katikati (Haina aina / Ina aina)
///  - Gusa kigae -> ukurasa wa bidhaa (aina zake, + Aina, hariri, futa)
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  late Future<List<Product>> _f;
  String? _highlight;

  @override
  void initState() {
    super.initState();
    _f = Api.i.products();
  }

  void _reload() => setState(() => _f = Api.i.products());

  Future<void> _new() async {
    final p = await showCenterDialog<Product>(context, builder: (_) => const NewProductDialog());
    if (p == null) return;
    _highlight = p.id;
    _reload();
    if (p.hasTypes && mounted) {
      // ina aina -> fungua ukurasa wake moja kwa moja ili aongeze aina
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductScreen(productId: p.id)));
      _reload();
    }
  }

  Future<void> _open(Product p) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductScreen(productId: p.id)));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Stock', action: TopButton('Bidhaa mpya', onTap: _new)),
      body: FutureBuilder<List<Product>>(
        future: _f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Loading();
          if (s.hasError) return ErrorView(s.error!, onRetry: _reload);
          final list = s.data!;
          final qty = list.fold<int>(0, (a, p) => a + p.qty);
          final cap = list.fold<int>(0, (a, p) => a + p.capital);
          return RefreshIndicator(
            color: C.blue,
            onRefresh: () async => _reload(),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
              Box(
                radius: 16,
                child: IntrinsicHeight(
                  child: Row(children: [
                    Expanded(child: _top('Jumla ya bidhaa', '$qty')),
                    const VerticalDivider(width: 1, color: C.line),
                    Expanded(child: _top('Mtaji dukani', money(cap), blue: true)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              if (list.isEmpty)
                const Padding(padding: EdgeInsets.all(30), child: Text('Bado huna bidhaa. Bonyeza "+ Bidhaa mpya" juu.', textAlign: TextAlign.center, style: TextStyle(color: C.muted))),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 116),
                itemBuilder: (_, i) {
                  final p = list[i];
                  final hl = p.id == _highlight;
                  final out = p.variants.any((v) => v.qty == 0);
                  return Box(
                    radius: 16,
                    color: hl ? C.blue3 : null,
                    border: hl ? C.blue : null,
                    padding: const EdgeInsets.all(14),
                    onTap: () => _open(p),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                        if (p.hasTypes) Text('aina ${p.variants.length}', style: const TextStyle(fontSize: 11.5, color: C.muted)),
                      ]),
                      const SizedBox(height: 4),
                      Text('${p.qty}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: p.qty == 0 ? C.red : C.text, fontFeatures: tabular)),
                      Text('mtaji ${money(p.capital)}${out && p.qty > 0 ? ' · 1 imeisha' : ''}', style: const TextStyle(fontSize: 11.5, color: C.muted)),
                    ]),
                  );
                },
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _top(String l, String v, {bool blue = false}) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: const TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(v, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: blue ? C.blue : C.text, fontFeatures: tabular)),
        ]),
      );
}

/// Dirisha: Bidhaa mpya (Haina aina -> idadi/bei hapa hapa; Ina aina -> aina baadaye)
class NewProductDialog extends StatefulWidget {
  const NewProductDialog({super.key});
  @override
  State<NewProductDialog> createState() => _NewProductDialogState();
}

class _NewProductDialogState extends State<NewProductDialog> {
  final _name = TextEditingController();
  final _qty = TextEditingController();
  final _buy = TextEditingController();
  final _sell = TextEditingController();
  final _fQty = FocusNode(), _fBuy = FocusNode(), _fSell = FocusNode();
  bool _hasTypes = false;
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final p = await Api.i.createProduct(
        name: _name.text.trim(),
        hasTypes: _hasTypes,
        qty: parseMoney(_qty.text),
        buying: parseMoney(_buy.text),
        selling: parseMoney(_sell.text),
      );
      if (mounted) Navigator.pop(context, p);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = parseMoney(_qty.text), b = parseMoney(_buy.text), s = parseMoney(_sell.text);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const DialogHeader('Bidhaa mpya'),
        const SizedBox(height: 14),
        Field(label: 'Jina la bidhaa', controller: _name, hint: 'Mfano: Mafuta ya nywele', autofocus: true, onSubmitted: (_) {
          if (!_hasTypes) _fQty.requestFocus();
        }),
        const SizedBox(height: 12),
        Row(children: [
          for (final (i, t) in ['Haina aina', 'Ina aina'].indexed) ...[
            if (i == 1) const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _hasTypes = i == 1),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _hasTypes == (i == 1) ? C.blue3 : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _hasTypes == (i == 1) ? C.blue : const Color(0xFFE5E7EB), width: 1.4),
                  ),
                  child: Text(t, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _hasTypes == (i == 1) ? C.blue : C.text2)),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 12),
        if (!_hasTypes) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 76, child: Field(label: 'Idadi', controller: _qty, focus: _fQty, number: true, hint: '0', onChanged: (_) => setState(() {}), onSubmitted: (_) => _fBuy.requestFocus())),
            const SizedBox(width: 8),
            Expanded(child: Field(label: 'Buying', controller: _buy, focus: _fBuy, money: true, hint: '0', onChanged: (_) => setState(() {}), onSubmitted: (_) => _fSell.requestFocus())),
            const SizedBox(width: 8),
            Expanded(child: Field(label: 'Selling', controller: _sell, focus: _fSell, money: true, hint: '0', action: TextInputAction.done, onChanged: (_) => setState(() {}), onSubmitted: (_) => _save())),
          ]),
          const SizedBox(height: 10),
          _calcStrip('Mtaji ${money(q * b)}', 'Faida ${money(q * (s - b))}'),
        ] else
          const Text('Utaongeza aina zake ukishahifadhi.', style: TextStyle(fontSize: 13, color: C.muted)),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerRight, child: SmallButton('Hifadhi', busy: _busy, onTap: _save)),
      ]),
    );
  }
}

Widget _calcStrip(String a, String b) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(child: Text(a, style: const TextStyle(fontSize: 13.5, color: C.muted, fontFeatures: tabular))),
        Text(b, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, fontFeatures: tabular)),
      ]),
    );
Widget calcStrip(String a, String b) => _calcStrip(a, b);
