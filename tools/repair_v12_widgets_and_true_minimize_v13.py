from pathlib import Path
import re

S = Path('lib/components/layout/main_shell_v7.dart')
D = Path('lib/screens/restaurant_dashboard_screen_v3.dart')

s = S.read_text()
d = D.read_text()

# 1) Repair the V12 toolbar callback. V11 already introduced _showPageWidgets(route,title),
# which correctly keeps non-dashboard pages local and sends dashboard a fresh customize nonce.
# V12 accidentally referenced undefined currentRoute/_pageWidgetVisible.
pattern = re.compile(r'onAddWidget:\s*\(\)\s*\{\s*// WIDGET_BUTTON_V12[\s\S]*?\n\s*\},')
m = pattern.search(s)
if m:
    s = s[:m.start()] + 'onAddWidget: () => _showPageWidgets(route, title),' + s[m.end():]
    print('OK: repaired Widgets toolbar callback to existing page-aware handler')
elif 'onAddWidget: () => _showPageWidgets(route, title),' in s:
    print('OK: Widgets toolbar callback already repaired')
else:
    # Last-resort structural replacement of a callback containing the broken names.
    pattern2 = re.compile(r'onAddWidget:\s*\(\)\s*\{[\s\S]{0,900}?(?:currentRoute|_pageWidgetVisible)[\s\S]{0,900}?\n\s*\},')
    m2 = pattern2.search(s)
    if not m2:
        raise SystemExit('ERROR: could not locate broken Widgets callback')
    s = s[:m2.start()] + 'onAddWidget: () => _showPageWidgets(route, title),' + s[m2.end():]
    print('OK: structurally repaired Widgets toolbar callback')

# 2) True minimize: fixed parent heights were reserving 300px even when _Panel hid its body.
# Remove those fixed heights from the six standard dashboard widget slots.
classes = (
    '_SalesOverviewCard', '_RecentOrdersCard', '_TopItemsCard',
    '_KitchenCard', '_AlertsCard', '_BranchCard'
)
removed = 0
for cls in classes:
    # Accept any legacy standardized height used by prior passes.
    new_d, n = re.subn(
        rf'(width:\s*[^,]+,\n\s*)height:\s*(?:260|300|330|360),\n(\s*child:\s*{re.escape(cls)})',
        rf'\1\2',
        d,
        count=1,
    )
    d = new_d
    removed += n

# The normal _Panel body must provide its own bounded height now that the outer slot is flexible.
old = '          Expanded(child: widget.child),\n'
new = '          SizedBox(height: 230, child: widget.child),\n'
if old in d:
    d = d.replace(old, new, 1)
    print('OK: dashboard panel now owns its expanded body height')
elif new in d:
    print('OK: dashboard panel body height already self-contained')
else:
    raise SystemExit('ERROR: normal dashboard panel body anchor not found')

# 3) Ensure the dashboard query customizer hook added by V12 remains wired.
if '_checkCustomizeRequest();' not in d or 'DASHBOARD_CUSTOMIZE_V12' not in d:
    raise SystemExit('ERROR: V12 dashboard customizer hook is missing')

# 4) Ensure top KPI drag is immediate Draggable after the V12 source pass.
kpi_start = d.find('final byId = {for (final kpi in kpis) kpi.id: kpi};')
kpi_end = d.find('const SizedBox(height: 16)', kpi_start)
if kpi_start < 0 or kpi_end < 0:
    raise SystemExit('ERROR: KPI region missing')
region = d[kpi_start:kpi_end]
if 'LongPressDraggable<String>' in region:
    region = region.replace('LongPressDraggable<String>', 'Draggable<String>')
    d = d[:kpi_start] + region + d[kpi_end:]
if 'Draggable<String>' not in region:
    raise SystemExit('ERROR: KPI Draggable missing')

S.write_text(s)
D.write_text(d)

print(f'OK: removed {removed} fixed widget slot heights for real minimize/reflow')
print('OK: minimized widgets collapse to their header instead of leaving a blank 300px slot')
print('OK: dashboard Widgets button uses page-aware V11 handler + V12 nonce customizer')
print('OK: top KPI cards remain immediate Draggable')
print('ONLY main_shell_v7.dart and restaurant_dashboard_screen_v3.dart modified')
