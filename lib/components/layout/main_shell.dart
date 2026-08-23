import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/subscription_provider.dart';
import 'package:provider/provider.dart';
import '../../routes/app_router.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final compact = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Row(
          children: [
            if (!compact) _SideNavigation(currentLocation: location),
            Expanded(
              child: Column(
                children: [
                  _TopBar(currentLocation: location, compact: compact),
                  Expanded(
                    child: Container(
                      color: AppColors.backgroundLight,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      drawer: compact
          ? Drawer(child: _SideNavigation(currentLocation: location, mobile: true))
          : null,
    );
  }
}

class _SideNavigation extends StatelessWidget {
  final String currentLocation;
  final bool mobile;
  const _SideNavigation({required this.currentLocation, this.mobile = false});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final items = AppRouter.getNavigationItems(auth.currentUser?.role ?? UserRole.admin);
    final restaurant = auth.currentUser?.restaurantName.isNotEmpty == true
        ? auth.currentUser!.restaurantName
        : 'Restaurant POS';

    return Container(
      width: mobile ? 280 : 252,
      color: AppColors.sidebar,
      child: Column(
        children: [
          Container(
            height: 82,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.sidebarBorder)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 23),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TYCOON POS', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: .5)),
                      SizedBox(height: 3),
                      Text('Restaurant Cloud', style: TextStyle(color: AppColors.sidebarMuted, fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(restaurant.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.sidebarMuted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final selected = currentLocation == item.route || (item.route != '/' && currentLocation.startsWith(item.route));
                return _NavItem(item: item, selected: selected, onTap: () => _navigate(context, item));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.sidebarCard, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withOpacity(.18),
                    child: const Icon(Icons.person_rounded, color: AppColors.primaryLight, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(auth.currentUser?.name ?? 'Account', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text((auth.currentUser?.role.name ?? 'user').toUpperCase(), style: const TextStyle(color: AppColors.sidebarMuted, fontSize: 9.5, letterSpacing: .7)),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Logout',
                    icon: const Icon(Icons.logout_rounded, color: AppColors.sidebarMuted, size: 18),
                    onPressed: () => _confirmLogout(context, auth),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
        if (mobile) Navigator.of(context).maybePop();
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

class _NavItem extends StatefulWidget {
  final NavigationItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.item, required this.selected, required this.onTap});
  @override State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: widget.selected ? AppColors.primary.withOpacity(.16) : hover ? Colors.white.withOpacity(.055) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onTap,
            child: Container(
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: widget.selected ? const Border(left: BorderSide(color: AppColors.primary, width: 3)) : null,
              ),
              child: Row(children: [
                Icon(widget.item.icon, size: 19, color: widget.selected ? AppColors.primaryLight : AppColors.sidebarMuted),
                const SizedBox(width: 12),
                Expanded(child: Text(widget.item.label, style: TextStyle(color: widget.selected ? Colors.white : AppColors.sidebarText, fontSize: 13, fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String currentLocation;
  final bool compact;
  const _TopBar({required this.currentLocation, required this.compact});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final title = _pageTitle(currentLocation);
    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 26),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.outlineLight))),
      child: Row(children: [
        if (compact) ...[
          Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () => Scaffold.of(context).openDrawer())),
          const SizedBox(width: 8),
        ],
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppColors.grey900, fontSize: 20, fontWeight: FontWeight.w700)),
          if (!compact) const Text('Manage restaurant operations', style: TextStyle(color: AppColors.grey500, fontSize: 11.5)),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(20)),
          child: const Row(children: [
            Icon(Icons.circle, size: 7, color: AppColors.success),
            SizedBox(width: 6),
            Text('Online', style: TextStyle(color: AppColors.successDark, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(width: 14),
        IconButton(tooltip: 'Notifications', onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded, color: AppColors.grey700)),
        if (!compact) ...[
          const SizedBox(width: 8),
          Container(width: 1, height: 28, color: AppColors.outlineLight),
          const SizedBox(width: 14),
          CircleAvatar(radius: 17, backgroundColor: AppColors.primarySoft, child: Text((auth.currentUser?.name ?? 'U').substring(0, 1).toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
        ],
      ]),
    );
  }

  String _pageTitle(String path) {
    if (path.startsWith('/table-order')) return 'Point of Sale';
    if (path.startsWith(AppRouter.tables)) return 'Table Management';
    if (path.startsWith(AppRouter.products)) return 'Inventory';
    if (path.startsWith(AppRouter.orders)) return 'Orders';
    if (path.startsWith(AppRouter.customers)) return 'Customers';
    if (path.startsWith(AppRouter.purchases)) return 'Operations';
    if (path.startsWith(AppRouter.ingredients)) return 'Recipe Management';
    if (path.startsWith(AppRouter.suppliers)) return 'Suppliers';
    if (path.startsWith(AppRouter.settings)) return 'Settings';
    return 'Dashboard';
  }
}
