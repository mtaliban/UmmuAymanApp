import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';

/// UKURASA WA BIDHAA (mf. Kanzu)
///  - Juu kulia: "+ Aina" -> dirisha katikati (jina, idadi, buying, selling)
///  - Idadi · Mtaji · Faida ukiuza
///  - Kila aina ni kadi: Zipo/Buying/Selling + Faida kimoja/Mtaji/Faida zote
///  - Gusa kadi -> dirisha: Ongeza idadi, badilisha bei, "Futa aina hii"
///  - Bidhaa isiyo na aina: kadi moja + "+ Aina" ikipata aina baadaye
class ProductScreen extends StatefulWidget {
  final String productId;
  const ProductScreen({super.key, required this.productId});
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  Product? _p;
  Object? _error;
  String? _hl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await Api.i.products();
      final p = list.where((x) => x.id == widget.productId).toList();
      if (!mounted) return;
      if (p.isEmpty) {
        Navigator.pop(context);
        return;
      }
      setState(() {
        _p = p.first;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _addType() async {
    final v = await showCenterDialog<Variant>(context, builder: (_) => _AddTypeDialog(_p!));
    if (v != null) {
      _hl = v.id;
      await _load();
    }
  }

  Future<void> _edit(Variant v) async {
    final changed = await showCenterDialog<bool>(context, builder: (_) => _EditTypeDialog(product: _p!, v: v));
    if (changed == true) {
      _hl = v.id;
      await _load();
    }
  }

  Future<void> _deleteProduct() async {
    final p = _p!;
    if (await confirmDelete(context, title: 'Futa ${p.name}?', message: 'Bidhaa hii${p.hasTypes ? ' na aina zake zote' : ''} (idadi ${p.qty}) itaondolewa kwenye stock.')) {
      try {
        await Api.i.deleteProduct(p.id);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      appBar: pageBar(p?.name ?? '', subtitle: p == null ? null : 'aina ${p.variants.length}', back: true),
      body: _error != null
          ? ErrorView(_error!, onRetry: _load)
          : p == null
              ? const Loading()
              : RefreshIndicator(
                  color: C.blue,
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
                    Box(
                      radius: 16,
                      child: IntrinsicHeight(
                        child: Row(children: [
                          Expanded(child: _top('Idadi', '${p.qty}')),
                          const VerticalDivider(width: 1, color: C.line),
                          Expanded(child: _top('Mtaji', money(p.capital))),
                          const VerticalDivider(width: 1, color: C.line),
                          Expanded(child: _top('Faida ukiuza', money(p.profitAll))),
                        ]),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 18, 0, 10),
                      child: Row(children: [
                        const Expanded(child: Text('AINA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .9))),
                        TopButton('Aina', onTap: _addType),
                      ]),
                    ),
                    for (final v in p.variants) ...[
                      _TypeCard(v, highlight: v.id == _hl, onTap: () => _edit(v)),
                      const SizedBox(height: 8),
                    ],
                    if (!p.hasTypes)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Bidhaa hii haina aina. Ikipata aina, bonyeza "+ Aina" juu.', style: TextStyle(fontSize: 12.5, color: C.muted)),
                      ),
                    const SizedBox(height: 26),
                    Center(
                      child: TextButton(
                        onPressed: _deleteProduct,
                        child: Text('Futa ${p.name}', style: const TextStyle(color: C.red, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ),
    );
  }

  Widget _top(String l, String v) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: const TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          FittedBox(child: Text(v, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, fontFeatures: tabular))),
        ]),
      );
}

class _TypeCard extends StatelessWidget {
  final Variant v;
  final bool highlight;
  final VoidCallback onTap;
  const _TypeCard(this.v, {required this.highlight, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final out = v.qty == 0;
    return Box(
      onTap: onTap,
      color: highlight ? C.blue3 : null,
      border: highlight ? C.blue : (out ? C.redLine : null),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: MiniStat('Zipo', '${v.qty}', bold: true, color: out ? C.red : null)),
          Expanded(child: MiniStat('Buying', money(v.buying))),
          Expanded(child: MiniStat('Selling', money(v.selling))),
          Expanded(child: MiniStat('Faida', money(v.profitEach), bold: true, color: C.blue)),
        ]),
      ]),
    );
  }
}

class _AddTypeDialog extends StatefulWidget {
  final Product p;
  const _AddTypeDialog(this.p);
  @override
  State<_AddTypeDialog> createState() => _AddTypeDialogState();
}

class _AddTypeDialogState extends State<_AddTypeDialog> {
  final _n = TextEditingController(), _q = TextEditingController(), _b = TextEditingController(), _s = TextEditingController();
  final _fq = FocusNode(), _fb = FocusNode(), _fs = FocusNode();
  bool _busy = false;

  Future<void> _save() async {
    if (_n.text.trim().isEmpty) {
      showError(context, 'Andika jina la aina');
      return;
    }
    setState(() => _busy = true);
    try {
      final v = await Api.i.addVariant(widget.p.id, name: _n.text.trim(), qty: parseMoney(_q.text), buying: parseMoney(_b.text), selling: parseMoney(_s.text));
      if (mounted) Navigator.pop(context, v);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = parseMoney(_q.text), b = parseMoney(_b.text), s = parseMoney(_s.text);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DialogHeader('Aina mpya ya ${widget.p.name}'),
        const SizedBox(height: 14),
        Field(label: 'Jina la aina', showLabel: false, controller: _n, autofocus: true, hint: 'Mfano: ${widget.p.name} ya Morocco', onSubmitted: (_) => _fq.requestFocus()),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          DialogField(label: 'Idadi', controller: _q, focus: _fq, number: true, hint: '0', width: 56, align: TextAlign.center, onChanged: (_) => setState(() {}), onSubmitted: (_) => _fb.requestFocus()),
          const SizedBox(width: 8),
          Expanded(child: DialogField(label: 'Buying', controller: _b, focus: _fb, money: true, hint: '0', onChanged: (_) => setState(() {}), onSubmitted: (_) => _fs.requestFocus())),
          const SizedBox(width: 8),
          Expanded(child: DialogField(label: 'Selling', controller: _s, focus: _fs, money: true, hint: '0', onChanged: (_) => setState(() {}), onSubmitted: (_) => _save())),
          const SizedBox(width: 8),
          PrimaryButton('Hifadhi', busy: _busy, onTap: _n.text.trim().isEmpty ? null : _save),
        ]),
        if (q > 0 || b > 0 || s > 0) ...[
          const SizedBox(height: 10),
          CalcStrip('Mtaji ${money(q * b)}', 'Faida ${money(q * (s - b))}'),
        ],
        const SizedBox(height: 4),
      ]),
    );
  }
}

class _EditTypeDialog extends StatefulWidget {
  final Product product;
  final Variant v;
  const _EditTypeDialog({required this.product, required this.v});
  @override
  State<_EditTypeDialog> createState() => _EditTypeDialogState();
}

class _EditTypeDialogState extends State<_EditTypeDialog> {
  late final _zipo = TextEditingController(text: '${widget.v.qty}');
  final _add = TextEditingController();
  late final _b = TextEditingController(text: money(widget.v.buying));
  late final _s = TextEditingController(text: money(widget.v.selling));
  final _fb = FocusNode(), _fs = FocusNode();
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await Api.i.updateVariant(widget.v.id, addQty: parseMoney(_add.text), buying: parseMoney(_b.text), selling: parseMoney(_s.text));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final single = !widget.product.hasTypes;
    final ok = await confirmDelete(context,
        title: 'Futa ${widget.v.name}?', message: '${single ? 'Bidhaa' : 'Aina'} hii na idadi yake (${widget.v.qty}) zitaondolewa kwenye stock.');
    if (!ok) return;
    try {
      if (single) {
        await Api.i.deleteProduct(widget.product.id);
      } else {
        await Api.i.deleteVariant(widget.v.id);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final add = parseMoney(_add.text), b = parseMoney(_b.text), s = parseMoney(_s.text);
    final after = widget.v.qty + add;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DialogHeader(widget.v.name, over: widget.product.hasTypes ? widget.product.name : null),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 76, child: Field(label: 'Zipo', controller: _zipo, readOnly: true)),
          const SizedBox(width: 8),
          Expanded(child: Field(label: 'Ongeza idadi', controller: _add, number: true, hint: '0', autofocus: true, onChanged: (_) => setState(() {}), onSubmitted: (_) => _fb.requestFocus())),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Field(label: 'Buying', controller: _b, focus: _fb, money: true, onChanged: (_) => setState(() {}), onSubmitted: (_) => _fs.requestFocus())),
          const SizedBox(width: 8),
          Expanded(child: Field(label: 'Selling', controller: _s, focus: _fs, money: true, action: TextInputAction.done, onChanged: (_) => setState(() {}), onSubmitted: (_) => _save())),
        ]),
        const SizedBox(height: 10),
        CalcStrip('Zitakuwa ${widget.v.qty} → $after', 'Faida ukiuza ${money(after * (s - b))}'),
        const SizedBox(height: 12),
        Row(children: [
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
            child: Text(widget.product.hasTypes ? 'Futa aina hii' : 'Futa bidhaa hii', style: const TextStyle(color: C.red, fontWeight: FontWeight.w700, fontSize: 13.5)),
          ),
          const Spacer(),
          SmallButton('Hifadhi', busy: _busy, onTap: _save),
        ]),
      ]),
    );
  }
}
