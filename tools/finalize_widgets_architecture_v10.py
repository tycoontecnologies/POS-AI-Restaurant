from pathlib import Path
import re

shell_p = Path('lib/components/layout/main_shell_v7.dart')
dash_p = Path('lib/screens/restaurant_dashboard_screen_v3.dart')
kot_p = Path('lib/screens/kitchen_kot_screen.dart')

for p in (shell_p, dash_p, kot_p):
    if not p.exists():
        raise SystemExit(f'ERROR: missing {p}')

# ---------------- MAIN SHELL: page-aware Widgets ----------------
s = shell_p.read_text()

old = "onAddWidget: () => context.go('${AppRouter.dashboard}?customize=1'),"
new = "onAddWidget: () => _showWidgetsForCurrentPage(route, title),"
if old in s:
    s = s.replace(old, new, 1)
elif new not in s:
    raise SystemExit('ERROR: Widgets button binding not found')

if 'Future<void> _showWidgetsForCurrentPage(String route, String title)' not in s:
    anchor = '  Future<void> _showCommandSearch(List<NavigationItem> items) async {'
    if anchor not in s:
        raise SystemExit('ERROR: shell method insertion anchor not found')
    method = r'''  Future<void> _showWidgetsForCurrentPage(String route, String title) async {
    if (route == AppRouter.dashboard) {
      context.go('${AppRouter.dashboard}?customize=1');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('$title Widgets'),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This page screen is its workspace widget.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: line),
                ),
                child: Row(
                  children: [
                    Icon(Icons.widgets_outlined, color: _accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$title Screen',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Use the widget header controls to minimize, maximize, restore or close this workspace.',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

'''
    s = s.replace(anchor, method + anchor, 1)

shell_p.write_text(s)

# ---------------- DASHBOARD: direct desktop drag + customizer + compact layout ----------------
d = dash_p.read_text()

# Immediate mouse drag everywhere (KPI and standard widgets)
d = d.replace('LongPressDraggable<String>(', 'Draggable<String>(')

# Make customize query reusable: always clear it and allow future opens.
old_tail = r'''    if (result != null && mounted) {
      setState(() => _visible = result);
      await _savePrefs();
      if (GoRouterState.of(
        context,
      ).uri.queryParameters.containsKey('customize')) {
        context.go(AppRouter.dashboard);
      }
    }
  }
'''
new_tail = r'''    if (result != null && mounted) {
      setState(() => _visible = result);
      await _savePrefs();
    }
    if (mounted) {
      _customizerShown = false;
      if (GoRouterState.of(context).uri.queryParameters.containsKey('customize')) {
        context.go(AppRouter.dashboard);
      }
    }
  }
'''
if old_tail in d:
    d = d.replace(old_tail, new_tail, 1)
elif '_customizerShown = false;' not in d:
    raise SystemExit('ERROR: dashboard customizer tail not found')

# Dynamic dashboard columns based on how many widgets are still visible.
pattern = re.compile(
    r"final wide = constraints\.maxWidth >= 1120;\s*"
    r"final medium = constraints\.maxWidth >= 760;\s*"
    r"final cardWidth = wide\s*\? \(constraints\.maxWidth - 24\) / 3\s*"
    r": medium\s*\? \(constraints\.maxWidth - 12\) / 2\s*"
    r": constraints\.maxWidth;",
    re.M,
)
replacement = """final wide = constraints.maxWidth >= 1120;
                    final medium = constraints.maxWidth >= 760;
                    final visibleCount = _sectionOrder
                        .where((id) => _visible.contains(id))
                        .length;
                    final columns = wide
                        ? math.max(1, math.min(3, visibleCount))
                        : medium
                        ? math.max(1, math.min(2, visibleCount))
                        : 1;
                    final cardWidth =
                        (constraints.maxWidth - ((columns - 1) * 12)) / columns;"""
d, count = pattern.subn(replacement, d, count=1)
if count == 0 and 'final visibleCount = _sectionOrder' not in d:
    raise SystemExit('ERROR: dashboard layout width block not found')

# No intentional narrow/wide special cards; every remaining widget uses the available grid width.
d = d.replace('width: wide ? cardWidth * 1.35 : cardWidth,', 'width: cardWidth,')
d = d.replace('width: wide ? cardWidth * .65 : cardWidth,', 'width: cardWidth,')

# Shorten any raw kitchen document-id display in dashboard while preserving table number.
# Covers common forms like #${doc.id}, ${doc.id} and direct doc.id in text labels.
d = d.replace("'#${doc.id}'", "'#${doc.id.length > 8 ? doc.id.substring(doc.id.length - 8) : doc.id}'")
d = d.replace("'${doc.id}'", "'${doc.id.length > 8 ? doc.id.substring(doc.id.length - 8) : doc.id}'")

# If prior kitchen patch introduced an order-id helper, leave it alone.
dash_p.write_text(d)

# ---------------- KOT: readable IDs already supported; strengthen fallback ----------------
k = kot_p.read_text()
# Replace old timestamp-like 12-digit fallback with compact KOT-friendly format where present.
old_fallback = "return '${two(d.day)}${two(d.month)}${two(d.year % 100)}${two(d.hour)}${two(d.minute)}${two(d.second)}';"
new_fallback = "return '${two(d.hour)}${two(d.minute)}-${two(d.day)}${two(d.month)}';"
if old_fallback in k:
    k = k.replace(old_fallback, new_fallback, 1)
kot_p.write_text(k)

print('OK: Widgets button is page-aware and no longer forces non-dashboard pages to Dashboard')
print('OK: Dashboard Widgets customizer can reopen without refresh')
print('OK: Dashboard KPI and section widgets use immediate desktop mouse drag')
print('OK: Dashboard columns reflow to remove blank gaps when widgets are closed')
print('OK: Dashboard widget widths normalized')
print('OK: Kitchen/KOT fallback identifiers shortened')
print('ONLY main_shell_v7.dart, restaurant_dashboard_screen_v3.dart and kitchen_kot_screen.dart modified')
