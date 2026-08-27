from pathlib import Path

shell_path = Path('lib/components/layout/main_shell_v7.dart')
dash_path = Path('lib/screens/restaurant_dashboard_screen_v3.dart')
kitchen_path = Path('lib/screens/kitchen_kot_screen.dart')

for p in (shell_path, dash_path, kitchen_path):
    if not p.exists():
        raise SystemExit(f'ERROR: missing {p}')

# ---------------- SHELL: page-aware Widgets ----------------
s = shell_path.read_text()

# Add a stable key so the top-bar Widgets button can control the current page widget.
anchor = "  Set<String> _favorites = <String>{};\n"
if "_workspaceKey" not in s:
    if anchor not in s:
        raise SystemExit('ERROR: shell state anchor not found')
    s = s.replace(anchor, anchor + "  final GlobalKey<_FeatureWorkspaceState> _workspaceKey = GlobalKey<_FeatureWorkspaceState>();\n", 1)

# Replace Dashboard-only routing with page-aware behavior.
old = "          onAddWidget: () => context.go('${AppRouter.dashboard}?customize=1'),"
new = """          onAddWidget: () {
            if (route == AppRouter.dashboard) {
              context.go('${AppRouter.dashboard}?customize=1');
            } else {
              _showCurrentPageWidgets(title);
            }
          },"""
if old in s:
    s = s.replace(old, new, 1)
elif "_showCurrentPageWidgets(title)" not in s:
    raise SystemExit('ERROR: shell Widgets button anchor not found')

# Attach the workspace key to every non-dashboard page screen widget.
old_fw = "                    : _FeatureWorkspace(\n                        title: title,"
new_fw = "                    : _FeatureWorkspace(\n                        key: _workspaceKey,\n                        title: title,"
if old_fw in s:
    s = s.replace(old_fw, new_fw, 1)
elif "key: _workspaceKey" not in s:
    raise SystemExit('ERROR: FeatureWorkspace construction anchor not found')

# Insert page widget manager before command search method.
manager_anchor = "  Future<void> _showCommandSearch(List<NavigationItem> items) async {"
if "Future<void> _showCurrentPageWidgets" not in s:
    if manager_anchor not in s:
        raise SystemExit('ERROR: page widget manager insertion anchor not found')
    manager = r'''  Future<void> _showCurrentPageWidgets(String title) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$title Widgets'),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This page screen is a workspace widget. Control it here without leaving the page.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: line),
                ),
                child: Row(
                  children: [
                    Icon(Icons.dashboard_customize_outlined, color: _accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$title Screen',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const Text('ACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF039855))),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'minimize'),
            child: const Text('Minimize'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'restore'),
            child: const Text('Restore'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'maximize'),
            child: const Text('Maximize'),
          ),
        ],
      ),
    );
    final state = _workspaceKey.currentState;
    if (state == null || action == null) return;
    if (action == 'minimize') state.setMinimized(true);
    if (action == 'restore') state.restoreWidget();
    if (action == 'maximize') state.setMaximized(true);
  }

'''
    s = s.replace(manager_anchor, manager + manager_anchor, 1)

# Add control methods to FeatureWorkspace state.
state_anchor = "class _FeatureWorkspaceState extends State<_FeatureWorkspace> {\n  bool minimized = false;\n  bool maximized = false;\n"
if "void setMinimized(bool value)" not in s:
    if state_anchor not in s:
        raise SystemExit('ERROR: FeatureWorkspace state anchor not found')
    methods = """class _FeatureWorkspaceState extends State<_FeatureWorkspace> {
  bool minimized = false;
  bool maximized = false;

  void setMinimized(bool value) {
    if (!mounted) return;
    setState(() => minimized = value);
  }

  void setMaximized(bool value) {
    if (!mounted) return;
    setState(() {
      minimized = false;
      maximized = value;
    });
  }

  void restoreWidget() {
    if (!mounted) return;
    setState(() {
      minimized = false;
      maximized = false;
    });
  }
"""
    s = s.replace(state_anchor, methods, 1)

shell_path.write_text(s)

# ---------------- DASHBOARD: real mouse drag + compact rows ----------------
d = dash_path.read_text()

# Immediate mouse drag instead of long-press drag, for both KPI cards and standard widgets.
d = d.replace('LongPressDraggable<String>(', 'Draggable<String>(')

# Remove legacy special widths that create narrow cards / unused white space.
d = d.replace('width: wide ? cardWidth * 1.35 : cardWidth,', 'width: cardWidth,')
d = d.replace('width: wide ? cardWidth * .65 : cardWidth,', 'width: cardWidth,')

# Replace the entire standard-widget drag assembly with a clean direct DragTarget + Draggable block.
start_token = "                    final orderedIds = _sectionOrder"
end_token = "                  },\n                ),\n              ],"
start = d.find(start_token)
if start != -1:
    end = d.find(end_token, start)
    if end == -1:
        raise SystemExit('ERROR: dashboard widget assembly end not found')
    block = r'''                    final orderedIds = _sectionOrder
                        .where(widgets.containsKey)
                        .toList();

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: orderedIds.map((id) {
                        final child = widgets[id]!;
                        return DragTarget<String>(
                          onWillAcceptWithDetails: (details) =>
                              details.data != id && _sectionOrder.contains(details.data),
                          onAcceptWithDetails: (details) {
                            final from = _sectionOrder.indexOf(details.data);
                            final to = _sectionOrder.indexOf(id);
                            if (from < 0 || to < 0 || from == to) return;
                            setState(() {
                              final moved = _sectionOrder.removeAt(from);
                              _sectionOrder.insert(to, moved);
                            });
                            _savePrefs();
                          },
                          builder: (_, candidates, __) => Draggable<String>(
                            data: id,
                            dragAnchorStrategy: pointerDragAnchorStrategy,
                            feedback: Material(
                              color: Colors.transparent,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth * .72,
                                ),
                                child: Opacity(opacity: .94, child: child),
                              ),
                            ),
                            childWhenDragging: Opacity(opacity: .20, child: child),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 100),
                                decoration: candidates.isEmpty
                                    ? null
                                    : BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: _purple, width: 2),
                                      ),
                                child: child,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
'''
    d = d[:start] + block + d[end:]
else:
    raise SystemExit('ERROR: dashboard ordered widget assembly not found')

# Make the lower-grid width respond to how many visible widgets remain, reducing blank space after closing widgets.
old_width = """                    final cardWidth = wide
                        ? (constraints.maxWidth - 24) / 3
                        : medium
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;"""
new_width = """                    final visibleCount = _sectionOrder
                        .where(_visible.contains)
                        .length;
                    final desktopColumns = visibleCount <= 1
                        ? 1
                        : visibleCount == 2
                        ? 2
                        : visibleCount == 4
                        ? 2
                        : 3;
                    final cardWidth = wide
                        ? (constraints.maxWidth - (12 * (desktopColumns - 1))) /
                              desktopColumns
                        : medium
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;"""
if old_width in d:
    d = d.replace(old_width, new_width, 1)

# Shorten unreadable Firestore document ids anywhere they are shown as kitchen receipts.
if '#${doc.id}' in d:
    d = d.replace(
        '#${doc.id}',
        "KOT ${doc.id.length > 6 ? doc.id.substring(doc.id.length - 6).toUpperCase() : doc.id.toUpperCase()}"
    )

dash_path.write_text(d)

# ---------------- KITCHEN: readable KOT number ----------------
k = kitchen_path.read_text()
old_saved = "    if (saved.isNotEmpty) return saved;"
new_saved = """    if (saved.isNotEmpty) {
      return saved.length > 8
          ? saved.substring(saved.length - 8).toUpperCase()
          : saved.toUpperCase();
    }"""
if old_saved in k:
    k = k.replace(old_saved, new_saved, 1)

old_fallback = "    return '${two(d.day)}${two(d.month)}${two(d.year % 100)}${two(d.hour)}${two(d.minute)}${two(d.second)}';"
new_fallback = "    return '${two(d.day)}${two(d.hour)}${two(d.minute)}${two(d.second)}';"
if old_fallback in k:
    k = k.replace(old_fallback, new_fallback, 1)

kitchen_path.write_text(k)

print('OK: Widgets button is page-aware; non-dashboard pages no longer jump away')
print('OK: every normal page screen is controllable as its own workspace widget')
print('OK: dashboard KPI and standard widgets use immediate desktop mouse drag')
print('OK: legacy drag drop-zones removed from standard widget layout')
print('OK: visible widget count now controls layout width to reduce blank space')
print('OK: narrow Top Selling layout width removed')
print('OK: kitchen/KOT identifiers shortened for readability')
print('ONLY shell + dashboard + kitchen KOT source files are modified')
