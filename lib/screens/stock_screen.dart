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

/// Ukubwa wa kadi moja kwenye gridi (unatumika pia kusogeza hadi kadi mpya).
const double _tileH = 106, _tileGap = 10;

class _StockScreenState extends State<StockScreen> {
  late Future<StockList> _f = Api.i.stock();
  final _q = TextEditingController();
  String? _newId;
  int? _newRow;
  bool _adding = false;
  final _listKey = GlobalKey();
  final _gridKey = GlobalKey();
  final _sc = ScrollController();

  @override
  void dispose() {
    _q.dispose();
    _sc.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _f = Api.i.stock();
    });
  }

  /// Sogeza ukurasa hadi kadi ya bidhaa mpya ionekane mara moja.
  /// Kadi iliyo nje ya skrini haijengwi, kwa hiyo tunatumia nafasi ya gridi
  /// (mstari wa kadi) badala ya kuitafuta kwa key.
  void _scrollToNew([int tries = 12]) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final grid = _gridKey.currentContext?.findRenderObject() as RenderBox?;
        final list = _listKey.currentContext?.findRenderObject() as RenderBox?;
        final row = _newRow;
        // Wakati orodha mpya inapakia, ukurasa huwa bado "Loading" — subiri fremu chache.
        if (grid == null || list == null || row == null || !_sc.hasClients) {
          if (tries > 0) _scrollToNew(tries - 1);
          return;
        }
        final gridTop = grid.localToGlobal(Offset.zero).dy - list.localToGlobal(Offset.zero).dy;
        final cardTop = gridTop + row * (_tileH + _tileGap);
        final view = _sc.position.viewportDimension;
        // Kadi ikiwa tayari inaonekana kikamilifu, hatusogezi ukurasa.
        if (cardTop >= 0 && cardTop + _tileH <= view) return;
        final target = (_sc.offset + cardTop - 12).clamp(0.0, _sc.position.maxScrollExtent);
        _sc.animateTo(target, duration: const Duration(milliseconds: 340), curve: Curves.easeOutCubic);
      });

  void _new() => setState(() => _adding = true);

  Future<void> _saved(StockProduct p) async {
    setState(() {
      _adding = false;
      _newId = p.id;
    });
    _reload();
    _scrollToNew();
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
                    : _content(list),
          );
        },
      );

  /// Ukurasa + fomu ya "Bidhaa mpya" iliyoshikamana na chini (kama Mauzo):
  /// orodha inabaki juu, fomu haizibi kadi zilizopo.
  Widget _content(StockList list) => LayoutBuilder(builder: (context, cons) {
        final maxForm = (cons.maxHeight - 24).clamp(140.0, 640.0);
        return Stack(children: [
          _body(list),
          if (_adding)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              left: 12,
              right: 12,
              // Scaffold inapunguza ukurasa kwa urefu wa keyboard, hivyo
              // "bottom: 10" inatosha: fomu inakaa chini juu ya kibodi.
              bottom: 10,
              child: Container(
                constraints: BoxConstraints(maxHeight: maxForm),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Color(0x2E111827), blurRadius: 24, offset: Offset(0, 8))],
                ),
                child: _NewProductCard(onSaved: _saved, onClose: () => setState(() => _adding = false)),
              ),
            ),
        ]);
      });

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
    // Mstari wa kadi mpya (kwa ajili ya kusogeza ukurasa hadi ionekane).
    final idx = _newId == null ? -1 : shown.indexWhere((p) => p.id == _newId);
    _newRow = idx < 0 ? null : idx ~/ 2;

    // Fomu ikiwa wazi, orodha ipate nafasi ya kutosha chini yake.
    return ListView(key: _listKey, controller: _sc, padding: EdgeInsets.fromLTRB(16, 16, 16, _adding ? 320 : 140), children: [
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
          key: _gridKey,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: shown.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: _tileGap, crossAxisSpacing: _tileGap, mainAxisExtent: _tileH),
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

/// K2 · S06 / S10: fomu ya bidhaa mpya ndani ya ukurasa (menyu ya chini
/// inabaki) — sawa na fomu za Mauzo, orodha inaonekana juu yake.
class _NewProductCard extends StatefulWidget {
  final ValueChanged<StockProduct> onSaved;
  final VoidCallback onClose;
  const _NewProductCard({required this.onSaved, required this.onClose});
  @override
  State<_NewProductCard> createState() => _NewProductCardState();
}

class _NewProductCardState extends State<_NewProductCard> {
  final _name = TextEditingController(), _qty = TextEditingController(), _buy = TextEditingController(), _sell = TextEditingController();
  final _fName = FocusNode(), _fQty = FocusNode(), _fBuy = FocusNode(), _fSell = FocusNode();
  bool _has = true, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Kila kisanduku kikiguswa, fomu inajisogeza hadi kionekane juu ya kibodi.
    for (final f in [_fName, _fQty, _fBuy, _fSell]) {
      f.addListener(() => keepFieldInView(f));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _qty, _buy, _sell]) {
      c.dispose();
    }
    for (final f in [_fName, _fQty, _fBuy, _fSell]) {
      f.dispose();
    }
    super.dispose();
  }

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
      if (mounted) {
        FocusScope.of(context).unfocus();
        widget.onSaved(p);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Box(
      radius: 12,
      border: C.cardLine,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      // Kadi haizidi nafasi iliyopo; ikiwa ndogo, inajisogeza yenyewe.
      child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
            child: Text('Bidhaa mpya',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: C.text)),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: widget.onClose,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.line)),
              child: const Icon(Icons.close_rounded, size: 16, color: C.text),
            ),
          ),
        ]),
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
      ])),
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
