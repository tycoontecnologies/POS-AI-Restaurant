from pathlib import Path

p = Path('lib/screens/restaurant_dashboard_screen_v3.dart')
s = p.read_text()

# Tighten vertical spacing between KPI strip and dashboard widgets.
s = s.replace('const SizedBox(height: 16),\n                LayoutBuilder(', 'const SizedBox(height: 10),\n                LayoutBuilder(', 1)
s = s.replace('runSpacing: 12,\n                      children: orderedIds.map((id) {', 'runSpacing: 10,\n                      children: orderedIds.map((id) {', 1)

# Lower dashboard row was oversized for its actual content. Keep it compact.
s = s.replace("height: 260,\n                        child: _KitchenCard(orders: orders),", "height: 220,\n                        child: _KitchenCard(orders: orders),", 1)
s = s.replace("height: 260,\n                        child: _AlertsCard(user: user),", "height: 220,\n                        child: _AlertsCard(user: user),", 1)
s = s.replace("height: 260,\n                        child: _BranchCard(user: user, sales: todaySales),", "height: 220,\n                        child: _BranchCard(user: user, sales: todaySales),", 1)

# Top Selling Items should use the full available card height instead of leaving a
# blank lower half when only a handful of products exist.
old = """      child: ListView.separated(\n        itemCount: math.min(15, names.length),\n        separatorBuilder: (_, __) => const SizedBox(height: 7),\n        itemBuilder: (_, i) {\n          final name = names[i];\n          final count = qty[name] ?? 0;\n          return Row(\n"""
new = """      child: names.isEmpty\n          ? const Center(\n              child: Text(\n                'No sales yet',\n                style: TextStyle(fontSize: 10, color: _muted),\n              ),\n            )\n          : Column(\n              children: List.generate(math.min(8, names.length), (i) {\n                final name = names[i];\n                final count = qty[name] ?? 0;\n                return Expanded(\n                  child: Align(\n                    alignment: Alignment.center,\n                    child: Row(\n"""
if old not in s:
    raise SystemExit('ERROR: Top Selling Items anchor not found')
s = s.replace(old, new, 1)

old_end = """            ],\n          );\n        },\n      ),\n    );\n  }\n}\n\nclass _KitchenCard"""
new_end = """                      ],\n                    ),\n                  ),\n                );\n              }),\n            ),\n    );\n  }\n}\n\nclass _KitchenCard"""
if old_end not in s:
    raise SystemExit('ERROR: Top Selling Items closing anchor not found')
s = s.replace(old_end, new_end, 1)

# Branch card: distribute its content vertically instead of pinning everything at
# the top and leaving a large blank lower area.
s = s.replace("""      child: Column(\n        children: [\n          ListTile(""", """      child: Column(\n        mainAxisAlignment: MainAxisAlignment.spaceBetween,\n        children: [\n          ListTile(""", 1)

# Panel itself: reduce padding slightly so content gets more usable area.
s = s.replace('padding: const EdgeInsets.all(14),\n    decoration: _cardDecoration(),', 'padding: const EdgeInsets.all(12),\n    decoration: _cardDecoration(),', 1)

p.write_text(s)
print('OK: dashboard vertical gaps tightened')
print('OK: lower widgets compacted 260px -> 220px')
print('OK: Top Selling Items now fills its card height')
print('OK: Branch Performance now distributes content vertically')
print('OK: panel padding reduced 14px -> 12px')
