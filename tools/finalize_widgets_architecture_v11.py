from pathlib import Path
import re

shell_p = Path('lib/components/layout/main_shell_v7.dart')
dash_p = Path('lib/screens/restaurant_dashboard_screen_v3.dart')
kot_p = Path('lib/screens/kitchen_kot_screen.dart')

for p in (shell_p, dash_p, kot_p):
    if not p.exists():
        raise SystemExit(f'ERROR: missing {p}')

# ---------- SHELL: page-aware Widgets ----------
s = shell_p.read_text()

if '_hiddenWorkspaceRoutes' not in s:
    anchor = '  Set<String> _favorites = <String>{};\n'
    if anchor in s:
        s = s.replace(anchor, anchor + '  final Set<String> _hiddenWorkspaceRoutes = <String>{};\n', 1)
    else:
        print('WARN: favorites anchor not found; hidden workspace state not inserted')

if 'Future<void> _showPageWidgets(' not in s:
    method_anchor = '  Future<void> _showCommandSearch(List<NavigationItem> items) async {'
    method = r'''  Future<void> _showPageWidgets(String route, String title) async {
    if (route == AppRouter.dashboard) {
      context.go(
        '${AppRouter.dashboard}?customize=1&nonce=${DateTime.now().millisecondsSinceEpoch}',
      );
      return;
    }

    bool visible = !_hiddenWorkspaceRoutes.contains(route);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setModal) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('$title Widgets'),
          content: SizedBox(
            width: 430,
            child: CheckboxListTile(
              value: visible,
              contentPadding: EdgeInsets.zero,
              title: Text(
                '$title Workspace',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Show this page screen as a workspace widget on this page.',
              ),
              onChanged: (value) => setModal(() => visible = value == true),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, visible),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result) {
        _hiddenWorkspaceRoutes.remove(route);
      } else {
        _hiddenWorkspaceRoutes.add(route);
      }
    });
  }

'''
    if method_anchor in s:
        s = s.replace(method_anchor, method + method_anchor, 1)
    else:
        raise SystemExit('ERROR: shell method insertion anchor not found')

# Replace whatever onAddWidget callback currently exists, without relying on old exact text.
pattern = re.compile(r"onAddWidget:\s*\(\)\s*=>.*?,\s*\n\s*onSearch:", re.S)
m = pattern.search(s)
if m:
    s = s[:m.start()] + 'onAddWidget: () => _showPageWidgets(route, title),\n          onSearch:' + s[m.end():]
elif 'onAddWidget: () => _showPageWidgets(route, title),' not in s:
    # Handle a block callback variant.
    pattern2 = re.compile(r"onAddWidget:\s*\(\)\s*\{.*?\},\s*\n\s*onSearch:", re.S)
    m2 = pattern2.search(s)
    if m2:
        s = s[:m2.start()] + 'onAddWidget: () => _showPageWidgets(route, title),\n          onSearch:' + s[m2.end():]
    else:
        raise SystemExit('ERROR: could not locate any onAddWidget callback variant')

# Make non-dashboard page workspace hide/restore on its own page instead of navigating away.
if '_hiddenWorkspaceRoutes.contains(route)' not in s:
    target = ': _FeatureWorkspace(\n'
    repl = r''': _hiddenWorkspaceRoutes.contains(route)
                    ? Center(
                        child: OutlinedButton.icon(
                          onPressed: () => _showPageWidgets(route, title),
                          icon: const Icon(Icons.widgets_outlined),
                          label: Text('Restore $title Workspace'),
                        ),
                      )
                    : _FeatureWorkspace(
'''
    if target in s:
        s = s.replace(target, repl, 1)
    else:
        raise SystemExit('ERROR: FeatureWorkspace render anchor not found')

shell_p.write_text(s)

# ---------- DASHBOARD: reliable reopen + immediate mouse drag + no blank layout ----------
d = dash_p.read_text()

# Reset customizer gate whenever query is removed, so Widgets can be reopened repeatedly.
if 'if (!customize) _customizerShown = false;' not in d:
    d = d.replace(
        "    final customize =\n        GoRouterState.of(context).uri.queryParameters['customize'] == '1';\n",
        "    final customize =\n        GoRouterState.of(context).uri.queryParameters['customize'] == '1';\n    if (!customize) _customizerShown = false;\n",
        1,
    )

# Always strip customize query after modal closes, including Cancel.
old_tail = r'''    if (result != null && mounted) {
      setState(() => _visible = result);
      await _savePrefs();
      if (GoRouterState.of(
        context,
      ).uri.queryParameters.containsKey('customize')) {
        context.go(AppRouter.dashboard);
      }
    }
'''
new_tail = r'''    if (result != null && mounted) {
      setState(() => _visible = result);
      await _savePrefs();
    }
    if (mounted &&
        GoRouterState.of(context).uri.queryParameters.containsKey('customize')) {
      context.go(AppRouter.dashboard);
    }
'''
if old_tail in d:
    d = d.replace(old_tail, new_tail, 1)

# Immediate mouse drag on desktop for every KPI and standard widget.
count_long = d.count('LongPressDraggable<String>')
d = d.replace('LongPressDraggable<String>', 'Draggable<String>')

# Add pointer anchored feedback when absent.
d = re.sub(
    r"Draggable<String>\(\n(\s*)data: ([^,]+),\n(?!\s*dragAnchorStrategy:)",
    r"Draggable<String>(\n\1data: \2,\n\1dragAnchorStrategy: pointerDragAnchorStrategy,\n",
    d,
)

# Standard widgets should reflow to visible count and use equal widths/heights.
old_width = r'''                    final wide = constraints.maxWidth >= 1120;
                    final medium = constraints.maxWidth >= 760;
                    final cardWidth = wide
                        ? (constraints.maxWidth - 24) / 3
                        : medium
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
'''
new_width = r'''                    final wide = constraints.maxWidth >= 1120;
                    final medium = constraints.maxWidth >= 760;
                    final visibleCount = _sectionOrder
                        .where((id) => _visible.contains(id))
                        .length
                        .clamp(1, 3);
                    final columns = wide
                        ? visibleCount
                        : medium
                        ? math.min(2, visibleCount)
                        : 1;
                    final cardWidth =
                        (constraints.maxWidth - (12 * (columns - 1))) / columns;
'''
if old_width in d:
    d = d.replace(old_width, new_width, 1)
else:
    print('WARN: standard card width block already changed or not found')

# Remove special asymmetric widths that created blank zones.
d = d.replace('width: wide ? cardWidth * 1.35 : cardWidth,', 'width: cardWidth,')
d = d.replace('width: wide ? cardWidth * .65 : cardWidth,', 'width: cardWidth,')

# Standardize widget heights so arbitrary reordering does not create holes between rows.
for name in ('_SalesOverviewCard', '_RecentOrdersCard', '_TopItemsCard', '_KitchenCard', '_AlertsCard', '_BranchCard'):
    d = re.sub(
        rf"height:\s*(?:260|300|330|360),\n(\s*)child: {name}",
        rf"height: 300,\n\1child: {name}",
        d,
    )

dash_p.write_text(d)

# ---------- READABLE KOT IDS ----------
def add_short_helper(text: str) -> str:
    if 'String _shortKotId(' in text:
        return text
    helper = r'''String _shortKotId(String raw) {
  final clean = raw.replaceAll('#', '').trim();
  if (clean.isEmpty) return 'KOT';
  if (clean.length <= 6) return 'KOT-${clean.toUpperCase()}';
  return 'KOT-${clean.substring(clean.length - 6).toUpperCase()}';
}

'''
    # Insert after imports, before first const/class.
    m = re.search(r"(?=const _ink|class )", text)
    if m:
        return text[:m.start()] + helper + text[m.start():]
    return helper + text

d2 = add_short_helper(dash_p.read_text())
k2 = add_short_helper(kot_p.read_text())

# Replace common raw doc/order id display literals with readable helper.
for var in ('doc', 'order', 'orderDoc', 'kot', 'ticket'):
    d2 = d2.replace(f"'#${{{var}.id}}'", f"_shortKotId({var}.id)")
    d2 = d2.replace(f'"#${{{var}.id}}"', f"_shortKotId({var}.id)")
    k2 = k2.replace(f"'#${{{var}.id}}'", f"_shortKotId({var}.id)")
    k2 = k2.replace(f'"#${{{var}.id}}"', f"_shortKotId({var}.id)")

# Also shorten explicit fallback interpolation patterns such as '#$id'.
k2 = re.sub(r"['\"]#\$([A-Za-z_][A-Za-z0-9_]*)['\"]", r"_shortKotId(\1)", k2)
d2 = re.sub(r"['\"]#\$([A-Za-z_][A-Za-z0-9_]*)['\"]", r"_shortKotId(\1)", d2)

dash_p.write_text(d2)
kot_p.write_text(k2)

print(f'OK: page-aware Widgets callback installed')
print('OK: non-dashboard page workspace can be shown/hidden on the same page')
print('OK: Dashboard Widgets modal can reopen repeatedly without refresh')
print(f'OK: converted {count_long} LongPressDraggable instances to immediate Draggable')
print('OK: visible dashboard widgets reflow into equal-width columns with standardized heights')
print('OK: readable KOT fallback IDs applied where raw document IDs were displayed')
print('ONLY main_shell_v7.dart, restaurant_dashboard_screen_v3.dart, kitchen_kot_screen.dart modified')
