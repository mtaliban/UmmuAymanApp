import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/app_icons.dart';
import '../widgets/ui.dart';
import 'sales_screen.dart';

/// HISTORIA — mauzo ya siku zilizopita kwa miezi (M16–M18).
/// Scroll chini -> pakia zaidi (next_before). Gusa siku -> Mauzo ya siku hiyo.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends State<HistoryScreen> {
  final List<HistoryMonth> _months = [];
  String? _next;
  bool _loading = false, _first = true;
  Object? _error;
  final _sc = ScrollController();

  @override
  void initState() {
    super.initState();
    _sc.addListener(() {
      if (_sc.position.extentAfter < 300) _more();
    });
    _more();
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  Future<void> _more() async {
    if (_loading || (!_first && _next == null)) return;
    setState(() => _loading = true);
    try {
      final h = await Api.i.history(before: _first ? null : _next);
      if (!mounted) return;
      setState(() {
        for (final m in h.months) {
          if (_months.isNotEmpty && _months.last.label == m.label) {
            _months.last.days.addAll(m.days);
          } else {
            _months.add(m);
          }
        }
        _next = h.nextBefore;
        _first = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String date) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SalesScreen(date: date)));
    if (!mounted) return;
    setState(() {
      _months.clear();
      _next = null;
      _first = true;
    });
    _more();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: pageBar('Historia', subtitle: 'Mauzo ya siku zilizopita', back: true, boxBack: true),
        body: _first
            ? const SizedBox.expand()
            : _error != null
                ? ErrorView(_error!, onRetry: () {
                    setState(() => _error = null);
                    _more();
                  })
                : _months.isEmpty
                    ? const Center(child: _NoHistory())
                    : ListView(
                        controller: _sc,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                        children: [
                          for (final m in _months) ...[
                            SectionTitle(m.label, trailing: 'siku ${m.days.length}', padding: const EdgeInsets.fromLTRB(2, 16, 2, 8)),
                            for (final d in m.days) ...[
                              _DayCard(d, onTap: () => _open(d.date)),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ],
                      ),
      );
}

class _DayCard extends StatelessWidget {
  final HistoryDay day;
  final VoidCallback onTap;
  const _DayCard(this.day, {required this.onTap});

  @override
  Widget build(BuildContext context) => Box(
        radius: 12,
        padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
        onTap: onTap,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(day.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('Mauzo ${money(day.sales)} · bidhaa ${day.items}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: C.muted)),
            ]),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Faida halisi', style: TextStyle(fontSize: 11, color: C.muted)),
            Text(money(day.net), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.blue, fontFeatures: tabular)),
          ]),
          const Icon(Icons.chevron_right_rounded, size: 20, color: C.faint),
        ]),
      );
}

class _NoHistory extends StatelessWidget {
  const _NoHistory();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: C.blue2, shape: BoxShape.circle),
            child: const Center(child: AppIcon(AppIcons.history, size: 28, color: C.text)),
          ),
          const SizedBox(height: 16),
          const Text('Hakuna historia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
      );
}
