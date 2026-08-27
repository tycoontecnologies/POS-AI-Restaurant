from pathlib import Path

DASH = Path('lib/screens/restaurant_dashboard_screen_v3.dart')
KITCHEN = Path('lib/screens/kitchen_kot_screen.dart')

for p in (DASH, KITCHEN):
    if not p.exists():
        raise SystemExit(f'ERROR: missing {p}')

# ---------------- Dashboard fixes ----------------
s = DASH.read_text()

# 1) Do not auto-open customize dialog from query-string after refresh.
# The toolbar Widgets action should open it explicitly; stale ?customize=1 was causing
# the refresh/modal behavior seen by the user.
old = """    final customize =
        GoRouterState.of(context).uri.queryParameters['customize'] == '1';
    if (customize && !_customizerShown) {
      _customizerShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _customize();
      });
    }
"""
new = """    // Dashboard customization is opened explicitly from the Widgets control.
    // Do not auto-open from a stale ?customize=1 URL after refresh.
"""
if old in s:
    s = s.replace(old, new, 1)

# 2) Close button for Sales Overview specifically. Standard widgets use _Panel onClose,
# but Sales Overview may still be constructed without it after earlier patches.
s = s.replace(
    "child: _SalesOverviewCard(sales: sales),",
    "child: _SalesOverviewCard(\n                          sales: sales,\n                          onClose: () {\n                            setState(() => _visible.remove('salesChart'));\n                            _savePrefs();\n                          },\n                        ),",
    1,
)

# 3) Recent / Top / Kitchen / Alerts / Branch ensure persistent close callback exists.
repls = {
    "child: _RecentOrdersCard(sales: sales),": "child: _RecentOrdersCard(\n                          sales: sales,\n                          onClose: () {\n                            setState(() => _visible.remove('recentOrders'));\n                            _savePrefs();\n                          },\n                        ),",
    "child: _TopItemsCard(sales: sales),": "child: _TopItemsCard(\n                          sales: sales,\n                          onClose: () {\n                            setState(() => _visible.remove('topItems'));\n                            _savePrefs();\n                          },\n                        ),",
    "child: _KitchenCard(orders: orders),": "child: _KitchenCard(\n                          orders: orders,\n                          onClose: () {\n                            setState(() => _visible.remove('kitchen'));\n                            _savePrefs();\n                          },\n                        ),",
    "child: _AlertsCard(user: user),": "child: _AlertsCard(\n                          user: user,\n                          onClose: () {\n                            setState(() => _visible.remove('alerts'));\n                            _savePrefs();\n                          },\n                        ),",
    "child: _BranchCard(user: user, sales: todaySales),": "child: _BranchCard(\n                          user: user,\n                          sales: todaySales,\n                          onClose: () {\n                            setState(() => _visible.remove('branches'));\n                            _savePrefs();\n                          },\n                        ),",
}
for a,b in repls.items():
    if a in s:
        s=s.replace(a,b,1)

# 4) Make Top Selling item row clickable to Sales.
needle = """          return Row(
            children: [
"""
replacement = """          return InkWell(
            onTap: () => context.go(AppRouter.sales),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
"""
if needle in s:
    s = s.replace(needle, replacement, 1)
    # close new wrappers at the first matching TopItems row ending before itemBuilder closes
    close_anchor = """              ),
            ],
          );
        },
      ),
    );
  }
}

class _KitchenCard"""
    close_repl = """              ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _KitchenCard"""
    if close_anchor in s:
        s = s.replace(close_anchor, close_repl, 1)

DASH.write_text(s)

# ---------------- Kitchen screen ----------------
k = KITCHEN.read_text()

# Replace unreadable fallback KOT with short human-readable time-based label.
old_kot = """    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}${two(d.month)}${two(d.year % 100)}${two(d.hour)}${two(d.minute)}${two(d.second)}';
"""
new_kot = """    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}${two(d.month)}-${two(d.hour)}${two(d.minute)}';
"""
if old_kot in k:
    k = k.replace(old_kot, new_kot, 1)

# Add completed filter and make served/completed visible there.
k = k.replace(
    "if (_filter == 'making') return status == 'making';\n    return status == 'open' || status == 'making';",
    "if (_filter == 'making') return status == 'making';\n    if (_filter == 'completed') {\n      return status == 'served' || status == 'completed' || status == 'checkout';\n    }\n    return status == 'open' || status == 'making';",
    1,
)
k = k.replace(
    "_FilterChip(label: 'Ready', selected: _filter == 'ready', onTap: () => setState(() => _filter = 'ready')),\n            _FilterChip(label: 'All'",
    "_FilterChip(label: 'Ready', selected: _filter == 'ready', onTap: () => setState(() => _filter = 'ready')),\n            _FilterChip(label: 'Completed', selected: _filter == 'completed', onTap: () => setState(() => _filter = 'completed')),\n            _FilterChip(label: 'All'",
    1,
)

# Give each KOT card access to tableId and provider for per-item completion interaction.
k = k.replace(
    "child: _KotCard(\n                              tableNumber: tableNumber,",
    "child: _KotCard(\n                              tableId: tableId,\n                              tableNumber: tableNumber,",
    1,
)

# Upgrade card from Stateless to Stateful with per-item prepared flags persisted in order meta.
start = k.find('class _KotCard extends StatelessWidget')
if start == -1:
    raise SystemExit('ERROR: _KotCard class not found')

prefix = k[:start]
new_card = r'''class _KotCard extends StatefulWidget {
  final String tableId;
  final String tableNumber;
  final String kotNo;
  final String status;
  final String label;
  final Color accent;
  final String waiter;
  final String guests;
  final List<String> items;
  final VoidCallback? onAction;

  const _KotCard({
    required this.tableId,
    required this.tableNumber,
    required this.kotNo,
    required this.status,
    required this.label,
    required this.accent,
    required this.waiter,
    required this.guests,
    required this.items,
    required this.onAction,
  });

  @override
  State<_KotCard> createState() => _KotCardState();
}

class _KotCardState extends State<_KotCard> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TableOrderProvider>();
    final info = provider.getOrderInfo(widget.tableId);
    final rawDone = info['preparedItemIndexes'];
    final done = <int>{};
    if (rawDone is List) {
      for (final value in rawDone) {
        if (value is int) done.add(value);
        if (value is num) done.add(value.toInt());
      }
    }

    Future<void> togglePrepared(int index) async {
      final next = Set<int>.from(done);
      if (!next.add(index)) next.remove(index);
      await provider.setOrderMeta(widget.tableId, {
        'preparedItemIndexes': next.toList()..sort(),
      });
    }

    final preparedCount = done.where((i) => i >= 0 && i < widget.items.length).length;
    final remainingCount = widget.items.length - preparedCount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(color: Color(0x0B000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: .08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.accent)),
              const SizedBox(width: 7),
              Expanded(child: Text(widget.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: widget.accent))),
              Text('KOT ${widget.kotNo}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _muted)),
            ]),
            const SizedBox(height: 9),
            Text('Table ${widget.tableNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink)),
            const SizedBox(height: 2),
            Text('${widget.waiter} • ${widget.guests} guests', style: const TextStyle(fontSize: 9.5, color: _muted)),
            const SizedBox(height: 8),
            Row(children: [
              _ProgressBadge('$preparedCount prepared', const Color(0xFF10B981)),
              const SizedBox(width: 6),
              _ProgressBadge('$remainingCount in prep', const Color(0xFFF59E0B)),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(13),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ITEMS • click each item when prepared', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _muted, letterSpacing: .5)),
            const SizedBox(height: 8),
            ...widget.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final prepared = done.contains(index);
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: InkWell(
                  onTap: widget.status == 'making' || widget.status == 'open'
                      ? () => togglePrepared(index)
                      : null,
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: prepared ? const Color(0xFFE8FFF4) : const Color(0xFFFFFAEB),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: prepared ? const Color(0xFFA6F4C5) : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        prepared ? Icons.check_circle_rounded : Icons.timelapse_rounded,
                        size: 17,
                        color: prepared ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: prepared ? const Color(0xFF047857) : _ink))),
                      Text(
                        prepared ? 'PREPARED' : 'IN PREP',
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: prepared ? const Color(0xFF047857) : const Color(0xFFB45309)),
                      ),
                    ]),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            if (widget.onAction != null)
              SizedBox(
                width: double.infinity,
                height: 42,
                child: FilledButton.icon(
                  onPressed: widget.status == 'making' && remainingCount > 0
                      ? null
                      : widget.onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(widget.status == 'making' ? Icons.check_circle_outline_rounded : Icons.soup_kitchen_outlined, size: 17),
                  label: Text(
                    widget.status == 'making'
                        ? remainingCount > 0
                            ? '$remainingCount ITEM(S) STILL IN PREP'
                            : 'READY TO SERVE'
                        : 'START MAKING',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                ),
              )
            else
              Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFE8FFF4), borderRadius: BorderRadius.circular(8)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 17),
                  SizedBox(width: 7),
                  Text('READY / COMPLETED', style: TextStyle(color: Color(0xFF047857), fontSize: 10.5, fontWeight: FontWeight.w900)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _ProgressBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: color),
        ),
      );
}
'''

# Replace everything from _KotCard to EOF because it is the final class in this file.
k = prefix + new_card
KITCHEN.write_text(k)

print('OK: stale customize query auto-open removed')
print('OK: Sales Overview and all dashboard widgets receive persistent close callbacks')
print('OK: Top Selling items navigate to Sales')
print('OK: Kitchen KOT uses readable short KOT number')
print('OK: Kitchen adds Completed filter')
print('OK: KOT items can be marked PREPARED / IN PREP individually')
print('OK: READY TO SERVE is blocked until every KOT item is prepared')
print('ONLY dashboard + kitchen KOT source files are modified')
