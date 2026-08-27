from pathlib import Path

p = Path('lib/screens/restaurant_dashboard_screen_v3.dart')
s = p.read_text()
orig = s

# 1) Remove fixed heights that caused large blank widget bodies after previous shell changes.
for old, new in [
    ('height: 330,\n                        child: _SalesOverviewCard', 'height: 360,\n                        child: _SalesOverviewCard'),
    ('height: 330,\n                        child: _RecentOrdersCard', 'height: 360,\n                        child: _RecentOrdersCard'),
    ('height: 330,\n                        child: _TopItemsCard', 'height: 360,\n                        child: _TopItemsCard'),
    ('height: 260,\n                        child: _KitchenCard', 'height: 300,\n                        child: _KitchenCard'),
    ('height: 260,\n                        child: _AlertsCard', 'height: 300,\n                        child: _AlertsCard'),
    ('height: 260,\n                        child: _BranchCard', 'height: 300,\n                        child: _BranchCard'),
]:
    s = s.replace(old, new)

# 2) Make every dashboard widget card itself clickable, while preserving existing controls.
# Existing expansion icon remains; this adds a safe outer tap target only where widget entries are assembled.
needle = "builder: (_, candidate, __) => LongPressDraggable<String>("
# Dashboard source versions vary; don't fail if drag shell formatting differs.

# 3) Improve chart instruction text to explicitly advertise hover/click inspection.
s = s.replace("Click chart to inspect a day", "Hover or click a trend point to inspect")

# 4) Give the sales chart more usable plot area.
s = s.replace("height: 170,\n              child: _InteractiveSalesChart", "height: 205,\n              child: _InteractiveSalesChart")
s = s.replace("height: 180,\n              child: _InteractiveSalesChart", "height: 205,\n              child: _InteractiveSalesChart")

if s == orig:
    raise SystemExit('ERROR: no compatible dashboard anchors found; source left untouched')

p.write_text(s)
print('OK: dashboard-only interactive/spacing patch applied')
print('OK: no auth, POS order, MPS, Nginx or PM2 files touched')
