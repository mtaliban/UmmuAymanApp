import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';
import 'product_screen.dart';

/// STOCK
///  - Kichwa: "Stock" + "Bidhaa 16 · aina 37"
///  - Juu: Jumla ya bidhaa · Mtaji dukani
///  - "BIDHAA" + "+ Bidhaa mpya" -> dirisha katikati (Ina aina / Haina aina)
///  - Vigae vya bidhaa (jina, "aina 4", idadi, mtaji) -> ukurasa wa bidhaa
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
    return FutureBuilder<List<Product>>(
      future: _f,
      builder: (c, s) {
        final done = s.connectionState == ConnectionState.done;
        final list = done && !s.hasError ? s.data : null;
        final sub = list == null ? null : 'Bidhaa ${list.length} · aina ${list.fold<int>(0, (a, p) => a + p.variants.length)}';
        return Scaffold(
          appBar: pageBar('Stock', subtitle: sub),
          body: !done
              ? const Loading()
              : s.hasError
                  ? ErrorView(s.error!, onRetry: _reload)
                  : _body(list!),
        );
      },
    );
  }

  Widget _body(List<Product> list) {
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
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 18, 0, 10),
          child: Row(children: [
            const Expanded(child: Text('BIDHAA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .9))),
            TopButton('Bidhaa mpya', onTap: _new),
          ]),
        ),
        if (list.isEmpty)
          const Padding(padding: EdgeInsets.all(30), child: Text('Bado huna bidhaa. Gusa “+ Bidhaa mpya”.', textAlign: TextAlign.center, style: TextStyle(color: C.muted)))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 104),
            itemBuilder: (_, i) {
              final p = list[i];
              final hl = p.id == _highlight;
              return Box(
                radius: 14,
                color: hl ? C.blue3 : null,
                border: hl ? C.blue : null,
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
                onTap: () => _open(p),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800))),
                    if (p.hasTypes) Text('aina ${p.variants.length}', style: const TextStyle(fontSize: 11.5, color: C.muted)),
                  ]),
                  const SizedBox(height: 3),
                  Text('${p.qty}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: p.qty == 0 ? C.red : C.text, fontFeatures: tabular)),
                  Text('mtaji ${money(p.capital)}', style: const TextStyle(fontSize: 11.5, color: C.muted)),
                ]),
              );
            },
          ),
      ]),
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

/// Dirisha: Bidhaa mpya
///  - Jina -> Ina aina | Haina aina
///  - Ina aina: aina zinaongezwa ndani ya bidhaa baada ya kuhifadhi
///  - Haina aina: Idadi · Buying · Selling -> Hifadhi
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
  final _fName = FocusNode(), _fQty = FocusNode(), _fBuy = FocusNode(), _fSell = FocusNode();
  bool _hasTypes = true;
  bool _busy = false;

  bool get _canSave {
    if (_name.text.trim().isEmpty) return false;
    if (_hasTypes) return true;
    return parseMoney(_qty.text) > 0 && parseMoney(_sell.text) > 0;
  }

  Future<void> _save() async {
    if (!_canSave) return;
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
    final example = _name.text.trim().isEmpty ? 'Kanzu' : _name.text.trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const DialogHeader('Bidhaa mpya'),
        const SizedBox(height: 14),
        Field(
          label: 'Jina',
          showLabel: false,
          controller: _name,
          focus: _fName,
          hint: 'Jina la bidhaa…',
          autofocus: true,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (_hasTypes) {
              _save();
            } else {
              _fQty.requestFocus();
            }
          },
        ),
        const SizedBox(height: 12),
        Row(children: [
          for (final (i, t) in ['Ina aina', 'Haina aina'].indexed) ...[
            if (i == 1) const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _hasTypes = i == 0),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _hasTypes == (i == 0) ? C.blue3 : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _hasTypes == (i == 0) ? C.blue : const Color(0xFFE5E7EB), width: 1.4),
                  ),
                  child: Text(t, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _hasTypes == (i == 0) ? C.blue : C.text2)),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        if (_hasTypes) ...[
          Text('Mf. $example → Alfurqan, Oman… Aina utaiziongeza ndani.', style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.4)),
          const SizedBox(height: 14),
          Align(alignment: Alignment.centerRight, child: PrimaryButton('Hifadhi', onTap: _canSave ? _save : null, busy: _busy)),
        ] else
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            DialogField(label: 'Idadi', controller: _qty, focus: _fQty, number: true, hint: '0', width: 56, align: TextAlign.center, onChanged: (_) => setState(() {}), onSubmitted: (_) => _fBuy.requestFocus()),
            const SizedBox(width: 8),
            Expanded(child: DialogField(label: 'Buying', controller: _buy, focus: _fBuy, money: true, hint: '0', onChanged: (_) => setState(() {}), onSubmitted: (_) => _fSell.requestFocus())),
            const SizedBox(width: 8),
            Expanded(child: DialogField(label: 'Selling', controller: _sell, focus: _fSell, money: true, hint: '0', onChanged: (_) => setState(() {}), onSubmitted: (_) => _save())),
            const SizedBox(width: 8),
            PrimaryButton('Hifadhi', onTap: _canSave ? _save : null, busy: _busy),
          ]),
      ]),
    );
  }
}
