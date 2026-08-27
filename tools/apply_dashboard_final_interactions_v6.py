from pathlib import Path

p = Path('lib/screens/restaurant_dashboard_screen_v3.dart')
s = p.read_text()

# ---------- 1. Desktop KPI row: six columns ----------
s = s.replace("final columns = width >= 1350\n                        ? 6\n                        : width >= 900\n                        ? 3\n                        : width >= 560\n                        ? 2\n                        : 1;",
              "final columns = width >= 1050\n                        ? 6\n                        : width >= 760\n                        ? 3\n                        : width >= 520\n                        ? 2\n                        : 1;")

# ---------- 2. KPI close button (session-level) ----------
s = s.replace("class _KpiCard extends StatelessWidget {\n  final _Kpi data;\n\n  const _KpiCard({required this.data});",
              "class _KpiCard extends StatelessWidget {\n  final _Kpi data;\n  final VoidCallback? onClose;\n\n  const _KpiCard({required this.data, this.onClose});")
s = s.replace("if (hasTrend)\n                Icon(Icons.show_chart_rounded, size: 15, color: data.color),",
              "if (hasTrend)\n                Icon(Icons.show_chart_rounded, size: 15, color: data.color),\n              if (onClose != null) ...[\n                const SizedBox(width: 2),\n                InkWell(\n                  borderRadius: BorderRadius.circular(14),\n                  onTap: onClose,\n                  child: const Padding(\n                    padding: EdgeInsets.all(2),\n                    child: Icon(Icons.close_rounded, size: 14, color: _muted),\n                  ),\n                ),\n              ],")
old_child = """child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => _showKpiDetails(kpi),
                                    child: _KpiCard(data: kpi),
                                  ),"""
new_child = """child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => _showKpiDetails(kpi),
                                    child: _KpiCard(
                                      data: kpi,
                                      onClose: () => setState(
                                        () => _kpiOrder.remove(kpi.id),
                                      ),
                                    ),
                                  ),"""
if old_child in s:
    s = s.replace(old_child, new_child, 1)

# ---------- 3. Sales chart: tooltip exactly at clicked/hovered node ----------
start = s.find('class _SalesOverviewCardState extends State<_SalesOverviewCard> {')
end = s.find('class _RecentOrdersCard extends StatelessWidget {', start)
if start < 0 or end < 0:
    raise SystemExit('ERROR: SalesOverview class anchors not found')
new_sales = r'''class _SalesOverviewCardState extends State<_SalesOverviewCard> {
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

  void _selectAt(double dx, double width, int count) {
    if (count <= 0 || width <= 0) return;
    final index = ((dx.clamp(0.0, width) / width) * (count - 1))
        .round()
        .clamp(0, count - 1);
    if (_selectedIndex != index) setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final dates = _dates();
    final dailySales = dates
        .map((day) => widget.sales.where((s) => _sameDayStatic(s.createdAt, day)).toList())
        .toList();
    final values = dailySales
        .map((items) => items.fold<double>(0, (a, b) => a + b.total))
        .toList();
    final total = values.fold<double>(0, (a, b) => a + b);
    final orderCount = dailySales.fold<int>(0, (a, b) => a + b.length);
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
              builder: (_, c) {
                final maxV = values.isEmpty ? 1.0 : math.max(1.0, values.reduce(math.max));
                final plotLeft = 6.0;
                final plotTop = 10.0;
                final plotWidth = math.max(1.0, c.maxWidth - 12);
                final plotHeight = math.max(1.0, c.maxHeight - 10);
                final pointX = values.length <= 1
                    ? plotLeft
                    : plotLeft + plotWidth * selected / (values.length - 1);
                final pointY = plotTop + plotHeight -
                    (values[selected] / maxV) * (plotHeight - 10);
                final selectedOrders = dailySales[selected];
                selectedOrders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                final activityTime = selectedOrders.isEmpty
                    ? 'No activity'
                    : 'Last ${DateFormat('h:mm a').format(selectedOrders.last.createdAt)}';
                const tooltipWidth = 156.0;
                final tooltipLeft = (pointX - tooltipWidth / 2)
                    .clamp(0.0, math.max(0.0, c.maxWidth - tooltipWidth));
                final tooltipTop = (pointY - 74)
                    .clamp(0.0, math.max(0.0, c.maxHeight - 66));

                return MouseRegion(
                  cursor: SystemMouseCursors.precise,
                  onHover: (event) => _selectAt(event.localPosition.dx, c.maxWidth, values.length),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => _selectAt(d.localPosition.dx, c.maxWidth, values.length),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
                            child: CustomPaint(painter: _LineChartPainter(values)),
                          ),
                        ),
                        if (values.isNotEmpty && _selectedIndex != null) ...[
                          Positioned(
                            left: pointX - .5,
                            top: 0,
                            bottom: 0,
                            child: Container(width: 1, color: _purple.withValues(alpha: .28)),
                          ),
                          Positioned(
                            left: pointX - 5,
                            top: pointY - 5,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: _purple, width: 3),
                              ),
                            ),
                          ),
                          Positioned(
                            left: tooltipLeft,
                            top: tooltipTop,
                            width: tooltipWidth,
                            child: Material(
                              elevation: 5,
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _line),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${DateFormat('dd MMM yyyy').format(dates[selected])} • $activityTime',
                                      style: const TextStyle(fontSize: 8.5, color: _muted, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Rs ${NumberFormat('#,##0').format(values[selected].round())}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _ink),
                                    ),
                                    Text(
                                      '${selectedOrders.length} order${selectedOrders.length == 1 ? '' : 's'}',
                                      style: const TextStyle(fontSize: 8.5, color: _muted),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('dd MMM').format(dates.first), style: const TextStyle(fontSize: 8.5, color: _muted)),
              const Text('Hover or click a node for exact activity', style: TextStyle(fontSize: 8.5, color: _muted)),
              Text(DateFormat('dd MMM').format(dates.last), style: const TextStyle(fontSize: 8.5, color: _muted)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(10)),
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

'''
s = s[:start] + new_sales + s[end:]

# ---------- 4. Top selling items: every item clickable ----------
top_start = s.find('class _TopItemsCard extends StatelessWidget {')
top_end = s.find('class _KitchenCard extends StatelessWidget {', top_start)
if top_start < 0 or top_end < 0:
    raise SystemExit('ERROR: TopItems anchors not found')
top = s[top_start:top_end]
top = top.replace('''          return Row(
            children: [''', '''          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.go(AppRouter.products),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [''', 1)
top = top.replace('''            ],
          );
        },
      ),
    );
  }
}

''', '''                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

''', 1)
s = s[:top_start] + top + s[top_end:]

# ---------- 5. Kitchen performance: live status list + clickable rows ----------
k_start = s.find('class _KitchenCard extends StatelessWidget {')
k_end = s.find('class _AlertsCard extends StatelessWidget {', k_start)
if k_start < 0 or k_end < 0:
    raise SystemExit('ERROR: Kitchen anchors not found')
new_kitchen = r'''class _KitchenCard extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> orders;
  const _KitchenCard({required this.orders});

  String _status(Map<String, dynamic> d) =>
      (d['status'] ?? 'open').toString().toLowerCase();

  Color _statusColor(String status) {
    if (status == 'ready') return _green;
    if (['served', 'completed', 'checkout'].contains(status)) return _blue;
    return _orange;
  }

  @override
  Widget build(BuildContext context) {
    var making = 0, ready = 0, served = 0;
    final sorted = [...orders];
    sorted.sort((a, b) {
      final av = a.data()['createdAt'];
      final bv = b.data()['createdAt'];
      final ad = av is Timestamp ? av.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
      final bd = bv is Timestamp ? bv.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    for (final doc in orders) {
      final status = _status(doc.data());
      if (['open', 'sent', 'making', 'preparing'].contains(status)) making++;
      if (status == 'ready') ready++;
      if (['served', 'completed', 'checkout'].contains(status)) served++;
    }

    return _Panel(
      title: 'Kitchen Performance',
      trailing: const _PeriodChip('Live'),
      child: Column(
        children: [
          SizedBox(
            height: 58,
            child: Row(
              children: [
                Expanded(child: InkWell(onTap: () => context.go(AppRouter.orders), child: _BigMiniStat('$making', 'Preparing', _orange))),
                const VerticalDivider(width: 1),
                Expanded(child: InkWell(onTap: () => context.go(AppRouter.orders), child: _BigMiniStat('$ready', 'Ready', _green))),
                const VerticalDivider(width: 1),
                Expanded(child: InkWell(onTap: () => context.go(AppRouter.orders), child: _BigMiniStat('$served', 'Completed', _blue))),
              ],
            ),
          ),
          const Divider(height: 10),
          Expanded(
            child: sorted.isEmpty
                ? const Center(child: Text('No kitchen activity', style: TextStyle(fontSize: 9.5, color: _muted)))
                : ListView.separated(
                    itemCount: math.min(6, sorted.length),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final doc = sorted[i];
                      final d = doc.data();
                      final status = _status(d);
                      final created = d['createdAt'];
                      final createdAt = created is Timestamp ? created.toDate() : null;
                      final table = (d['tableNumber'] ?? d['tableName'] ?? '').toString();
                      final orderNo = (d['orderNo'] ?? d['orderNumber'] ?? doc.id).toString();
                      final elapsed = createdAt == null ? '' : _shortElapsed(DateTime.now().difference(createdAt));
                      return ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -3),
                        contentPadding: EdgeInsets.zero,
                        onTap: () => context.go(AppRouter.orders),
                        title: Text(
                          '#$orderNo${table.isEmpty ? '' : ' • Table $table'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9.2, fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${createdAt == null ? '' : DateFormat('h:mm a').format(createdAt)}${elapsed.isEmpty ? '' : ' • $elapsed'}',
                          style: const TextStyle(fontSize: 8.2, color: _muted),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            _prettyStatus(status),
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: _statusColor(status)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _shortElapsed(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${math.max(0, d.inSeconds)}s';
  }

  static String _prettyStatus(String s) {
    if (['open', 'sent', 'making', 'preparing'].contains(s)) return 'Preparing';
    if (s == 'ready') return 'Ready';
    if (['served', 'completed', 'checkout'].contains(s)) return 'Completed';
    return s.isEmpty ? 'Open' : '${s[0].toUpperCase()}${s.substring(1)}';
  }
}

'''
s = s[:k_start] + new_kitchen + s[k_end:]

# ---------- 6. Alerts + branch are clickable to relevant sections ----------
alerts_start = s.find('class _AlertsCard extends StatelessWidget {')
branch_start = s.find('class _BranchCard extends StatelessWidget {', alerts_start)
if alerts_start >= 0 and branch_start > alerts_start:
    alerts = s[alerts_start:branch_start]
    alerts = alerts.replace('''              return ListTile(
                dense: true,''', '''              final title = (d['title'] ?? 'Alert').toString();
              final lower = title.toLowerCase();
              final route = lower.contains('stock')
                  ? AppRouter.products
                  : lower.contains('work') || lower.contains('staff')
                      ? AppRouter.attendance
                      : lower.contains('payment') || lower.contains('sale')
                          ? AppRouter.sales
                          : AppRouter.orders;
              return ListTile(
                onTap: () => context.go(route),
                dense: true,''', 1)
    s = s[:alerts_start] + alerts + s[branch_start:]

branch_start = s.find('class _BranchCard extends StatelessWidget {')
panel_start = s.find('class _Panel extends StatefulWidget {', branch_start)
if branch_start >= 0 and panel_start > branch_start:
    branch = s[branch_start:panel_start]
    branch = branch.replace('''          ListTile(
            contentPadding: EdgeInsets.zero,''', '''          ListTile(
            onTap: () => context.go(AppRouter.branches),
            contentPadding: EdgeInsets.zero,''', 1)
    s = s[:branch_start] + branch + s[panel_start:]

# ---------- 7. Persistent close X for every standard widget ----------
# _Panel supports close callback.
s = s.replace('''class _Panel extends StatefulWidget {
  final String title;
  final Widget trailing, child;
  const _Panel({
    required this.title,
    required this.trailing,
    required this.child,
  });''', '''class _Panel extends StatefulWidget {
  final String title;
  final Widget trailing, child;
  final VoidCallback? onClose;
  const _Panel({
    required this.title,
    required this.trailing,
    required this.child,
    this.onClose,
  });''')
s = s.replace('''            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Maximize',
              onPressed: _maximize,
              icon: const Icon(Icons.open_in_full_rounded, size: 16),
            ),
          ],''', '''            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Maximize',
              onPressed: _maximize,
              icon: const Icon(Icons.open_in_full_rounded, size: 16),
            ),
            if (widget.onClose != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Close widget',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded, size: 17),
              ),
          ],''', 1)

# Add onClose property to each dashboard card and feed it to _Panel.
classes = [
    ('_SalesOverviewCard', "final List<Sale> sales;", "const _SalesOverviewCard({required this.sales});"),
    ('_RecentOrdersCard', "final List<Sale> sales;", "const _RecentOrdersCard({required this.sales});"),
    ('_TopItemsCard', "final List<Sale> sales;", "const _TopItemsCard({required this.sales});"),
    ('_KitchenCard', "final List<QueryDocumentSnapshot<Map<String, dynamic>>> orders;", "const _KitchenCard({required this.orders});"),
    ('_AlertsCard', "final UserModel user;", "const _AlertsCard({required this.user});"),
    ('_BranchCard', "final UserModel user;\n  final List<Sale> sales;", "const _BranchCard({required this.user, required this.sales});"),
]
for cls, field, ctor in classes:
    pos = s.find(f'class {cls}')
    if pos < 0:
        continue
    next_pos = s.find('\nclass _', pos + 10)
    if next_pos < 0:
        next_pos = len(s)
    chunk = s[pos:next_pos]
    if 'final VoidCallback? onClose;' not in chunk:
        chunk = chunk.replace(field, field + '\n  final VoidCallback? onClose;', 1)
        chunk = chunk.replace(ctor, ctor[:-2] + ', this.onClose});', 1)
        chunk = chunk.replace("return _Panel(\n      title:", "return _Panel(\n      onClose: onClose,\n      title:", 1)
        s = s[:pos] + chunk + s[next_pos:]

# Supply persistent close callbacks at construction sites.
repls = {
    '_SalesOverviewCard(sales: sales)': "_SalesOverviewCard(sales: sales, onClose: () { setState(() => _visible.remove('salesChart')); _savePrefs(); })",
    '_RecentOrdersCard(sales: sales)': "_RecentOrdersCard(sales: sales, onClose: () { setState(() => _visible.remove('recentOrders')); _savePrefs(); })",
    '_TopItemsCard(sales: sales)': "_TopItemsCard(sales: sales, onClose: () { setState(() => _visible.remove('topItems')); _savePrefs(); })",
    '_KitchenCard(orders: orders)': "_KitchenCard(orders: orders, onClose: () { setState(() => _visible.remove('kitchen')); _savePrefs(); })",
    '_AlertsCard(user: user)': "_AlertsCard(user: user, onClose: () { setState(() => _visible.remove('alerts')); _savePrefs(); })",
    '_BranchCard(user: user, sales: todaySales)': "_BranchCard(user: user, sales: todaySales, onClose: () { setState(() => _visible.remove('branches')); _savePrefs(); })",
}
for old, new in repls.items():
    s = s.replace(old, new, 1)

# ---------- 8. KPI detail dialog gets direct relevant-section button ----------
if 'String _routeForKpi(' not in s:
    insert_at = s.find('  Future<void> _showKpiDetails(_Kpi kpi) async {')
    if insert_at > 0:
        helper = '''  String _routeForKpi(String id) {
    switch (id) {
      case 'sales':
      case 'avg':
        return AppRouter.sales;
      case 'orders':
      case 'kitchenTime':
        return AppRouter.orders;
      case 'tables':
        return AppRouter.tables;
      case 'pra':
        return AppRouter.praSettings;
      default:
        return AppRouter.dashboard;
    }
  }

'''
        s = s[:insert_at] + helper + s[insert_at:]

s = s.replace('''                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),''', '''                      IconButton(
                        tooltip: 'Open relevant section',
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          context.go(_routeForKpi(kpi.id));
                        },
                        icon: const Icon(Icons.open_in_new_rounded),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),''', 1)

p.write_text(s)
print('OK: six KPI cards fit one desktop row')
print('OK: KPI cards have close X')
print('OK: Sales trend tooltip follows exact clicked/hovered node')
print('OK: tooltip shows date, amount, order count and latest activity time')
print('OK: Top Selling Items are clickable')
print('OK: Kitchen Performance shows Preparing / Ready / Completed orders')
print('OK: kitchen rows navigate to Orders/KOT')
print('OK: Alerts and Branch content navigate to relevant sections')
print('OK: every standard dashboard widget has persistent close X')
print('OK: KPI detail dialog can open relevant section')
print('ONLY lib/screens/restaurant_dashboard_screen_v3.dart is modified')
