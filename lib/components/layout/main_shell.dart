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
    if (_editingText()) return;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
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
        child: Scaffold(
          backgroundColor: AppColors.backgroundLight,
          body: SafeArea(
            child: Row(children: [
              _IconRail(currentLocation: location),
              Expanded(child: Column(children: [
                _QuickTopBar(currentLocation: location),
                Expanded(child: ColoredBox(color: AppColors.backgroundLight, child: child)),
              ])),
            ]),
          ),
        ),
      ),
    );
  }
}

class _IconRail extends StatelessWidget {
  final String currentLocation;
  const _IconRail({required this.currentLocation});

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
          child: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 22)),
        )),
        const SizedBox(height: 10),
        const Divider(height: 1, color: AppColors.sidebarBorder),
        const SizedBox(height: 10),
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final selected = currentLocation == item.route || (item.route != '/' && currentLocation.startsWith(item.route));
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Tooltip(
                message: _railTooltip(item),
                preferBelow: false,
                waitDuration: const Duration(milliseconds: 250),
                child: Material(
                  color: selected ? AppColors.primary.withValues(alpha: .22) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _navigate(context, item),
                    child: SizedBox(height: 44, child: Center(child: Icon(item.icon, size: 20, color: selected ? Colors.white : AppColors.sidebarMuted))),
                  ),
                ),
              ),
            );
          },
        )),
        const Divider(height: 1, color: AppColors.sidebarBorder),
        const SizedBox(height: 8),
        Tooltip(message: auth.currentUser?.name ?? 'Account', child: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary.withValues(alpha: .20),
          child: Text((auth.currentUser?.name ?? 'U').substring(0, 1).toUpperCase(), style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w800, fontSize: 12)),
        )),
        const SizedBox(height: 6),
        Tooltip(message: 'Logout', child: IconButton(onPressed: () => _confirmLogout(context, auth), icon: const Icon(Icons.logout_rounded, color: AppColors.sidebarMuted, size: 19))),
        const SizedBox(height: 8),
      ]),
    );
  }

  String _railTooltip(NavigationItem item) {
    const keys = {
      'Dashboard': 'd', 'Tables': 't', 'Billing': 'b', 'Inventory': 'i', 'CRM': 'c',
      'Operations': 'o', 'Kitchen Recipes': 'k', 'Vendors': 'v', 'Preferences': 'p',
    };
    final key = keys[item.label];
    return key == null ? item.label : '${item.label}  [$key]';
  }

  Future<void> _navigate(BuildContext context, NavigationItem item) async {
    try {
      final subscription = context.read<SubscriptionProvider>();
      final valid = await subscription.hasValidSubscription();
      if (!context.mounted) return;
      if (!valid && item.route != AppRouter.pricing) {
        context.go(AppRouter.pricing);
      } else {
        context.go(item.route);
      }
    } catch (_) {
      if (context.mounted) context.go(item.route);
    }
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out of Tycoon POS?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            Navigator.pop(dialogContext);
            await auth.signOut();
            if (context.mounted) context.go(AppRouter.login);
          }, child: const Text('Sign out')),
        ],
      ),
    );
  }
}

class _QuickTopBar extends StatelessWidget {
  final String currentLocation;
  const _QuickTopBar({required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final title = _pageTitle(currentLocation);
    final user = auth.currentUser;
    final isAdmin = user?.isAdmin ?? false;
    final actions = _quickActions(isAdmin);
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.outlineLight))),
      child: Row(children: [
        SizedBox(width: 155, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.grey900, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(user?.department.isNotEmpty == true ? user!.department : (isAdmin ? 'Restaurant Admin' : 'Restaurant Operator'), style: const TextStyle(color: AppColors.grey500, fontSize: 10.5)),
        ])),
        Container(width: 1, height: 32, color: AppColors.outlineLight),
        const SizedBox(width: 12),
        Expanded(child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: actions.map((action) {
            final selected = _isQuickSelected(action.route, currentLocation);
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: '${action.label}  [${action.shortcut}]',
                waitDuration: const Duration(milliseconds: 200),
                child: Material(
                  color: selected ? AppColors.primarySoft : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    onTap: () => context.go(action.route),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(width: 42, height: 42, decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: selected ? AppColors.primary.withValues(alpha: .35) : AppColors.outlineLight)), child: Icon(action.icon, size: 19, color: selected ? AppColors.primary : AppColors.grey700)),
                  ),
                ),
              ),
            );
          }).toList()),
        )),
        const SizedBox(width: 10),
        Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(18)), child: const Row(children: [Icon(Icons.circle, size: 7, color: AppColors.success), SizedBox(width: 5), Text('Online', style: TextStyle(color: AppColors.successDark, fontSize: 10.5, fontWeight: FontWeight.w700))])),
        const SizedBox(width: 8),
        Tooltip(message: 'Notifications', child: IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded, color: AppColors.grey700, size: 20))),
        const SizedBox(width: 3),
        CircleAvatar(radius: 16, backgroundColor: AppColors.primarySoft, child: Text((user?.name ?? 'U').substring(0, 1).toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 11))),
      ]),
    );
  }

  bool _isQuickSelected(String route, String location) {
    if (route == AppRouter.dashboard) return location == AppRouter.dashboard;
    return location.startsWith(route);
  }

  List<_QuickAction> _quickActions(bool isAdmin) {
    if (!isAdmin) {
      return const [
        _QuickAction('Dashboard', Icons.dashboard_outlined, AppRouter.dashboard, 'd'),
        _QuickAction('Tables', Icons.table_restaurant_outlined, AppRouter.tables, 't'),
        _QuickAction('Billing', Icons.receipt_long_outlined, AppRouter.orders, 'b'),
        _QuickAction('Sales', Icons.point_of_sale_outlined, AppRouter.sales, 's'),
      ];
    }
    return const [
      _QuickAction('Dashboard', Icons.dashboard_outlined, AppRouter.dashboard, 'd'),
      _QuickAction('Tables', Icons.table_restaurant_outlined, AppRouter.tables, 't'),
      _QuickAction('Inventory', Icons.inventory_2_outlined, AppRouter.products, 'i'),
      _QuickAction('Add Item', Icons.add_box_outlined, AppRouter.products, 'a'),
      _QuickAction('Billing', Icons.receipt_long_outlined, AppRouter.orders, 'b'),
      _QuickAction('Sales', Icons.point_of_sale_outlined, AppRouter.sales, 's'),
      _QuickAction('Returns', Icons.assignment_return_outlined, AppRouter.salesReturn, 'r'),
      _QuickAction('CRM', Icons.people_alt_outlined, AppRouter.customers, 'c'),
      _QuickAction('Operations', Icons.settings_suggest_outlined, AppRouter.purchases, 'o'),
      _QuickAction('Vendors', Icons.local_shipping_outlined, AppRouter.suppliers, 'v'),
      _QuickAction('Kitchen Recipes', Icons.menu_book_outlined, AppRouter.ingredients, 'k'),
      _QuickAction('Users', Icons.manage_accounts_outlined, AppRouter.usersRoles, 'u'),
      _QuickAction('Preferences', Icons.settings_outlined, AppRouter.settings, 'p'),
    ];
  }

  String _pageTitle(String path) {
    if (path.startsWith('/table-order')) return 'POS';
    if (path.startsWith(AppRouter.tables)) return 'Tables';
    if (path.startsWith(AppRouter.products)) return 'Inventory';
    if (path.startsWith(AppRouter.orders)) return 'Billing';
    if (path.startsWith(AppRouter.customers)) return 'CRM';
    if (path.startsWith(AppRouter.purchases)) return 'Operations';
    if (path.startsWith(AppRouter.ingredients)) return 'Kitchen Recipes';
    if (path.startsWith(AppRouter.suppliers)) return 'Vendors';
    if (path.startsWith(AppRouter.usersRoles)) return 'Users & Roles';
    if (path.startsWith(AppRouter.settings)) return 'Preferences';
    if (path.startsWith(AppRouter.salesReturn)) return 'Returns';
    if (path.startsWith(AppRouter.sales)) return 'Sales';
    return 'Dashboard';
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final String route;
  final String shortcut;
  const _QuickAction(this.label, this.icon, this.route, this.shortcut);
}
