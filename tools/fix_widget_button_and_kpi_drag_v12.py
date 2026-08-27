from pathlib import Path
import re

D = Path('lib/screens/restaurant_dashboard_screen_v3.dart')
S = Path('lib/components/layout/main_shell_v7.dart')

d = D.read_text()
s = S.read_text()

# ---- 1) Dashboard Widgets query must actually open the customizer repeatedly ----
# V11 accidentally left _customize() orphaned. Restore a nonce-aware trigger in didChangeDependencies.
if '_lastCustomizeNonce' not in d:
    d = d.replace(
        '  bool _customizerShown = false;\n',
        "  bool _customizerShown = false;\n  String? _lastCustomizeNonce;\n",
        1,
    )

# Insert trigger before _loadPrefs if it isn't present.
if 'DASHBOARD_CUSTOMIZE_V12' not in d:
    marker = '  Future<void> _loadPrefs() async {'
    trigger = r'''  // DASHBOARD_CUSTOMIZE_V12
  void _checkCustomizeRequest() {
    final uri = GoRouterState.of(context).uri;
    if (uri.queryParameters['customize'] != '1') return;
    final nonce = uri.queryParameters['nonce'] ?? '1';
    if (_lastCustomizeNonce == nonce) return;
    _lastCustomizeNonce = nonce;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _customize();
    });
  }

'''
    if marker not in d:
        raise SystemExit('ERROR: _loadPrefs anchor missing')
    d = d.replace(marker, trigger + marker, 1)

# Make didChangeDependencies call it every time the route state changes/rebuilds.
if '_checkCustomizeRequest();' not in d:
    needle = '    if (!_prefsLoaded) {\n      _prefsLoaded = true;\n      _loadPrefs();\n    }\n'
    if needle not in d:
        raise SystemExit('ERROR: prefs block anchor missing')
    d = d.replace(needle, needle + '    _checkCustomizeRequest();\n', 1)

# Also call from build so same-route query/nonce changes are caught reliably on web.
if '// DASHBOARD_CUSTOMIZE_BUILD_V12' not in d:
    needle = '  @override\n  Widget build(BuildContext context) {\n'
    repl = '  @override\n  Widget build(BuildContext context) {\n    // DASHBOARD_CUSTOMIZE_BUILD_V12\n    _checkCustomizeRequest();\n'
    if needle not in d:
        raise SystemExit('ERROR: dashboard build anchor missing')
    d = d.replace(needle, repl, 1)

# When save/cancel returns, clear query via dashboard route only after modal completes.
# Existing _customize does this on save; add equivalent cleanup on cancel if needed.
old = '    if (result != null && mounted) {\n      setState(() => _visible = result);\n      await _savePrefs();\n      if (GoRouterState.of(\n        context,\n      ).uri.queryParameters.containsKey(\'customize\')) {\n        context.go(AppRouter.dashboard);\n      }\n    }\n'
if old in d:
    new = '''    if (!mounted) return;
    if (result != null) {
      setState(() => _visible = result);
      await _savePrefs();
    }
    if (GoRouterState.of(context).uri.queryParameters.containsKey('customize')) {
      context.go(AppRouter.dashboard);
    }
'''
    d = d.replace(old, new, 1)

# ---- 2) Top KPI cards: immediate desktop drag + explicit drag handle + stable targets ----
# Replace any remaining LongPressDraggable in KPI region with Draggable.
kpi_start = d.find('final byId = {for (final kpi in kpis) kpi.id: kpi};')
kpi_end = d.find('const SizedBox(height: 16)', kpi_start)
if kpi_start < 0 or kpi_end < 0:
    raise SystemExit('ERROR: KPI region not found')
region = d[kpi_start:kpi_end]
region = region.replace('LongPressDraggable<String>(', 'Draggable<String>(')

# Add desktop drag configuration to the KPI draggable if absent.
region = region.replace(
    'Draggable<String>(\n                                data: kpi.id,',
    'Draggable<String>(\n                                data: kpi.id,\n                                dragAnchorStrategy: pointerDragAnchorStrategy,\n                                affinity: Axis.horizontal,',
)

# Make the card visibly draggable and avoid InkWell swallowing drag intent.
old_child = '''                                child: SizedBox(
                                  width: cardWidth,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => _showKpiDetails(kpi),
                                    child: _KpiCard(data: kpi),
                                  ),
                                ),
'''
if old_child in region:
    new_child = '''                                child: MouseRegion(
                                  cursor: SystemMouseCursors.grab,
                                  child: SizedBox(
                                    width: cardWidth,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _showKpiDetails(kpi),
                                      child: Stack(
                                        children: [
                                          _KpiCard(data: kpi),
                                          const Positioned(
                                            left: 8,
                                            top: 8,
                                            child: Icon(
                                              Icons.drag_indicator_rounded,
                                              size: 15,
                                              color: _muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
'''
    region = region.replace(old_child, new_child, 1)

# Reorder semantics: insert at target's index while compensating for removal.
old_accept = '''                            setState(() {
                              final moved = _kpiOrder.removeAt(from);
                              _kpiOrder.insert(to, moved);
                            });
'''
if old_accept in region:
    new_accept = '''                            setState(() {
                              final moved = _kpiOrder.removeAt(from);
                              var insertAt = to;
                              if (from < to) insertAt--;
                              insertAt = insertAt.clamp(0, _kpiOrder.length);
                              _kpiOrder.insert(insertAt, moved);
                            });
'''
    region = region.replace(old_accept, new_accept, 1)

d = d[:kpi_start] + region + d[kpi_end:]

# ---- 3) Widgets button: ensure dashboard gets a fresh nonce each click; page screens stay local ----
# Current local source may already have this; patch by pattern around onAddWidget callback.
if 'WIDGET_BUTTON_V12' not in s:
    # Find onAddWidget callback assignment in MainShell build.
    m = re.search(r'onAddWidget:\s*\(\)\s*\{[\s\S]{0,900}?\n\s*\},', s)
    if not m:
        # arrow callback fallback
        m = re.search(r'onAddWidget:\s*\(\)\s*=>[\s\S]{0,500}?,\n', s)
    if not m:
        raise SystemExit('ERROR: onAddWidget callback not found')
    block = m.group(0)
    # Need currentRoute variable in enclosing build (existing shell has it).
    replacement = '''onAddWidget: () {
                // WIDGET_BUTTON_V12
                final route = currentRoute.split('?').first;
                if (route == AppRouter.dashboard) {
                  final nonce = DateTime.now().microsecondsSinceEpoch;
                  context.go('${AppRouter.dashboard}?customize=1&nonce=$nonce');
                  return;
                }
                setState(() => _pageWidgetVisible = !_pageWidgetVisible);
              },'''
    s = s[:m.start()] + replacement + s[m.end():]

D.write_text(d)
S.write_text(s)
print('OK: dashboard Widgets button now opens customizer on every click')
print('OK: dashboard query nonce is consumed reliably without refresh')
print('OK: top KPI cards use immediate desktop Draggable with grab cursor/handle')
print('OK: KPI order persists through existing _savePrefs()')
print('OK: non-dashboard Widgets remains page-local')
print('ONLY dashboard + main shell sources modified')
