from pathlib import Path
import re

POS = Path('lib/screens/pos_order_screen_v6.dart')
DASH = Path('lib/screens/restaurant_dashboard_screen_v3.dart')

pos = POS.read_text()
dash = DASH.read_text()

# 1) Replace the passive horizontal category strip with an arrow-controlled strip.
old_category = re.compile(r"class _CategoryStrip extends StatelessWidget \{.*?\n\}\n\nclass _MenuTile", re.S)
new_category = r'''class _CategoryStrip extends StatefulWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;
  const _CategoryStrip({required this.categories, required this.selected, required this.onSelect});

  @override
  State<_CategoryStrip> createState() => _CategoryStripState();
}

class _CategoryStripState extends State<_CategoryStrip> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(double delta) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + delta).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    height: 58,
    color: Colors.white,
    child: Row(
      children: [
        const SizedBox(width: 8),
        _CategoryArrow(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Previous categories',
          onTap: () => _move(-300),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: ListView.separated(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
            scrollDirection: Axis.horizontal,
            itemCount: widget.categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (_, i) {
              final item = widget.categories[i];
              final active = item == widget.selected;
              return ChoiceChip(
                label: Text(item),
                selected: active,
                onSelected: (_) => widget.onSelect(item),
                showCheckmark: false,
                selectedColor: AppColors.primary,
                backgroundColor: const Color(0xFFF7F7F8),
                side: BorderSide(
                  color: active ? AppColors.primary : AppColors.outlineLight,
                ),
                labelStyle: TextStyle(
                  color: active ? Colors.white : AppColors.grey700,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 4),
        _CategoryArrow(
          icon: Icons.chevron_right_rounded,
          tooltip: 'More categories',
          onTap: () => _move(300),
        ),
        const SizedBox(width: 8),
      ],
    ),
  );
}

class _CategoryArrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _CategoryArrow({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: const Color(0xFFF7F7F8),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 20, color: AppColors.grey700),
        ),
      ),
    ),
  );
}

class _MenuTile'''
pos, n = old_category.subn(new_category, pos, count=1)
if n != 1:
    raise SystemExit(f'ERROR: category strip replacement count={n}')
print('OK: category strip left/right controls')

# 2) Remove the ghost/disabled Bill half-button. KOT takes full width when Bill is unavailable.
old_actions = "Row(children: [Expanded(child: OutlinedButton.icon(onPressed: busy ? null : onKot, icon: const Icon(Icons.print_outlined, size: 15), label: Text(state == 'open' ? 'KOT' : 'Reprint KOT'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: busy ? null : onBill, icon: const Icon(Icons.receipt_long_outlined, size: 15), label: const Text('Bill')))]),"
new_actions = "if (onBill == null) SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: busy ? null : onKot, icon: const Icon(Icons.print_outlined, size: 15), label: Text(state == 'open' ? 'KOT' : 'Reprint KOT'))) else Row(children: [Expanded(child: OutlinedButton.icon(onPressed: busy ? null : onKot, icon: const Icon(Icons.print_outlined, size: 15), label: Text(state == 'open' ? 'KOT' : 'Reprint KOT'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: busy ? null : onBill, icon: const Icon(Icons.receipt_long_outlined, size: 15), label: const Text('Bill')))]),"
if old_actions not in pos:
    raise SystemExit('ERROR: ticket secondary action anchor not found')
pos = pos.replace(old_actions, new_actions, 1)
print('OK: removed ghost disabled Bill area')

POS.write_text(pos)

# 3) Replace Sales Overview with a true interactive time-range chart.
chart = re.compile(r"class _SalesOverviewCard extends StatelessWidget \{.*?\n\}\n\nclass _RecentOrdersCard", re.S)
new_chart = r'''class _SalesOverviewCard extends StatefulWidget {
  final List<Sale> sales;
  const _SalesOverviewCard({required this.sales});

  @override
  State<_SalesOverviewCard> createState() => _SalesOverviewCardState();
}

class _SalesOverviewCardState extends State<_SalesOverviewCard> {
  int _days = 7;
  int? _selectedIndex;

  List<DateTime> _dates() {
    final now = DateTime.now();
    return List.generate(
      _days,
      (i) => DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: _days - 1 - i)),
    );
  }

  List<double> _values(List<DateTime> dates) => dates
      .map(
        (day) => widget.sales
            .where((s) => _sameDayStatic(s.createdAt, day))
            .fold<double>(0, (a, b) => a + b.total),
      )
      .toList();

  void _selectPoint(TapDownDetails details, double width, int count) {
    if (count <= 0 || width <= 0) return;
    final x = details.localPosition.dx.clamp(0.0, width);
    final index = count == 1
        ? 0
        : ((x / width) * (count - 1)).round().clamp(0, count - 1);
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final dates = _dates();
    final values = _values(dates);
    final total = values.fold<double>(0, (a, b) => a + b);
    final orderCount = widget.sales
        .where((s) => dates.any((d) => _sameDayStatic(s.createdAt, d)))
        .length;
    final selected = _selectedIndex != null && _selectedIndex! < values.length
        ? _selectedIndex!
        : values.length - 1;

    return _Panel(
      title: 'Sales Overview',
      trailing: Wrap(
        spacing: 4,
        children: [7, 30, 90]
            .map(
              (days) => ChoiceChip(
                label: Text(days == 7 ? '7D' : days == 30 ? '30D' : '90D'),
                selected: _days == days,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() {
                  _days = days;
                  _selectedIndex = null;
                }),
              ),
            )
            .toList(),
      ),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _selectPoint(d, c.maxWidth, values.length),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
                        child: CustomPaint(
                          painter: _LineChartPainter(values),
                        ),
                      ),
                    ),
                    if (values.isNotEmpty)
                      Positioned(
                        left: 10,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: _line),
                            boxShadow: const [
                              BoxShadow(color: Color(0x0D101828), blurRadius: 8),
                            ],
                          ),
                          child: Text(
                            '${DateFormat('dd MMM').format(dates[selected])}  •  Rs ${NumberFormat('#,##0').format(values[selected].round())}',
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('dd MMM').format(dates.first), style: const TextStyle(fontSize: 8.5, color: _muted)),
              const Text('Click chart to inspect a day', style: TextStyle(fontSize: 8.5, color: _muted)),
              Text(DateFormat('dd MMM').format(dates.last), style: const TextStyle(fontSize: 8.5, color: _muted)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(child: _MiniStat('$_days-Day Sales', 'Rs ${NumberFormat('#,##0').format(total.round())}')),
                Expanded(child: _MiniStat('Orders', '$orderCount')),
                Expanded(child: _MiniStat('Daily Avg', 'Rs ${NumberFormat('#,##0').format((total / _days).round())}')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentOrdersCard'''
dash, n = chart.subn(new_chart, dash, count=1)
if n != 1:
    raise SystemExit(f'ERROR: sales chart replacement count={n}')
print('OK: interactive 7D/30D/90D sales chart')

DASH.write_text(dash)
print('OK: POS + dashboard source written')
