from pathlib import Path
import re

p = Path('lib/screens/restaurant_dashboard_screen_v3.dart')
s = p.read_text()


def sub_once(pattern, replacement, name, flags=re.S):
    global s
    s2, n = re.subn(pattern, replacement, s, count=1, flags=flags)
    if n != 1:
        raise SystemExit(f'ERROR: {name}: expected 1 match, found {n}')
    s = s2
    print('OK:', name)

# 1) Remove redundant Today/date chip and its spacing.
sub_once(
    r"\n\s*Align\(\s*alignment:\s*Alignment\.centerRight,\s*child:\s*Container\([\s\S]*?'Today, \$\{DateFormat\('d MMM yyyy'\)\.format\(now\)\}'[\s\S]*?\),\s*\),\s*const SizedBox\(height:\s*10\),",
    "\n",
    'remove dashboard date chip',
)

# 2) Add richer details to KPI model.
sub_once(
    r"class _Kpi \{\s*final String id, label, value;\s*final IconData icon;\s*final Color color;\s*final List<double> trend;\s*const _Kpi\(\s*this\.id,\s*this\.label,\s*this\.value,\s*this\.icon,\s*this\.color,\s*this\.trend,\s*\);\s*\}",
    '''class _Kpi {
  final String id, label, value;
  final IconData icon;
  final Color color;
  final List<double> trend;
  final Map<String, String> details;
  const _Kpi(
    this.id,
    this.label,
    this.value,
    this.icon,
    this.color,
    this.trend, [
    this.details = const <String, String>{},
  ]);
}''',
    'extend KPI model',
)

# 3) Add KPI detail maps to the six KPI constructors using stable trailing anchors.
repls = [
("""                        _salesTrend(sales),
                      ),""", """                        _salesTrend(sales),
                        {
                          'Today': 'Rs ${_money(todayRevenue)}',
                          'Orders today': '${todaySales.length}',
                          'Average bill': 'Rs ${_money(avgBill)}',
                          '7-day total': 'Rs ${_money(_salesTrend(sales).fold<double>(0, (a, b) => a + b))}',
                        },
                      ),"""),
("""                        _orderTrend(sales),
                      ),""", """                        _orderTrend(sales),
                        {
                          'Today': '${todaySales.length}',
                          'Sales today': 'Rs ${_money(todayRevenue)}',
                          'Average bill': 'Rs ${_money(avgBill)}',
                          '7-day orders': '${_orderTrend(sales).fold<double>(0, (a, b) => a + b).round()}',
                        },
                      ),"""),
("""                        _purple,
                        const <double>[],
                      ),""", """                        _purple,
                        const <double>[],
                        {
                          'Average bill': 'Rs ${_money(avgBill)}',
                          'Sales today': 'Rs ${_money(todayRevenue)}',
                          'Orders today': '${todaySales.length}',
                        },
                      ),"""),
("""                        _orange,
                        const <double>[],
                      ),""", """                        _orange,
                        const <double>[],
                        {
                          'Average kitchen time': kitchenAverage == null ? 'Not available' : _duration(kitchenAverage),
                          'Live kitchen orders': '${orders.length}',
                        },
                      ),"""),
("""                        const Color(0xFF06AED4),
                        const <double>[],
                      ),""", """                        const Color(0xFF06AED4),
                        const <double>[],
                        {
                          'Active tables': '$activeTables',
                          'Total tables': '${tables.length}',
                          'Utilization': tables.isEmpty ? '0%' : '${((activeTables / tables.length) * 100).round()}%',
                        },
                      ),"""),
("""                        _pink,
                        const <double>[],
                      ),""", """                        _pink,
                        const <double>[],
                        {
                          'Finalized': '$praFinalized',
                          'Total receipts': '${todaySales.length}',
                          'Completion': todaySales.isEmpty ? '0%' : '${((praFinalized / todaySales.length) * 100).round()}%',
                        },
                      ),"""),
]
for old, new in repls:
    if old not in s:
        raise SystemExit('ERROR: KPI constructor anchor not found')
    s = s.replace(old, new, 1)
print('OK: rich KPI statistics')

# 4) Replace KPI dialog with detailed/full statistics popup.
sub_once(
    r"Future<void> _showKpiDetails\(_Kpi kpi\) async \{[\s\S]*?\n  \}\n\n  Duration\? _averageKitchenTime",
    '''Future<void> _showKpiDetails(_Kpi kpi) async {
    final trendTotal = kpi.trend.fold<double>(0, (a, b) => a + b);
    final trendAverage = kpi.trend.isEmpty ? 0.0 : trendTotal / kpi.trend.length;
    final trendHigh = kpi.trend.isEmpty ? 0.0 : kpi.trend.reduce(math.max);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 650),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 58,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _line)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: kpi.color.withValues(alpha: .11),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(kpi.icon, color: kpi.color, size: 19),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          kpi.label,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kpi.value,
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: _ink),
                        ),
                        const SizedBox(height: 18),
                        if (kpi.details.isNotEmpty)
                          LayoutBuilder(
                            builder: (_, constraints) {
                              final cardWidth = constraints.maxWidth >= 560
                                  ? (constraints.maxWidth - 12) / 2
                                  : constraints.maxWidth;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: kpi.details.entries.map((entry) => Container(
                                  width: cardWidth,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _soft,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _line),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(entry.key, style: const TextStyle(fontSize: 10, color: _muted, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 5),
                                      Text(entry.value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
                                    ],
                                  ),
                                )).toList(),
                              );
                            },
                          ),
                        if (kpi.trend.length > 1) ...[
                          const SizedBox(height: 20),
                          const Text('7-Day Trend', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          Container(
                            height: 150,
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _line),
                            ),
                            child: CustomPaint(painter: _SparklinePainter(kpi.trend, kpi.color)),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _DetailChip('7-day total', kpi.id == 'sales' ? 'Rs ${_money(trendTotal)}' : '${trendTotal.round()}'),
                              _DetailChip('Daily average', kpi.id == 'sales' ? 'Rs ${_money(trendAverage)}' : trendAverage.toStringAsFixed(1)),
                              _DetailChip('Highest day', kpi.id == 'sales' ? 'Rs ${_money(trendHigh)}' : '${trendHigh.round()}'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Duration? _averageKitchenTime''',
    'rich KPI popup',
)

# 5) Replace _Panel with stateful card controls: minimize, maximize/full view.
sub_once(
    r"class _Panel extends StatelessWidget \{[\s\S]*?\n\}\n\nclass _PeriodChip",
    '''class _Panel extends StatefulWidget {
  final String title;
  final Widget trailing, child;
  const _Panel({
    required this.title,
    required this.trailing,
    required this.child,
  });

  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> {
  bool minimized = false;

  Future<void> _maximize() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1250, maxHeight: 820),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _line)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.drag_indicator_rounded, size: 18, color: _purple),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(widget.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                      ),
                      widget.trailing,
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Restore size',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_fullscreen_rounded, size: 18),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
                Expanded(child: Padding(padding: const EdgeInsets.all(18), child: widget.child)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _cardDecoration(),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(Icons.drag_indicator_rounded, size: 16, color: _purple),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
            widget.trailing,
            const SizedBox(width: 5),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: minimized ? 'Restore' : 'Minimize',
              onPressed: () => setState(() => minimized = !minimized),
              icon: Icon(minimized ? Icons.add_rounded : Icons.remove_rounded, size: 17),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Maximize',
              onPressed: _maximize,
              icon: const Icon(Icons.open_in_full_rounded, size: 16),
            ),
          ],
        ),
        if (!minimized) ...[
          const SizedBox(height: 8),
          Expanded(child: widget.child),
        ],
      ],
    ),
  );
}

class _DetailChip extends StatelessWidget {
  final String label, value;
  const _DetailChip(this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: _soft,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 9.5, color: _muted)),
        Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
      ],
    ),
  );
}

class _PeriodChip''',
    'dashboard panel controls',
)

p.write_text(s)
print('PATCH COMPLETE')
