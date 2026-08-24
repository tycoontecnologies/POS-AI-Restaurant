import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/subscription_provider.dart';
import 'package:provider/provider.dart';
import '../../routes/app_router.dart';
import '../../utils/app_colors.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  bool _editingText() {
    final c = FocusManager.instance.primaryFocus?.context;
    if (c == null) return false;
    if (c.widget is EditableText) return true;
    return c.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _shortcut(BuildContext context, String route) {
    if (!_editingText()) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final location = GoRouterState.of(context).uri.toString();
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('vendors').doc(user.authUid).snapshots(),
      builder: (_, snap) {
        final scheme = (snap.data?.data()?['uiColorScheme'] ?? 'purple').toString();
        final accent = _accentFor(scheme);
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyD): () => _shortcut(context, AppRouter.dashboard),
            const SingleActivator(LogicalKeyboardKey.keyT): () => _shortcut(context, AppRouter.tables),
            const SingleActivator(LogicalKeyboardKey.keyI): () => _shortcut(context, AppRouter.products),
            const SingleActivator(LogicalKeyboardKey.keyA): () => _shortcut(context, AppRouter.products),
            const SingleActivator(LogicalKeyboardKey.keyB): () => _shortcut(context, AppRouter.orders),
            const SingleActivator(LogicalKeyboardKey.keyS): () => _shortcut(context, AppRouter.sales),
            const SingleActivator(LogicalKeyboardKey.keyR): () => _shortcut(context, AppRouter.salesReturn),
            const SingleActivator(LogicalKeyboardKey.keyC): () => _shortcut(context, AppRouter.customers),
            const SingleActivator(LogicalKeyboardKey.keyO): () => _shortcut(context, AppRouter.purchases),
            const SingleActivator(LogicalKeyboardKey.keyV): () => _shortcut(context, AppRouter.suppliers),
            const SingleActivator(LogicalKeyboardKey.keyK): () => _shortcut(context, AppRouter.ingredients),
            const SingleActivator(LogicalKeyboardKey.keyU): () => _shortcut(context, AppRouter.usersRoles),
            const SingleActivator(LogicalKeyboardKey.keyP): () => _shortcut(context, AppRouter.settings),
          },
          child: Focus(
            autofocus: true,
            child: Theme(
              data: Theme.of(context).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.light)),
              child: Scaffold(
                backgroundColor: AppColors.backgroundLight,
                body: SafeArea(
                  child: Row(children: [
                    _IconRail(currentLocation: location, accent: accent),
                    Expanded(child: Column(children: [
                      _QuickTopBar(currentLocation: location, accent: accent, scheme: scheme),
                      Expanded(child: ColoredBox(color: AppColors.backgroundLight, child: child)),
                    ])),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Color _accentFor(String name) {
    switch (name) {
      case 'burgundy': return const Color(0xFF6B1020);
      case 'navy': return const Color(0xFF183B66);
      case 'emerald': return const Color(0xFF087F5B);
      case 'graphite': return const Color(0xFF374151);
      default: return const Color(0xFF6C3BFF);
    }
  }
}

class _IconRail extends StatelessWidget {
  final String currentLocation;
  final Color accent;
  const _IconRail({required this.currentLocation, required this.accent});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final items = AppRouter.getNavigationItems(auth.currentUser?.role ?? UserRole.admin);
    return Container(
      width: 66,
      color: AppColors.sidebar,
      child: Column(children: [
        const SizedBox(height: 10),
        Tooltip(message: 'Dashboard [d]', child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go(AppRouter.dashboard),
          child: Container(width: 44, height: 44, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 22)),
        )),
        const SizedBox(height: 10), const Divider(height: 1, color: AppColors.sidebarBorder), const SizedBox(height: 10),
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 9), itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final selected = currentLocation == item.route || (item.route != '/' && currentLocation.startsWith(item.route));
            return Padding(padding: const EdgeInsets.only(bottom: 5), child: Tooltip(
              message: _railTooltip(item), preferBelow: false, waitDuration: const Duration(milliseconds: 200),
              child: Material(color: selected ? accent.withValues(alpha: .25) : Colors.transparent, borderRadius: BorderRadius.circular(10), child: InkWell(
                borderRadius: BorderRadius.circular(10), onTap: () => _navigate(context, item),
                child: SizedBox(height: 44, child: Center(child: Icon(item.icon, size: 20, color: selected ? Colors.white : AppColors.sidebarMuted))),
              )),
            ));
          },
        )),
        const Divider(height: 1, color: AppColors.sidebarBorder), const SizedBox(height: 8),
        Tooltip(message: 'Account & colors', child: InkWell(
          onTap: () => _showAccountMenu(context, auth, accent),
          borderRadius: BorderRadius.circular(30),
          child: CircleAvatar(radius: 18, backgroundColor: accent.withValues(alpha: .25), child: Text((auth.currentUser?.name ?? 'U').substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
        )),
        const SizedBox(height: 6),
        Tooltip(message: 'Logout', child: IconButton(onPressed: () => _confirmLogout(context, auth), icon: const Icon(Icons.logout_rounded, color: AppColors.sidebarMuted, size: 19))),
        const SizedBox(height: 8),
      ]),
    );
  }

  String _railTooltip(NavigationItem item) {
    const keys = {'Dashboard':'d','Tables':'t','Billing':'b','Inventory':'i','CRM':'c','Operations':'o','Kitchen Recipes':'k','Vendors':'v','Preferences':'p'};
    final key = keys[item.label];
    return key == null ? item.label : '${item.label}  [$key]';
  }

  Future<void> _navigate(BuildContext context, NavigationItem item) async {
    try {
      final valid = await context.read<SubscriptionProvider>().hasValidSubscription();
      if (!context.mounted) return;
      context.go(!valid && item.route != AppRouter.pricing ? AppRouter.pricing : item.route);
    } catch (_) {
      if (context.mounted) context.go(item.route);
    }
  }

  void _showAccountMenu(BuildContext context, AuthProvider auth, Color accent) {
    showModalBottomSheet(context: context, showDragHandle: true, builder: (sheet) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(auth.currentUser?.name ?? 'Account', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3), Text(auth.currentUser?.department ?? '', style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
        const SizedBox(height: 18), const Text('Interface color', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const SizedBox(height: 10),
        Wrap(spacing: 10, children: const [
          _SchemeDot('burgundy', Color(0xFF6B1020)), _SchemeDot('purple', Color(0xFF6C3BFF)), _SchemeDot('navy', Color(0xFF183B66)), _SchemeDot('emerald', Color(0xFF087F5B)), _SchemeDot('graphite', Color(0xFF374151)),
        ]),
      ]),
    ));
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog(context: context, builder: (d) => AlertDialog(title: const Text('Sign out'), content: const Text('Are you sure you want to sign out of Tycoon POS?'), actions: [
      TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
      FilledButton(onPressed: () async { Navigator.pop(d); await auth.signOut(); if (context.mounted) context.go(AppRouter.login); }, child: const Text('Sign out')),
    ]));
  }
}

class _SchemeDot extends StatelessWidget {
  final String name; final Color color;
  const _SchemeDot(this.name, this.color);
  @override
  Widget build(BuildContext context) => Tooltip(message: name, child: InkWell(
    onTap: () async {
      final user = context.read<AuthProvider>().currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance.collection('vendors').doc(user.authUid).set({'uiColorScheme': name}, SetOptions(merge: true));
      if (context.mounted) Navigator.pop(context);
    },
    borderRadius: BorderRadius.circular(30),
    child: Container(width: 34, height: 34, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 5)])),
  ));
}

class _QuickTopBar extends StatelessWidget {
  final String currentLocation; final Color accent; final String scheme;
  const _QuickTopBar({required this.currentLocation, required this.accent, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final title = _pageTitle(currentLocation);
    final isAdmin = user?.isAdmin ?? false;
    final actions = _quickActions(isAdmin);
    final onDashboard = currentLocation == AppRouter.dashboard;
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.outlineLight))),
      child: Row(children: [
        SizedBox(width: 198, child: Row(children: [
          if (!onDashboard) Tooltip(message: 'Back', child: IconButton(onPressed: () => _goBack(context), icon: const Icon(Icons.arrow_back_rounded, size: 19))),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [InkWell(onTap: () => context.go(AppRouter.dashboard), child: const Text('Home', style: TextStyle(color: AppColors.grey500, fontSize: 9.5))), if (!onDashboard) ...[const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Icon(Icons.chevron_right_rounded, size: 13, color: AppColors.grey400)), Expanded(child: Text(title, overflow: TextOverflow.ellipsis, style: TextStyle(color: accent, fontSize: 9.5, fontWeight: FontWeight.w700)))] ]),
            const SizedBox(height: 3), Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.grey900, fontSize: 16.5, fontWeight: FontWeight.w800)),
          ])),
        ])),
        Container(width: 1, height: 34, color: AppColors.outlineLight), const SizedBox(width: 12),
        Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: actions.map((a) {
          final selected = _isSelected(a.route, currentLocation);
          return Padding(padding: const EdgeInsets.only(right: 6), child: Tooltip(message: '${a.label}  [${a.shortcut}]', child: Material(
            color: selected ? accent.withValues(alpha: .09) : Colors.white, borderRadius: BorderRadius.circular(9),
            child: InkWell(onTap: () => context.go(a.route), borderRadius: BorderRadius.circular(9), child: Container(width: 42, height: 42, decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: selected ? accent.withValues(alpha: .45) : AppColors.outlineLight)), child: Icon(a.icon, size: 19, color: selected ? accent : AppColors.grey700))),
          )));
        }).toList()))),
        const SizedBox(width: 8),
        Tooltip(message: 'Change interface color', child: IconButton(onPressed: () => _openColorPicker(context), icon: Icon(Icons.palette_outlined, color: accent, size: 20))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(18)), child: const Row(children: [Icon(Icons.circle, size: 7, color: AppColors.success), SizedBox(width: 5), Text('Online', style: TextStyle(color: AppColors.successDark, fontSize: 10.5, fontWeight: FontWeight.w700))])),
        const SizedBox(width: 7), IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded, color: AppColors.grey700, size: 20)),
        CircleAvatar(radius: 16, backgroundColor: accent.withValues(alpha: .10), child: Text((user?.name ?? 'U').substring(0,1).toUpperCase(), style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 11))),
      ]),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) { context.pop(); return; }
    context.go(AppRouter.dashboard);
  }

  void _openColorPicker(BuildContext context) {
    showDialog(context: context, builder: (d) => AlertDialog(title: const Text('Interface color'), content: const Wrap(spacing: 12, runSpacing: 12, children: [
      _SchemeDot('burgundy', Color(0xFF6B1020)), _SchemeDot('purple', Color(0xFF6C3BFF)), _SchemeDot('navy', Color(0xFF183B66)), _SchemeDot('emerald', Color(0xFF087F5B)), _SchemeDot('graphite', Color(0xFF374151)),
    ])));
  }

  bool _isSelected(String route, String location) => route == AppRouter.dashboard ? location == route : location.startsWith(route);

  List<_QuickAction> _quickActions(bool admin) => admin ? const [
    _QuickAction('Dashboard', Icons.dashboard_outlined, AppRouter.dashboard, 'd'), _QuickAction('Tables', Icons.table_restaurant_outlined, AppRouter.tables, 't'), _QuickAction('Inventory', Icons.inventory_2_outlined, AppRouter.products, 'i'), _QuickAction('Add Item', Icons.add_box_outlined, AppRouter.products, 'a'), _QuickAction('Billing', Icons.receipt_long_outlined, AppRouter.orders, 'b'), _QuickAction('Sales', Icons.point_of_sale_outlined, AppRouter.sales, 's'), _QuickAction('Returns', Icons.assignment_return_outlined, AppRouter.salesReturn, 'r'), _QuickAction('CRM', Icons.people_alt_outlined, AppRouter.customers, 'c'), _QuickAction('Operations', Icons.settings_suggest_outlined, AppRouter.purchases, 'o'), _QuickAction('Vendors', Icons.local_shipping_outlined, AppRouter.suppliers, 'v'), _QuickAction('Kitchen Recipes', Icons.menu_book_outlined, AppRouter.ingredients, 'k'), _QuickAction('Users', Icons.manage_accounts_outlined, AppRouter.usersRoles, 'u'), _QuickAction('Preferences', Icons.settings_outlined, AppRouter.settings, 'p'),
  ] : const [_QuickAction('Dashboard', Icons.dashboard_outlined, AppRouter.dashboard, 'd'), _QuickAction('Tables', Icons.table_restaurant_outlined, AppRouter.tables, 't'), _QuickAction('Billing', Icons.receipt_long_outlined, AppRouter.orders, 'b'), _QuickAction('Sales', Icons.point_of_sale_outlined, AppRouter.sales, 's')];

  String _pageTitle(String path) {
    if (path.startsWith('/table-order')) return 'POS'; if (path.startsWith(AppRouter.tables)) return 'Tables'; if (path.startsWith(AppRouter.products)) return 'Inventory'; if (path.startsWith(AppRouter.orders)) return 'Billing'; if (path.startsWith(AppRouter.customers)) return 'CRM'; if (path.startsWith(AppRouter.purchases)) return 'Operations'; if (path.startsWith(AppRouter.ingredients)) return 'Kitchen Recipes'; if (path.startsWith(AppRouter.suppliers)) return 'Vendors'; if (path.startsWith(AppRouter.usersRoles)) return 'Users & Roles'; if (path.startsWith(AppRouter.settings)) return 'Preferences'; if (path.startsWith(AppRouter.salesReturn)) return 'Returns'; if (path.startsWith(AppRouter.sales)) return 'Sales'; return 'Dashboard';
  }
}

class _QuickAction {
  final String label; final IconData icon; final String route; final String shortcut;
  const _QuickAction(this.label, this.icon, this.route, this.shortcut);
}
