import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pos/branding/tycoon_pos_brand.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/services/notification_service.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const burgundy = Color(0xFF7A1026);
  static const red = Color(0xFFD80000);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);
  static const soft = Color(0xFFF8FAFC);

  bool _loaded = false;
  String _navPlacement = 'top';
  String _navBackground = 'white';
  String _buttonColor = 'burgundy';
  Set<String> _favorites = {};
  bool _online = true;

  UserModel? get _user => context.read<AuthProvider>().currentUser;
  DocumentReference<Map<String, dynamic>>? get _vendorRef {
    final u = _user;
    return u == null ? null : FirebaseFirestore.instance.collection('vendors').doc(u.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadPrefs();
      _ensureBillingState();
    }
  }

  Future<void> _loadPrefs() async {
    try {
      final snap = await _vendorRef?.get();
      final d = snap?.data() ?? <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _navPlacement = (d['uiNavPlacement'] ?? 'top').toString();
        _navBackground = (d['uiNavBackground'] ?? 'white').toString();
        _buttonColor = (d['uiButtonColor'] ?? 'burgundy').toString();
        _favorites = Set<String>.from((d['favoriteFeatures'] as List?)?.map((e) => e.toString()) ?? const <String>[]);
        _online = (d['presenceOnline'] ?? true) == true;
      });
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      await _vendorRef?.set({
        'uiNavPlacement': _navPlacement,
        'uiNavBackground': _navBackground,
        'uiButtonColor': _buttonColor,
        'favoriteFeatures': _favorites.toList(),
        'presenceOnline': _online,
        'uiPreferencesUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _ensureBillingState() async {
    final u = _user;
    if (u == null || !u.isAdmin) return;
    try {
      final ref = FirebaseFirestore.instance.collection('vendors').doc(u.id);
      final snap = await ref.get();
      if (!snap.exists) return;
      final d = snap.data() ?? <String, dynamic>{};
      final plan = (d['billingPlanId'] ?? d['subscriptionType'] ?? '').toString();
      if (plan != 'monthly' && plan != 'perTransaction') return;

      final now = DateTime.now();
      final status = (d['billingStatus'] ?? '').toString().toLowerCase();
      final usageDue = d['transactionUsageAmount'] is num ? (d['transactionUsageAmount'] as num).toDouble() : 0.0;
      final dueRaw = d['nextPaymentDueAt'];
      DateTime dueAt = dueRaw is Timestamp ? dueRaw.toDate() : DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      if (dueRaw == null) await ref.set({'nextPaymentDueAt': Timestamp.fromDate(dueAt)}, SetOptions(merge: true));

      final reminderKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final reminderSent = (d['billingReminderMonth'] ?? '').toString() == reminderKey;
      final shouldRemind = now.day >= 25 && !reminderSent && (plan == 'monthly' ? status != 'paid' : usageDue > 0);
      if (shouldRemind) {
        await NotificationService().publish(
          actor: u,
          type: 'billing_due',
          title: 'Tycoon POS fee due',
          message: plan == 'perTransaction'
              ? 'Your current transaction usage fee is Rs ${usageDue.toStringAsFixed(0)}. Please pay by month-end to keep full access.'
              : 'Your monthly Tycoon POS fee is due. Please pay by month-end to keep full access.',
          targetRoles: const ['admin', 'superAdmin'],
          metadata: {'plan': plan, 'amountDue': plan == 'perTransaction' ? usageDue : 7000},
        );
        await ref.set({'billingReminderMonth': reminderKey, 'billingReminderSentAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      }

      final overdue = now.isAfter(dueAt) && (plan == 'monthly' ? status != 'paid' : usageDue > 0);
      if (overdue) {
        await ref.set({'accessMode': 'basic', 'billingStatus': 'overdue', 'downgradedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Color get _accent => switch (_buttonColor) {
        'purple' => const Color(0xFF6C3BFF),
        'red' => const Color(0xFFD80000),
        'navy' => const Color(0xFF17365D),
        'emerald' => const Color(0xFF059669),
        'graphite' => const Color(0xFF334155),
        _ => burgundy,
      };

  Color get _navColor => switch (_navBackground) {
        'soft' => const Color(0xFFF1F5F9),
        'burgundy' => burgundy,
        'navy' => const Color(0xFF17365D),
        'graphite' => const Color(0xFF334155),
        _ => Colors.white,
      };

  Color get _navTextColor => ['burgundy', 'navy', 'graphite'].contains(_navBackground) ? Colors.white : ink;

  String _shortcutFor(String label) {
    const map = {
      'Dashboard': 'D', 'Tables': 'T', 'Billing': 'B', 'KOT': 'K', 'Inventory': 'I', 'Store': 'M', 'Expenses': 'E',
      'CRM': 'C', 'Operations': 'O', 'Kitchen Recipes': 'K', 'Vendors': 'V', 'Branches': 'N', 'PRA': 'F', 'Help AI': 'H', 'Preferences': 'P'
    };
    return map[label] ?? label.substring(0, 1).toUpperCase();
  }

  Future<void> _toggleFavorite(String route) async {
    setState(() => _favorites.contains(route) ? _favorites.remove(route) : _favorites.add(route));
    await _savePrefs();
  }

  Future<void> _setPresence(bool online) async {
    setState(() => _online = online);
    await _savePrefs();
    final u = _user;
    if (u != null) {
      await _vendorRef?.collection('presence').doc(u.authUid).set({
        'online': online,
        'name': u.name,
        'role': u.role.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AuthProvider>().currentUser;
    if (u == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final route = GoRouterState.of(context).uri.path;
    final items = AppRouter.getNavigationItems(u.role);
    final current = items.where((e) => route == e.route || (e.route != '/' && route.startsWith(e.route))).firstOrNull;
    final title = current?.label ?? (route.startsWith('/table-order') ? 'POS' : 'Workspace');
    final verticalNav = _navPlacement == 'left' || _navPlacement == 'right';

    Widget body = Column(children: [
      _Header(
        user: u,
        title: title,
        accent: _accent,
        online: _online,
        onPresence: _setPresence,
        onSettings: _showInterfaceSettings,
        onBilling: () => _showBillingMenu(u),
        onNotifications: () => _showNotificationHistory(u),
      ),
      if (_navPlacement == 'top') _NavBar(items: items, currentRoute: route, accent: _accent, background: _navColor, textColor: _navTextColor, favorites: _favorites, shortcutFor: _shortcutFor, onFavorite: _toggleFavorite),
      Expanded(child: Stack(children: [
        Positioned.fill(child: route == AppRouter.dashboard || route.startsWith('/table-order') ? widget.child : _FeatureWorkspace(title: title, route: route, accent: _accent, favorite: _favorites.contains(current?.route), onFavorite: current == null ? null : () => _toggleFavorite(current.route), child: widget.child)),
        if (u.isAdmin) Positioned(top: 12, right: 12, child: _UnreadNotificationRail(user: u)),
      ])),
      if (_navPlacement == 'bottom') _NavBar(items: items, currentRoute: route, accent: _accent, background: _navColor, textColor: _navTextColor, favorites: _favorites, shortcutFor: _shortcutFor, onFavorite: _toggleFavorite),
    ]);

    if (verticalNav) {
      final rail = _VerticalNav(items: items, currentRoute: route, accent: _accent, background: _navColor, textColor: _navTextColor, favorites: _favorites, shortcutFor: _shortcutFor, onFavorite: _toggleFavorite);
      body = Row(children: _navPlacement == 'left' ? [rail, Expanded(child: body)] : [Expanded(child: body), rail]);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isAltPressed || HardwareKeyboard.instance.isMetaPressed) return KeyEventResult.ignored;
          if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) return KeyEventResult.ignored;
          final char = event.character?.toUpperCase();
          if (char == null) return KeyEventResult.ignored;
          for (final item in items) {
            if (_shortcutFor(item.label) == char) {
              context.go(item.route);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Row(children: [
          if (!verticalNav) _BrandRail(accent: _accent, items: items, currentRoute: route, shortcutFor: _shortcutFor),
          Expanded(child: body),
        ]),
      ),
    );
  }

  Future<void> _showInterfaceSettings() async {
    String placement = _navPlacement;
    String background = _navBackground;
    String button = _buttonColor;
    final result = await showDialog<List<String>>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (_, setModal) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Interface & Navigation'),
        content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Navigation position', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(spacing: 7, children: [('top','Sticky Top'),('bottom','Float Bottom'),('left','Left Vertical'),('right','Right Vertical')].map((x) => ChoiceChip(label: Text(x.$2), selected: placement == x.$1, onSelected: (_) => setModal(() => placement = x.$1))).toList()),
          const SizedBox(height: 18),
          const Text('Navigation background', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(spacing: 7, children: ['white','soft','burgundy','navy','graphite'].map((x) => ChoiceChip(label: Text(x[0].toUpperCase()+x.substring(1)), selected: background == x, onSelected: (_) => setModal(() => background = x))).toList()),
          const SizedBox(height: 18),
          const Text('Button / accent color', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(spacing: 7, children: ['burgundy','red','purple','navy','emerald','graphite'].map((x) => ChoiceChip(label: Text(x[0].toUpperCase()+x.substring(1)), selected: button == x, onSelected: (_) => setModal(() => button = x))).toList()),
          const SizedBox(height: 12),
          const Text('Changes are saved automatically to this restaurant.', style: TextStyle(fontSize: 10.5, color: muted)),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, [placement, background, button]), child: const Text('Apply'))],
      )),
    );
    if (result != null && mounted) {
      setState(() { _navPlacement = result[0]; _navBackground = result[1]; _buttonColor = result[2]; });
      await _savePrefs();
    }
  }

  Future<void> _showBillingMenu(UserModel u) async {
    final snap = await FirebaseFirestore.instance.collection('vendors').doc(u.id).get();
    if (!mounted) return;
    final d = snap.data() ?? <String, dynamic>{};
    final plan = (d['billingPlanId'] ?? d['subscriptionType'] ?? 'trial').toString();
    final success = d['successfulReceiptCount'] is num ? (d['successfulReceiptCount'] as num).toInt() : 0;
    final unbilled = d['unbilledReceiptCount'] is num ? (d['unbilledReceiptCount'] as num).toInt() : 0;
    final rate = d['transactionRate'] is num ? (d['transactionRate'] as num).toDouble() : 1.0;
    final usage = d['transactionUsageAmount'] is num ? (d['transactionUsageAmount'] as num).toDouble() : 0.0;
    final server = Map<String, dynamic>.from(d['serverMetrics'] ?? d['serverUsage'] ?? const <String, dynamic>{});

    await showDialog<void>(context: context, builder: (c) => AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('Tycoon Account & Billing'),
      content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _infoRow('Package', _planLabel(plan)),
        if (plan == 'perTransaction') ...[
          _infoRow('Successful receipts', '$success lifetime • $unbilled current'),
          _infoRow('Usage rate', 'Rs ${rate.toStringAsFixed(rate % 1 == 0 ? 0 : 2)} / successful receipt'),
          _infoRow('Current amount due', 'Rs ${usage.toStringAsFixed(0)}'),
        ],
        const Divider(height: 24),
        const Text('Server Usage', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Text(server.isEmpty ? 'Server is online. Detailed CPU / RAM / disk feed is not connected yet.' : 'CPU ${server['cpu'] ?? '-'}   •   RAM ${server['ram'] ?? '-'}   •   Disk ${server['disk'] ?? '-'}', style: const TextStyle(fontSize: 11.5, color: muted)),
        const SizedBox(height: 18),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: () { Navigator.pop(c); context.go(AppRouter.pricing); }, icon: const Icon(Icons.workspace_premium_outlined, size: 17), label: const Text('Upgrade Package')),
          FilledButton.icon(onPressed: () { Navigator.pop(c); context.go('${AppRouter.payment}/${plan == 'trial' ? 'monthly' : plan}'); }, icon: const Icon(Icons.payments_outlined, size: 17), label: const Text('Pay Tycoon Fee')),
          OutlinedButton.icon(onPressed: () async { final uri = Uri.parse('https://tycoon.technology'); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }, icon: const Icon(Icons.support_agent_rounded, size: 17), label: const Text('Contact Tycoon')),
        ]),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
    ));
  }

  Widget _infoRow(String a, String b) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [SizedBox(width: 145, child: Text(a, style: const TextStyle(fontSize: 11, color: muted))), Expanded(child: Text(b, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5))) ]));

  String _planLabel(String plan) => switch (plan) {'perTransaction' => 'Rs 1 / successful receipt', 'monthly' => 'Monthly • Rs 7,000', 'yearly' => 'Yearly • Rs 80,000', 'fiveYears' => '5 Years • Rs 200,000', _ => '3-day Trial'};

  Future<void> _showNotificationHistory(UserModel u) async {
    await showDialog<void>(context: context, builder: (_) => _NotificationHistoryDialog(user: u));
  }
}

class _Header extends StatelessWidget {
  final UserModel user;
  final String title;
  final Color accent;
  final bool online;
  final ValueChanged<bool> onPresence;
  final VoidCallback onSettings;
  final VoidCallback onBilling;
  final VoidCallback onNotifications;
  const _Header({required this.user, required this.title, required this.accent, required this.online, required this.onPresence, required this.onSettings, required this.onBilling, required this.onNotifications});

  @override
  Widget build(BuildContext context) => Container(
    height: 80,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: _MainShellState.line))),
    child: Row(children: [
      const Text('TYCOON POS', style: TextStyle(color: _MainShellState.red, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
      const SizedBox(width: 10),
      Container(width: 1, height: 30, color: _MainShellState.line),
      const SizedBox(width: 12),
      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _MainShellState.ink)),
        Row(children: [
          if ((user.restaurantLogoUrl ?? '').isNotEmpty) ...[
            ClipOval(child: Image.network(user.restaurantLogoUrl!, width: 18, height: 18, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.storefront_outlined, size: 16))),
            const SizedBox(width: 5),
          ],
          Flexible(child: Text(user.restaurantName.isEmpty ? user.branchName : '${user.restaurantName} • ${user.branchName}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: _MainShellState.muted))),
        ]),
      ])),
      IconButton(tooltip: 'Interface position and colors', onPressed: onSettings, icon: const Icon(Icons.palette_outlined)),
      IconButton(tooltip: 'Tycoon account, package, fees & server', onPressed: onBilling, icon: Icon(Icons.account_balance_wallet_outlined, color: accent)),
      IconButton(tooltip: 'Notification history', onPressed: onNotifications, icon: const Icon(Icons.notifications_outlined)),
      PopupMenuButton<bool>(tooltip: 'Presence', onSelected: onPresence, itemBuilder: (_) => const [PopupMenuItem(value: true, child: Text('Go Online')), PopupMenuItem(value: false, child: Text('Go Offline'))], child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8), decoration: BoxDecoration(color: online ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(18)), child: Row(children: [Icon(Icons.circle, size: 7, color: online ? const Color(0xFF059669) : const Color(0xFF64748B)), const SizedBox(width: 6), Text(online ? 'Online' : 'Offline', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: online ? const Color(0xFF047857) : _MainShellState.muted)), const Icon(Icons.arrow_drop_down_rounded, size: 16)]))),
      const SizedBox(width: 8),
      PopupMenuButton<String>(onSelected: (v) async { if (v == 'logout') { await context.read<AuthProvider>().signOut(); if (context.mounted) context.go(AppRouter.login); } }, itemBuilder: (_) => [PopupMenuItem(enabled: false, child: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w900))), const PopupMenuDivider(), const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout_rounded, size: 18), SizedBox(width: 8), Text('Logout')]))], child: CircleAvatar(backgroundColor: accent.withValues(alpha: .10), foregroundColor: accent, child: Text(user.name.isEmpty ? 'U' : user.name.substring(0,1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900)))),
    ]),
  );
}

class _BrandRail extends StatelessWidget {
  final Color accent;
  final List<NavigationItem> items;
  final String currentRoute;
  final String Function(String) shortcutFor;
  const _BrandRail({required this.accent, required this.items, required this.currentRoute, required this.shortcutFor});
  @override
  Widget build(BuildContext context) => Container(
    width: 92,
    color: const Color(0xFFD80000),
    child: Column(children: [
      const SizedBox(height: 10),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 9), child: TycoonPosLogo(width: 70, height: 70, fit: BoxFit.cover, borderRadius: BorderRadius.circular(13))),
      const SizedBox(height: 8),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 4), children: items.map((i) {
        final selected = currentRoute == i.route || (i.route != '/' && currentRoute.startsWith(i.route));
        return Tooltip(message: '${i.label} • shortcut ${shortcutFor(i.label)}', child: InkWell(onTap: () => context.go(i.route), child: Container(height: 58, margin: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: selected ? Colors.white.withValues(alpha: .18) : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Stack(children: [Center(child: Icon(i.icon, color: Colors.white, size: 24)), Positioned(right: 5, bottom: 5, child: Container(width: 18, height: 18, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)), child: Text(shortcutFor(i.label), style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFFD80000)))))]))));
      }).toList())),
    ]),
  );
}

class _NavBar extends StatelessWidget {
  final List<NavigationItem> items;
  final String currentRoute;
  final Color accent;
  final Color background;
  final Color textColor;
  final Set<String> favorites;
  final String Function(String) shortcutFor;
  final ValueChanged<String> onFavorite;
  const _NavBar({required this.items, required this.currentRoute, required this.accent, required this.background, required this.textColor, required this.favorites, required this.shortcutFor, required this.onFavorite});
  @override
  Widget build(BuildContext context) {
    final sorted = [...items]..sort((a,b) => (favorites.contains(b.route) ? 1 : 0).compareTo(favorites.contains(a.route) ? 1 : 0));
    return Container(height: 70, color: background, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), child: ListView(scrollDirection: Axis.horizontal, children: sorted.map((i) {
      final active = currentRoute == i.route || (i.route != '/' && currentRoute.startsWith(i.route));
      return Container(margin: const EdgeInsets.only(right: 8), child: InkWell(onLongPress: () => onFavorite(i.route), onTap: () => context.go(i.route), borderRadius: BorderRadius.circular(10), child: Container(padding: const EdgeInsets.symmetric(horizontal: 13), decoration: BoxDecoration(color: active ? accent.withValues(alpha: .10) : background, borderRadius: BorderRadius.circular(10), border: Border.all(color: active ? accent : textColor.withValues(alpha: .16))), child: Row(children: [Icon(i.icon, size: 18, color: active ? accent : textColor), const SizedBox(width: 7), Text(i.label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: active ? accent : textColor)), const SizedBox(width: 7), Container(width: 21, height: 21, alignment: Alignment.center, decoration: BoxDecoration(color: active ? accent.withValues(alpha: .10) : textColor.withValues(alpha: .06), borderRadius: BorderRadius.circular(6)), child: Text(shortcutFor(i.label), style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: active ? accent : textColor))), if (favorites.contains(i.route)) ...[const SizedBox(width: 5), Icon(Icons.star_rounded, size: 14, color: active ? accent : const Color(0xFFF59E0B))]])))));
    }).toList()));
  }
}

class _VerticalNav extends StatelessWidget {
  final List<NavigationItem> items;
  final String currentRoute;
  final Color accent;
  final Color background;
  final Color textColor;
  final Set<String> favorites;
  final String Function(String) shortcutFor;
  final ValueChanged<String> onFavorite;
  const _VerticalNav({required this.items, required this.currentRoute, required this.accent, required this.background, required this.textColor, required this.favorites, required this.shortcutFor, required this.onFavorite});
  @override
  Widget build(BuildContext context) => Container(width: 190, color: background, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Column(children: [
    const Padding(padding: EdgeInsets.all(8), child: TycoonPosLogo(width: 72, height: 72)),
    Expanded(child: ListView(children: items.map((i) {
      final active = currentRoute == i.route || (i.route != '/' && currentRoute.startsWith(i.route));
      return ListTile(dense: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)), selected: active, selectedTileColor: accent.withValues(alpha: .10), leading: Icon(i.icon, size: 18, color: active ? accent : textColor), title: Text(i.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: active ? accent : textColor)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (favorites.contains(i.route)) const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)), const SizedBox(width: 4), Text(shortcutFor(i.label), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: active ? accent : textColor))]), onTap: () => context.go(i.route), onLongPress: () => onFavorite(i.route));
    }).toList())),
  ]));
}

class _FeatureWorkspace extends StatefulWidget {
  final String title;
  final String route;
  final Color accent;
  final bool favorite;
  final VoidCallback? onFavorite;
  final Widget child;
  const _FeatureWorkspace({required this.title, required this.route, required this.accent, required this.favorite, required this.onFavorite, required this.child});
  @override
  State<_FeatureWorkspace> createState() => _FeatureWorkspaceState();
}

class _FeatureWorkspaceState extends State<_FeatureWorkspace> {
  bool minimized = false;
  bool maximized = false;
  @override
  Widget build(BuildContext context) {
    if (minimized) return Align(alignment: Alignment.topLeft, child: Padding(padding: const EdgeInsets.all(18), child: OutlinedButton.icon(onPressed: () => setState(() => minimized=false), icon: const Icon(Icons.open_in_full_rounded), label: Text('Restore ${widget.title}'))));
    return Container(color: Colors.white, padding: EdgeInsets.all(maximized ? 0 : 16), child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(maximized ? 0 : 14), border: maximized ? null : Border.all(color: _MainShellState.line), boxShadow: maximized ? null : const [BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0,4))]), child: Column(children: [
      Container(height: 48, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _MainShellState.line))), child: Row(children: [Icon(Icons.widgets_outlined, color: widget.accent, size: 18), const SizedBox(width: 8), Expanded(child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))), IconButton(tooltip: widget.favorite ? 'Remove favorite' : 'Favorite', onPressed: widget.onFavorite, icon: Icon(widget.favorite ? Icons.star_rounded : Icons.star_border_rounded, size: 18, color: widget.favorite ? const Color(0xFFF59E0B) : _MainShellState.muted)), IconButton(tooltip: 'Minimize', onPressed: () => setState(()=>minimized=true), icon: const Icon(Icons.remove_rounded, size: 18)), IconButton(tooltip: maximized ? 'Restore size' : 'Maximize', onPressed: () => setState(()=>maximized=!maximized), icon: Icon(maximized ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded, size: 17)), IconButton(tooltip: 'Return to dashboard', onPressed: () => context.go(AppRouter.dashboard), icon: const Icon(Icons.close_rounded, size: 18))])),
      Expanded(child: Theme(data: Theme.of(context).copyWith(scaffoldBackgroundColor: Colors.white, colorScheme: Theme.of(context).colorScheme.copyWith(primary: widget.accent, surface: Colors.white), cardTheme: const CardThemeData(color: Colors.white), inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _MainShellState.line))), filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: widget.accent))), child: widget.child)),
    ])));
  }
}

class _UnreadNotificationRail extends StatelessWidget {
  final UserModel user;
  const _UnreadNotificationRail({required this.user});
  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance.collection('vendors').doc(user.id).collection('notifications').orderBy('createdAt', descending: true).limit(20);
    return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: q.snapshots(), builder: (_, snap) {
      final docs = (snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String,dynamic>>>[]).where((d) {
        final a = d.data();
        final cleared = List<String>.from(a['clearedBy'] ?? const <String>[]).contains(user.authUid);
        final read = List<String>.from(a['readBy'] ?? const <String>[]).contains(user.authUid);
        return !cleared && !read && _visibleFor(user, a);
      }).take(4).toList();
      if (docs.isEmpty) return const SizedBox.shrink();
      return SizedBox(width: 355, child: Column(mainAxisSize: MainAxisSize.min, children: docs.map((d) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _NotificationToast(user: user, doc: d))).toList()));
    });
  }
}

class _NotificationToast extends StatelessWidget {
  final UserModel user;
  final QueryDocumentSnapshot<Map<String,dynamic>> doc;
  const _NotificationToast({required this.user, required this.doc});
  @override
  Widget build(BuildContext context) {
    final a = doc.data();
    return Material(color: Colors.transparent, child: InkWell(onTap: () => NotificationService().markRead(restaurantId: user.id, notificationId: doc.id, authUid: user.authUid), borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF59E0B)), boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 10, offset: Offset(0,3))]), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.notifications_active_outlined, color: Color(0xFFF97316), size: 20), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text((a['title'] ?? 'Notification').toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)), const SizedBox(height: 2), Text((a['message'] ?? '').toString(), style: const TextStyle(fontSize: 10.5, color: _MainShellState.muted))])), IconButton(tooltip: 'Mark read & hide', onPressed: () => NotificationService().markRead(restaurantId: user.id, notificationId: doc.id, authUid: user.authUid), icon: const Icon(Icons.done_rounded, color: Color(0xFFF97316), size: 18)), IconButton(tooltip: 'Dismiss', onPressed: () => NotificationService().dismiss(restaurantId: user.id, notificationId: doc.id, authUid: user.authUid), icon: const Icon(Icons.close_rounded, size: 17))]))));
  }
}

class _NotificationHistoryDialog extends StatefulWidget {
  final UserModel user;
  const _NotificationHistoryDialog({required this.user});
  @override
  State<_NotificationHistoryDialog> createState() => _NotificationHistoryDialogState();
}

class _NotificationHistoryDialogState extends State<_NotificationHistoryDialog> {
  String filter = 'all';
  bool _sameDay(DateTime a, DateTime b) => a.year==b.year && a.month==b.month && a.day==b.day;
  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance.collection('vendors').doc(widget.user.id).collection('notifications').orderBy('createdAt', descending: true).limit(250);
    return Dialog(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: SizedBox(width: 820, height: 680, child: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: q.snapshots(), builder: (_, snap) {
      final all = (snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String,dynamic>>>[]).where((d) {
        final a=d.data();
        final cleared=List<String>.from(a['clearedBy']??const<String>[]).contains(widget.user.authUid);
        return !cleared && _visibleFor(widget.user,a);
      }).toList();
      final now=DateTime.now();
      final docs=all.where((d){ final a=d.data(); final read=List<String>.from(a['readBy']??const<String>[]).contains(widget.user.authUid); final raw=a['createdAt']; final dt=raw is Timestamp?raw.toDate():DateTime.fromMillisecondsSinceEpoch(0); return switch(filter){'unread'=>!read,'read'=>read,'today'=>_sameDay(dt,now),'yesterday'=>_sameDay(dt,now.subtract(const Duration(days:1))),_=>true}; }).toList();
      return Column(children:[
        Padding(padding: const EdgeInsets.fromLTRB(18,14,10,10), child: Row(children:[const Expanded(child: Text('Notification History',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900))), DropdownButton<String>(value:filter,underline:const SizedBox.shrink(),items:const [DropdownMenuItem(value:'all',child:Text('All')),DropdownMenuItem(value:'unread',child:Text('Unread')),DropdownMenuItem(value:'read',child:Text('Read')),DropdownMenuItem(value:'today',child:Text('Today')),DropdownMenuItem(value:'yesterday',child:Text('Yesterday'))],onChanged:(v)=>setState(()=>filter=v??'all')), PopupMenuButton<String>(tooltip:'Clear history view',onSelected:(v)=>_clear(v),itemBuilder:(_)=>const [PopupMenuItem(value:'today',child:Text('Clear today')),PopupMenuItem(value:'yesterday',child:Text('Clear yesterday')),PopupMenuItem(value:'date',child:Text('Clear selected date…')),PopupMenuDivider(),PopupMenuItem(value:'all',child:Text('Clear all'))]), IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded))])),
        const Divider(height:1),
        Expanded(child: docs.isEmpty?const Center(child:Text('No notifications in this view',style:TextStyle(color:_MainShellState.muted))):ListView.separated(padding:const EdgeInsets.all(14),itemCount:docs.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(_,i){final d=docs[i];final a=d.data();final read=List<String>.from(a['readBy']??const<String>[]).contains(widget.user.authUid);return InkWell(onTap:()=>NotificationService().markRead(restaurantId:widget.user.id,notificationId:d.id,authUid:widget.user.authUid),borderRadius:BorderRadius.circular(11),child:Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:read?const Color(0xFFF8FAFC):const Color(0xFFFFF4E5),borderRadius:BorderRadius.circular(11),border:Border.all(color:read?const Color(0xFFE2E8F0):const Color(0xFFF59E0B))),child:Row(children:[Icon(read?Icons.done_all_rounded:Icons.done_rounded,color:read?const Color(0xFF2563EB):const Color(0xFFF97316),size:19),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text((a['title']??'Notification').toString(),style:const TextStyle(fontWeight:FontWeight.w900,fontSize:12)),const SizedBox(height:2),Text((a['message']??'').toString(),style:const TextStyle(fontSize:10.8,color:_MainShellState.muted))])),Text(read?'Read':'Unread',style:TextStyle(fontSize:9.5,fontWeight:FontWeight.w800,color:read?const Color(0xFF2563EB):const Color(0xFFF97316)))]))));})),
      ]);
    })));
  }

  Future<void> _clear(String mode) async {
    DateTime? start; DateTime? end; final now=DateTime.now();
    if(mode=='today'){start=DateTime(now.year,now.month,now.day);end=start.add(const Duration(days:1));}
    if(mode=='yesterday'){end=DateTime(now.year,now.month,now.day);start=end.subtract(const Duration(days:1));}
    if(mode=='date'){final d=await showDatePicker(context:context,firstDate:DateTime(now.year-5),lastDate:now,initialDate:now);if(d==null)return;start=DateTime(d.year,d.month,d.day);end=start.add(const Duration(days:1));}
    await NotificationService().clearForUser(restaurantId:widget.user.id,authUid:widget.user.authUid,start:start,end:end);
  }
}

bool _visibleFor(UserModel u, Map<String,dynamic> a) {
  final roles=List<String>.from(a['targetRoles']??const<String>[]);
  final users=List<String>.from(a['targetUserIds']??const<String>[]);
  if(users.isNotEmpty && !users.contains(u.authUid) && !users.contains(u.id)) return false;
  if(roles.isNotEmpty && !roles.contains(u.role.name) && !(u.isAdmin && roles.contains('admin'))) return false;
  if(users.isEmpty && roles.isEmpty) return u.isAdmin;
  return true;
}
