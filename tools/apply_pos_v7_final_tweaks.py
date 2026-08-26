#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SHELL = ROOT / 'lib/components/layout/main_shell_v7.dart'
DASH = ROOT / 'lib/screens/restaurant_dashboard_screen_v3.dart'


def sub1(text: str, pattern: str, replacement: str, name: str) -> str:
    new, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f'{name}: expected 1 match, found {count}')
    print(f'OK: {name}')
    return new


def patch_shell() -> None:
    s = SHELL.read_text()

    # Brand default. Existing user preference still wins after load.
    s = s.replace("String _buttonColor = 'purple';", "String _buttonColor = 'burgundy';", 1)
    s = s.replace("(data['uiButtonColor'] ?? 'purple').toString()", "(data['uiButtonColor'] ?? 'burgundy').toString()", 1)

    if 'items: items,' not in s[s.find('_TopBar('):s.find('_TopBar(')+220]:
        s = sub1(s, r'(_TopBar\(\s*user:\s*user,\s*)', r'\1items: items,\n          ', 'TopBar items')

    if 'user: user,' not in s[s.find('_VerticalNav('):s.find('_VerticalNav(')+220]:
        s = sub1(s, r'(_VerticalNav\(\s*)items:\s*items,', r'\1user: user,\n        items: items,', 'VerticalNav user')

    topbar = r'''class _TopBar extends StatelessWidget {
  final UserModel user;
  final List<NavigationItem> items;
  final String title;
  final Color accent;
  final bool online;
  final ValueChanged<bool> onPresence;
  final VoidCallback onInterfaceSettings;
  final VoidCallback onBilling;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;
  final VoidCallback onProfile;
  final VoidCallback onLogout;
  final VoidCallback onAddWidget;
  final VoidCallback onSearch;

  const _TopBar({
    required this.user,
    required this.items,
    required this.title,
    required this.accent,
    required this.online,
    required this.onPresence,
    required this.onInterfaceSettings,
    required this.onBilling,
    required this.onNotifications,
    required this.onSettings,
    required this.onProfile,
    required this.onLogout,
    required this.onAddWidget,
    required this.onSearch,
  });

  NavigationItem? _utility(String kind) {
    for (final item in items) {
      final label = item.label.trim().toLowerCase();
      if (kind == 'pra' && label == 'pra') return item;
      if (kind == 'help' && (label == 'help ai' || label == 'help / ai' || label == 'help & ai' || label == 'ai help' || label == 'help' || label == 'ai assistant')) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final initials = user.name.trim().isEmpty ? 'U' : user.name.trim().substring(0, 1).toUpperCase();
    final pra = _utility('pra');
    final help = _utility('help');

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _MainShellState.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 170,
            child: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _MainShellState.ink)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: InkWell(
                onTap: onSearch,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _MainShellState.line)),
                  child: const Row(children: [Icon(Icons.search_rounded, size: 19, color: _MainShellState.muted), SizedBox(width: 9), Expanded(child: Text('Search anything…', style: TextStyle(fontSize: 12, color: _MainShellState.muted)))]),
                ),
              ),
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onAddWidget,
            icon: Icon(Icons.widgets_outlined, color: accent, size: 17),
            label: Text('Widgets', style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(minimumSize: const Size(96, 40), side: BorderSide(color: accent.withValues(alpha: .42)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(width: 4),
          if (pra != null) Tooltip(message: 'PRA', child: IconButton(onPressed: () => context.go(pra.route), icon: Icon(Icons.verified_user_outlined, color: accent))),
          if (help != null) Tooltip(message: 'Help / AI', child: IconButton(onPressed: () => context.go(help.route), icon: Icon(Icons.auto_awesome_outlined, color: accent))),
          Tooltip(message: 'Tycoon Account & Billing', child: IconButton(onPressed: onBilling, icon: Icon(Icons.account_balance_wallet_outlined, color: accent))),
          _NotificationButton(user: user, accent: accent, onTap: onNotifications),
          Tooltip(message: 'Interface & Navigation', child: IconButton(onPressed: onInterfaceSettings, icon: const Icon(Icons.tune_rounded))),
          const SizedBox(width: 3),
          PopupMenuButton<String>(
            tooltip: 'Profile',
            onSelected: (value) {
              if (value == 'profile') onProfile();
              if (value == 'settings') onSettings();
              if (value == 'logout') onLogout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: ListTile(dense: true, leading: Icon(Icons.person_outline), title: Text('My Profile'))),
              PopupMenuItem(value: 'settings', child: ListTile(dense: true, leading: Icon(Icons.settings_outlined), title: Text('Settings'))),
              PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: ListTile(dense: true, leading: Icon(Icons.logout_rounded), title: Text('Logout'))),
            ],
            child: Row(children: [
              CircleAvatar(radius: 18, backgroundColor: const Color(0xFFF2F4F7), child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w900, color: _MainShellState.ink))),
              const SizedBox(width: 7),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name.isEmpty ? 'User' : user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 1),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(user.role.name, style: const TextStyle(fontSize: 9.5, color: _MainShellState.muted)),
                    const Text(' • ', style: TextStyle(fontSize: 9.5, color: _MainShellState.muted)),
                    InkWell(
                      onTap: () => onPresence(!online),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: online ? const Color(0xFF12B76A) : const Color(0xFF98A2B3))),
                        const SizedBox(width: 4),
                        Text(online ? 'Online' : 'Offline', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: online ? const Color(0xFF027A48) : _MainShellState.muted)),
                      ]),
                    ),
                  ]),
                ]),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
            ]),
          ),
        ],
      ),
    );
  }
}

'''
    s = sub1(s, r'class _TopBar extends StatelessWidget \{.*?(?=class _RestaurantLogo)', topbar, 'TopBar')

    notification = r'''class _NotificationButton extends StatefulWidget {
  final UserModel user;
  final Color accent;
  final VoidCallback onTap;
  const _NotificationButton({required this.user, required this.accent, required this.onTap});
  @override
  State<_NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<_NotificationButton> {
  bool _open = false;
  void _tap() {
    setState(() => _open = true);
    widget.onTap();
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _open = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance.collection('vendors').doc(widget.user.id).collection('notifications').orderBy('createdAt', descending: true).limit(50);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (_, snapshot) {
        final count = (snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]).where((doc) {
          final d = doc.data();
          final cleared = List<String>.from(d['clearedBy'] ?? const <String>[]).contains(widget.user.authUid);
          final read = List<String>.from(d['readBy'] ?? const <String>[]).contains(widget.user.authUid);
          return !cleared && !read && _visibleFor(widget.user, d);
        }).length;
        final active = count > 0 || _open;
        return Stack(clipBehavior: Clip.none, children: [
          Material(
            color: _open ? widget.accent.withValues(alpha: .10) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: IconButton(
              tooltip: count > 0 ? 'Notifications • $count unread' : 'Notifications',
              onPressed: _tap,
              icon: Icon(count > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, color: active ? widget.accent : _MainShellState.ink),
            ),
          ),
          if (count > 0) Positioned(right: 3, top: 2, child: Container(constraints: const BoxConstraints(minWidth: 17), height: 17, padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFD92D20), borderRadius: BorderRadius.circular(9)), child: Text(count > 99 ? '99+' : '$count', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)))),
        ]);
      },
    );
  }
}

'''
    s = sub1(s, r'class _NotificationButton extends StatelessWidget \{.*?(?=class _KeyHint)', notification, 'NotificationButton')

    vertical = r'''class _VerticalNav extends StatelessWidget {
  final UserModel user;
  final List<NavigationItem> items;
  final String currentRoute;
  final Color accent, background, textColor;
  final Set<String> favorites;
  final String Function(String) shortcutFor;
  final String displayMode;
  final ValueChanged<String> onFavorite;
  const _VerticalNav({required this.user, required this.items, required this.currentRoute, required this.accent, required this.background, required this.textColor, required this.favorites, required this.shortcutFor, required this.displayMode, required this.onFavorite});

  bool _utility(NavigationItem item) {
    final x = item.label.trim().toLowerCase();
    return x == 'pra' || x == 'help ai' || x == 'help / ai' || x == 'help & ai' || x == 'ai help' || x == 'help' || x == 'ai assistant';
  }

  @override
  Widget build(BuildContext context) {
    final iconsOnly = displayMode == 'iconsOnly';
    final iconsKeys = displayMode == 'iconsKeys';
    final full = displayMode == 'full';
    final width = iconsOnly ? 72.0 : iconsKeys ? 104.0 : full ? 245.0 : 215.0;
    final navItems = items.where((item) => !_utility(item)).toList();
    final restaurant = user.restaurantName.isEmpty ? 'Restaurant' : user.restaurantName;

    return Container(
      width: width,
      color: background,
      child: Column(children: [
        Container(
          height: 82,
          padding: EdgeInsets.symmetric(horizontal: iconsOnly ? 10 : 13),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: textColor.withValues(alpha: .15)))),
          child: iconsOnly
              ? Center(child: _RestaurantLogo(user: user, size: 46))
              : Row(children: [_RestaurantLogo(user: user, size: 43), const SizedBox(width: 9), Expanded(child: Text(restaurant, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w900)))]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 9, 8, 9),
            itemCount: navItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 2),
            itemBuilder: (_, index) {
              final item = navItems[index];
              final active = currentRoute == item.route || (item.route != '/' && currentRoute.startsWith(item.route));
              final showName = !iconsOnly && !iconsKeys;
              final showKey = iconsKeys || full;
              Widget tile = Material(
                color: active ? accent.withValues(alpha: .12) : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => context.go(item.route),
                  onLongPress: () => onFavorite(item.route),
                  child: SizedBox(height: 43, child: Row(mainAxisAlignment: iconsOnly ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
                    SizedBox(width: iconsOnly ? 56 : 42, child: Icon(item.icon, size: 19, color: active ? accent : textColor)),
                    if (showName) Expanded(child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? accent : textColor, fontSize: 12, fontWeight: active ? FontWeight.w800 : FontWeight.w600))),
                    if (showKey) Container(margin: const EdgeInsets.only(right: 7), constraints: const BoxConstraints(minWidth: 25), height: 24, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: active ? accent.withValues(alpha: .12) : const Color(0xFFF2F4F7), borderRadius: BorderRadius.circular(6)), child: Text(shortcutFor(item.label), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: active ? accent : _MainShellState.muted))),
                  ])),
                ),
              );
              if (iconsOnly || iconsKeys) tile = Tooltip(message: item.label, child: tile);
              return tile;
            },
          ),
        ),
        Container(height: 36, alignment: Alignment.center, decoration: BoxDecoration(border: Border(top: BorderSide(color: textColor.withValues(alpha: .15)))), child: Text(iconsOnly ? 'T' : 'Tycoon POS', style: TextStyle(fontSize: iconsOnly ? 12 : 10, fontWeight: FontWeight.w800, color: textColor.withValues(alpha: .65)))),
      ]),
    );
  }
}

'''
    s = sub1(s, r'class _VerticalNav extends StatelessWidget \{.*?(?=class _FeatureWorkspace)', vertical, 'VerticalNav')

    SHELL.write_text(s)


def patch_dashboard() -> None:
    s = DASH.read_text()

    s = s.replace("Set<String> _visible = _allSections.keys.toSet();", "Set<String> _visible = _allSections.keys.toSet();\n  List<String> _sectionOrder = _allSections.keys.toList();\n  List<String> _kpiOrder = const ['sales', 'orders', 'avg', 'kitchenTime', 'tables', 'pra'].toList();", 1)

    old_load = """      if (visible != null && visible.isNotEmpty)\n        setState(() => _visible = visible);"""
    new_load = """      final savedOrder = (data['sectionOrder'] as List?)?.map((e) => e.toString()).where(_allSections.containsKey).toList();
      final savedKpis = (data['kpiOrder'] as List?)?.map((e) => e.toString()).where(const {'sales','orders','avg','kitchenTime','tables','pra'}.contains).toList();
      setState(() {
        if (visible != null && visible.isNotEmpty) _visible = visible;
        if (savedOrder != null && savedOrder.isNotEmpty) {
          _sectionOrder = [...savedOrder, ..._allSections.keys.where((x) => !savedOrder.contains(x))];
        }
        if (savedKpis != null && savedKpis.isNotEmpty) {
          _kpiOrder = [...savedKpis, ...['sales','orders','avg','kitchenTime','tables','pra'].where((x) => !savedKpis.contains(x))];
        }
      });"""
    if old_load not in s:
        raise RuntimeError('dashboard load anchor not found')
    s = s.replace(old_load, new_load, 1)

    s = s.replace("'visibleSections': _visible.toList(),\n        'updatedAt'", "'visibleSections': _visible.toList(),\n        'sectionOrder': _sectionOrder,\n        'kpiOrder': _kpiOrder,\n        'updatedAt'", 1)

    # Remove duplicate page heading/customize icon row. Keep only compact date row.
    header_pattern = r"\s*Row\(\s*children: \[\s*Expanded\(\s*child: Column\(.*?if \(user\.canAddWidgets\) \.\.\.\[.*?\],\s*\),\s*const SizedBox\(height: 18\),"
    header_repl = "\n                Align(\n                  alignment: Alignment.centerRight,\n                  child: Container(\n                    height: 36,\n                    padding: const EdgeInsets.symmetric(horizontal: 11),\n                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _line), borderRadius: BorderRadius.circular(9)),\n                    child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.calendar_today_outlined, size: 15, color: _muted), const SizedBox(width: 7), Text('Today, ${DateFormat('d MMM yyyy').format(now)}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800))]),\n                  ),\n                ),\n                const SizedBox(height: 10),"
    s, count = re.subn(header_pattern, header_repl, s, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f'dashboard compact header: expected 1 match, found {count}')
    print('OK: dashboard compact header')

    # KPI constructor gets stable id.
    s = s.replace("class _Kpi {\n  final String label, value;", "class _Kpi {\n  final String id, label, value;", 1)
    s = s.replace("const _Kpi(this.label, this.value, this.icon, this.color, this.trend);", "const _Kpi(this.id, this.label, this.value, this.icon, this.color, this.trend);", 1)

    # Add ids to six KPI definitions.
    s = s.replace("_Kpi(\n                        'Total Sales',", "_Kpi(\n                        'sales',\n                        'Total Sales',", 1)
    s = s.replace("_Kpi(\n                        'Orders',", "_Kpi(\n                        'orders',\n                        'Orders',", 1)
    s = s.replace("_Kpi(\n                        'Average Bill',", "_Kpi(\n                        'avg',\n                        'Average Bill',", 1)
    s = s.replace("_Kpi(\n                        'Kitchen Time',", "_Kpi(\n                        'kitchenTime',\n                        'Kitchen Time',", 1)
    s = s.replace("_Kpi(\n                        'Active Tables',", "_Kpi(\n                        'tables',\n                        'Active Tables',", 1)
    s = s.replace("_Kpi(\n                        'PRA Finalized',", "_Kpi(\n                        'pra',\n                        'PRA Finalized',", 1)

    old_kpi_return = r"return Wrap\(\s*spacing: 12,\s*runSpacing: 12,\s*children: kpis\s*\.map\(.*?\s*\.toList\(\),\s*\);"
    new_kpi_return = r'''final byId = {for (final kpi in kpis) kpi.id: kpi};
                    final ordered = _kpiOrder.map((id) => byId[id]).whereType<_Kpi>().toList();
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: ordered.map((kpi) {
                        return DragTarget<String>(
                          onWillAcceptWithDetails: (d) => d.data != kpi.id && _kpiOrder.contains(d.data),
                          onAcceptWithDetails: (d) {
                            final from = _kpiOrder.indexOf(d.data);
                            final to = _kpiOrder.indexOf(kpi.id);
                            if (from < 0 || to < 0 || from == to) return;
                            setState(() {
                              final moved = _kpiOrder.removeAt(from);
                              _kpiOrder.insert(to, moved);
                            });
                            _savePrefs();
                          },
                          builder: (_, candidate, __) => LongPressDraggable<String>(
                            data: kpi.id,
                            feedback: Material(color: Colors.transparent, child: SizedBox(width: cardWidth, child: Opacity(opacity: .92, child: _KpiCard(data: kpi)))),
                            childWhenDragging: SizedBox(width: cardWidth, child: Opacity(opacity: .30, child: _KpiCard(data: kpi))),
                            child: SizedBox(
                              width: cardWidth,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _showKpiDetails(kpi),
                                child: _KpiCard(data: kpi),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );'''
    s, count = re.subn(old_kpi_return, new_kpi_return, s, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f'dashboard KPI wrap: expected 1 match, found {count}')
    print('OK: draggable KPI strip')

    old_sections = r"final sections = <Widget>\[\];.*?return Wrap\(\s*spacing: 12,\s*runSpacing: 12,\s*children: sections,\s*\);"
    new_sections = r'''final widgets = <String, Widget>{};
                    if (_visible.contains('salesChart')) widgets['salesChart'] = SizedBox(width: wide ? cardWidth * 1.35 : cardWidth, height: 330, child: _SalesOverviewCard(sales: sales));
                    if (_visible.contains('recentOrders')) widgets['recentOrders'] = SizedBox(width: cardWidth, height: 330, child: _RecentOrdersCard(sales: sales));
                    if (_visible.contains('topItems')) widgets['topItems'] = SizedBox(width: wide ? cardWidth * .65 : cardWidth, height: 330, child: _TopItemsCard(sales: sales));
                    if (_visible.contains('kitchen')) widgets['kitchen'] = SizedBox(width: cardWidth, height: 260, child: _KitchenCard(orders: orders));
                    if (_visible.contains('alerts')) widgets['alerts'] = SizedBox(width: cardWidth, height: 260, child: _AlertsCard(user: user));
                    if (_visible.contains('branches')) widgets['branches'] = SizedBox(width: cardWidth, height: 260, child: _BranchCard(user: user, sales: todaySales));
                    final orderedIds = _sectionOrder.where(widgets.containsKey).toList();
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: orderedIds.map((id) {
                        final child = widgets[id]!;
                        return DragTarget<String>(
                          onWillAcceptWithDetails: (d) => d.data != id && _sectionOrder.contains(d.data),
                          onAcceptWithDetails: (d) {
                            final from = _sectionOrder.indexOf(d.data);
                            final to = _sectionOrder.indexOf(id);
                            if (from < 0 || to < 0 || from == to) return;
                            setState(() {
                              final moved = _sectionOrder.removeAt(from);
                              _sectionOrder.insert(to, moved);
                            });
                            _savePrefs();
                          },
                          builder: (_, candidate, __) => LongPressDraggable<String>(
                            data: id,
                            feedback: Material(color: Colors.transparent, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: constraints.maxWidth * .75), child: Opacity(opacity: .90, child: child))),
                            childWhenDragging: Opacity(opacity: .28, child: child),
                            child: child,
                          ),
                        );
                      }).toList(),
                    );'''
    s, count = re.subn(old_sections, new_sections, s, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f'dashboard sections: expected 1 match, found {count}')
    print('OK: draggable dashboard widgets')

    # Insert KPI detail popup before _averageKitchenTime.
    anchor = "  Duration? _averageKitchenTime("
    detail = """  Future<void> _showKpiDetails(_Kpi kpi) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: kpi.color.withValues(alpha: .11), shape: BoxShape.circle), child: Icon(kpi.icon, color: kpi.color, size: 20)), const SizedBox(width: 11), Expanded(child: Text(kpi.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))), IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close_rounded))]),
                const SizedBox(height: 18),
                Text(kpi.value, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: _ink)),
                const SizedBox(height: 8),
                const Text('Drag this KPI on the dashboard to change its position. Your layout is saved automatically.', style: TextStyle(fontSize: 11, color: _muted)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

"""
    if anchor not in s:
        raise RuntimeError('KPI detail anchor not found')
    s = s.replace(anchor, detail + anchor, 1)

    # Compact KPI visuals.
    s = s.replace('height: 132,', 'height: 102,', 1)
    s = s.replace('padding: const EdgeInsets.all(14),', 'padding: const EdgeInsets.all(11),', 1)
    s = s.replace('const SizedBox(height: 10),\n      Text(data.value', 'const SizedBox(height: 6),\n      Text(data.value', 1)
    s = s.replace('fontSize: 19,', 'fontSize: 17,', 1)
    s = s.replace('SizedBox(height: 24, width: double.infinity', 'SizedBox(height: 16, width: double.infinity', 1)

    DASH.write_text(s)


def main() -> int:
    if not SHELL.exists() or not DASH.exists():
        print('ERROR: run from the POS repository; required files are missing', file=sys.stderr)
        return 2
    try:
        patch_shell()
        patch_dashboard()
    except Exception as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        return 1
    print('PATCH COMPLETE')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
