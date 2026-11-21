import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/app_icons.dart';
import '../widgets/ui.dart';

/// UKURASA WA BIDHAA (K1 · S04, S05, S07–S09, S12, S13)
///  - Kichwa: ← · jina · "aina 4" / "haina aina" · + Aina (kama ina aina)
///  - Zipo · Mtaji · Faida ukiuza
///  - Kadi za aina (CHAGUO A): ZIPO · BUYING · SELLING · FAIDA
///  - Gusa kadi → dirisha: Ongeza idadi · Buying · Selling · "Zitakuwa N"
///  - Hakuna kufuta popote; makosa yanaonekana ndani ya dirisha
class ProductScreen extends StatefulWidget {
  final String productId;
  final StockProduct? initial;
  const ProductScreen({super.key, required this.productId, this.initial});
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late StockProduct? _p = widget.initial;
  Object? _error;
  String? _hl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await Api.i.stockProduct(widget.productId);
      if (mounted) {
        setState(() {
          _p = p;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _mark(String id) {
    setState(() => _hl = id);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _hl = null);
    });
  }

  Future<void> _addType() async {
    final p = _p;
    if (p == null) return;
    final np = await showEntryDialog<StockProduct>(context, builder: (_) => _AddVariantDialog(p));
    if (np == null || !mounted) return;
    final added = np.variants.where((v) => !p.variants.any((x) => x.id == v.id)).toList();
    setState(() => _p = np);
    if (added.isNotEmpty) _mark(added.first.id);
  }

  Future<void> _edit(StockVariant v) async {
    final p = _p;
    if (p == null) return;
    final np = await showEntryDialog<StockProduct>(context, builder: (_) => _EditVariantDialog(v));
    if (np == null || !mounted) return;
    setState(() => _p = np);
    _mark(v.id);
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      appBar: pageBar(
        p?.name ?? '',
        subtitle: p == null ? null : (p.hasVariants ? 'aina ${p.variants.length}' : 'haina aina'),
        back: true,
        boxBack: true,
        action: (p?.hasVariants ?? false) ? SmallButton('+ Aina', height: 32, onTap: _addType) : null,
      ),
      body: _error != null
          ? ErrorView(_error!, onRetry: _load)
          : p == null
              ? const Loading()
              : _body(p),
    );
  }

  Widget _body(StockProduct p) {
    if (p.hasVariants && p.variants.isEmpty) {
      // S07: bidhaa yenye aina lakini bado tupu
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: C.blue2, shape: BoxShape.circle),
            child: const Center(child: AppIcon(AppIcons.package, size: 28, color: C.text)),
          ),
          const SizedBox(height: 16),
          const Text('Hakuna aina bado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
      );
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 30), children: [
      _ThreeStat(qty: p.qty, capital: p.capital, profit: p.profitIfSold),
      SectionTitle(p.hasVariants ? 'Aina' : 'Taarifa',
          trailing: p.hasVariants ? '${p.variants.length}' : null, padding: const EdgeInsets.fromLTRB(2, 18, 2, 10)),
      for (final v in p.variants) ...[
        _VariantCard(v, highlight: v.id == _hl, onTap: () => _edit(v)),
        const SizedBox(height: 8),
      ],
    ]);
  }
}

/// Zipo · Mtaji · Faida ukiuza (bluu)
class _ThreeStat extends StatelessWidget {
  final int qty, capital, profit;
  const _ThreeStat({required this.qty, required this.capital, required this.profit});
  @override
  Widget build(BuildContext context) => Box(
        radius: 16,
        border: C.cardLine,
        child: IntrinsicHeight(
          child: Row(children: [
            Expanded(child: _cell('Zipo', '$qty', false)),
            const VerticalDivider(width: 1, color: C.line),
            Expanded(child: _cell('Mtaji', money(capital), false)),
            const VerticalDivider(width: 1, color: C.line),
            Expanded(child: _cell('Faida ukiuza', money(profit), true)),
          ]),
        ),
      );

  Widget _cell(String label, String value, bool blue) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          FittedBox(
            child: Text(value,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: blue ? C.blue : C.text, fontFeatures: tabular)),
          ),
        ]),
      );
}

/// Kadi ya aina: safu 62 : 100 : 100 : 100, nafasi 12, namba ndani ya FittedBox
class _VariantCard extends StatelessWidget {
  final StockVariant v;
  final bool highlight;
  final VoidCallback onTap;
  const _VariantCard(this.v, {required this.highlight, required this.onTap});

  Widget _cell(String label, String value, {bool blue = false, bool bold = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: C.muted)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: blue ? C.blue : C.text,
                  fontFeatures: tabular,
                )),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => Box(
        radius: 12,
        color: highlight ? C.blue3 : null,
        border: highlight ? C.blue : C.cardLine,
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 62, child: _cell('ZIPO', '${v.qty}')),
            const SizedBox(width: 12),
            Expanded(flex: 100, child: _cell('BUYING', money(v.buying))),
            const SizedBox(width: 12),
            Expanded(flex: 100, child: _cell('SELLING', money(v.selling))),
            const SizedBox(width: 12),
            Expanded(flex: 100, child: _cell('FAIDA', money(v.profitEach), blue: true, bold: true)),
          ]),
        ]),
      );
}

/// S05 / S13: Ongeza idadi · Buying · Selling · Zitakuwa N
class _EditVariantDialog extends StatefulWidget {
  final StockVariant v;
  const _EditVariantDialog(this.v);
  @override
  State<_EditVariantDialog> createState() => _EditVariantDialogState();
}

class _EditVariantDialogState extends State<_EditVariantDialog> {
  final _add = TextEditingController();
  late final _buy = TextEditingController(text: money(widget.v.buying));
  late final _sell = TextEditingController(text: money(widget.v.selling));
  final _fAdd = FocusNode(), _fBuy = FocusNode(), _fSell = FocusNode();
  bool _busy = false;
  String? _error;

  /// Hifadhi inawaka tu ikiwa kuna kilichobadilika (idadi ≠ 0 au bei mpya).
  bool get _changed {
    if (_busy) return false;
    final add = parseMoney(_add.text), b = parseMoney(_buy.text), s = parseMoney(_sell.text);
    return s >= 1 && (add > 0 || b != widget.v.buying || s != widget.v.selling);
  }

  Future<void> _save() async {
    final v = widget.v;
    final add = parseMoney(_add.text), b = parseMoney(_buy.text), s = parseMoney(_sell.text);
    if (add == 0 && b == v.buying && s == v.selling) {
      Navigator.pop(context);
      return;
    }
    if (s < 1) {
      setState(() => _error = 'Jaza selling');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final np = await Api.i.editStockVariant(v.id, addQty: add, buying: b != v.buying ? b : null, selling: s != v.selling ? s : null);
      if (mounted) Navigator.pop(context, np);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final will = widget.v.qty + parseMoney(_add.text);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        EntryHeader(widget.v.name),
        const SizedBox(height: 4),
        Text('Zipo ${widget.v.qty}', style: const TextStyle(fontSize: 11.5, color: C.muted)),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          DialogField(label: 'Ongeza idadi', controller: _add, focus: _fAdd, number: true, hint: '0', width: 84, align: TextAlign.center, autofocus: true, onChanged: (_) => setState(() {}), onSubmitted: (_) => _fBuy.requestFocus()),
          const SizedBox(width: 8),
          DialogField(label: 'Buying', controller: _buy, focus: _fBuy, money: true, width: 86, align: TextAlign.right, onChanged: (_) => setState(() {}), onSubmitted: (_) => _fSell.requestFocus()),
          const SizedBox(width: 8),
          DialogField(label: 'Selling', controller: _sell, focus: _fSell, money: true, width: 86, align: TextAlign.right, onChanged: (_) => setState(() {}), onSubmitted: (_) => _save()),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Text.rich(TextSpan(style: const TextStyle(fontSize: 12.5, color: C.muted), children: [
              const TextSpan(text: 'Zitakuwa '),
              TextSpan(text: '$will', style: const TextStyle(color: C.text, fontWeight: FontWeight.w700, fontFeatures: tabular)),
            ])),
          ),
          PrimaryButton('Hifadhi', busy: _busy, onTap: _changed ? _save : null),
        ]),
        if (_error != null) ErrorText(_error!),
      ]),
    );
  }
}

/// S08: Aina mpya ya {bidhaa}
class _AddVariantDialog extends StatefulWidget {
  final StockProduct p;
  const _AddVariantDialog(this.p);
  @override
  State<_AddVariantDialog> createState() => _AddVariantDialogState();
}

class _AddVariantDialogState extends State<_AddVariantDialog> {
  final _name = TextEditingController(), _qty = TextEditingController(), _buy = TextEditingController(), _sell = TextEditingController();
  final _fName = FocusNode(), _fQty = FocusNode(), _fBuy = FocusNode(), _fSell = FocusNode();
  bool _busy = false;
  String? _error;

  bool get _canSave => !_busy && _name.text.trim().isNotEmpty && _qty.text.isNotEmpty && _buy.text.isNotEmpty && parseMoney(_sell.text) > 0;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final np = await Api.i.addStockVariant(widget.p.id,
          name: _name.text.trim(), qty: parseMoney(_qty.text), buying: parseMoney(_buy.text), selling: parseMoney(_sell.text));
      if (mounted) Navigator.pop(context, np);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        EntryHeader('Aina mpya ya ${widget.p.name}'),
        const SizedBox(height: 14),
        DialogField(
          controller: _name,
          focus: _fName,
          autofocus: true,
          hint: 'Mf. ${widget.p.name} ya hariri',
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _fQty.requestFocus(),
        ),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(flex: 48, child: DialogField(label: 'Idadi', controller: _qty, focus: _fQty, number: true, hint: '0', align: TextAlign.center, onChanged: (_) => setState(() {}), onSubmitted: (_) => _fBuy.requestFocus())),
          const SizedBox(width: 8),
          Expanded(flex: 80, child: DialogField(label: 'Buying', controller: _buy, focus: _fBuy, money: true, hint: '0', align: TextAlign.right, onChanged: (_) => setState(() {}), onSubmitted: (_) => _fSell.requestFocus())),
          const SizedBox(width: 8),
          Expanded(flex: 80, child: DialogField(label: 'Selling', controller: _sell, focus: _fSell, money: true, hint: '0', align: TextAlign.right, onChanged: (_) => setState(() {}), onSubmitted: (_) => _save())),
          const SizedBox(width: 10),
          PrimaryButton('Hifadhi', onTap: _canSave ? _save : null, busy: _busy),
        ]),
        if (_error != null) ErrorText(_error!),
      ]),
    );
  }
}
