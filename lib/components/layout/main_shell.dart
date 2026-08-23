import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/subscription_provider.dart';
import 'package:provider/provider.dart';
import '../../routes/app_router.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final compact = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Row(
          children: [
            if (!compact)
              _SideNavigation(
                currentLocation: location,
                collapsed: _collapsed,
                onToggle: () => setState(() => _collapsed = !_collapsed),
              ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(currentLocation: location, compact: compact),
                  Expanded(
                    child: ColoredBox(
                      color: AppColors.backgroundLight,
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      drawer: compact
          ? Drawer(
              child: _SideNavigation(
                currentLocation: location,
                mobile: true,
                collapsed: false,
                onToggle: () => Navigator.of(context).maybePop(),
              ),
            )
          : null,
    );
  }
}

class _SideNavigation extends StatelessWidget {
  final String currentLocation;
  final bool mobile;
  final bool collapsed;
  final VoidCallback onToggle;

  const _SideNavigation({
    required this.currentLocation,
    required this.collapsed,
    required this.onToggle,
    this.mobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final items = AppRouter.getNavigationItems(
      auth.currentUser?.role ?? UserRole.admin,
    );
    final restaurant = auth.currentUser?.restaurantName.isNotEmpty == true
        ? auth.currentUser!.restaurantName
        : 'Restaurant POS';

    final width = mobile ? 280.0 : (collapsed ? 78.0 : 248.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: width,
      color: AppColors.sidebar,
      child: Column(
        children: [
          SizedBox(
            height: 76,
            child: Row(
              mainAxisAlignment:
                  collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (!collapsed) const SizedBox(width: 16),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.point_of_sale_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TYCOON POS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .4,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Restaurant Cloud',
                          style: TextStyle(
                            color: AppColors.sidebarMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.sidebarBorder),
          Padding(
            padding: EdgeInsets.fromLTRB(
              collapsed ? 12 : 14,
              12,
              collapsed ? 12 : 14,
              8,
            ),
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 38,
                padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 10),
                child: Row(
                  mainAxisAlignment:
                      collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    Icon(
                      collapsed
                          ? Icons.keyboard_double_arrow_right_rounded
                          : Icons.keyboard_double_arrow_left_rounded,
                      size: 19,
                      color: AppColors.sidebarMuted,
                    ),
                    if (!collapsed) ...[
                      const SizedBox(width: 10),
                      const Text(
                        'Collapse menu',
                        style: TextStyle(
                          color: AppColors.sidebarMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  restaurant.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.sidebarMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 10 : 12,
                vertical: 2,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final selected = currentLocation == item.route ||
                    (item.route != '/' && currentLocation.startsWith(item.route));
                return _NavItem(
                  item: item,
                  selected: selected,
                  collapsed: collapsed,
                  onTap: () => _navigate(context, item),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(collapsed ? 10 : 12),
            child: Container(
              height: collapsed ? 48 : 60,
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 10),
              decoration: BoxDecoration(
                color: AppColors.sidebarCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: collapsed
                  ? Tooltip(
                      message: auth.currentUser?.name ?? 'Account',
                      child: IconButton(
                        tooltip: 'Logout',
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: AppColors.sidebarMuted,
                          size: 19,
                        ),
                        onPressed: () => _confirmLogout(context, auth),
                      ),
                    )
                  : Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: AppColors.primary.withValues(alpha: .18),
                          child: const Icon(
                            Icons.person_rounded,
                            color: AppColors.primaryLight,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                auth.currentUser?.name ?? 'Account',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (auth.currentUser?.role.name ?? 'user')
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.sidebarMuted,
                                  fontSize: 9,
                                  letterSpacing: .6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Logout',
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: AppColors.sidebarMuted,
                            size: 18,
                          ),
                          onPressed: () => _confirmLogout(context, auth),
                        ),
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
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await auth.signOut();
              if (context.mounted) context.go(AppRouter.login);
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final NavigationItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Material(
      color: selected
          ? AppColors.primary.withValues(alpha: .16)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12),
          child: Row(
            mainAxisAlignment:
                collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                item.icon,
                size: 19,
                color: selected ? AppColors.primaryLight : AppColors.sidebarMuted,
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.sidebarText,
                      fontSize: 12.8,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: collapsed ? Tooltip(message: item.label, child: tile) : tile,
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
      height: 68,
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.outlineLight)),
      ),
      child: Row(
        children: [
          if (compact) ...[
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.grey900,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!compact)
                const Text(
                  'Restaurant operations',
                  style: TextStyle(color: AppColors.grey500, fontSize: 10.8),
                ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.successSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, size: 7, color: AppColors.success),
                SizedBox(width: 6),
                Text(
                  'Online',
                  style: TextStyle(
                    color: AppColors.successDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.grey700,
              size: 21,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 4),
            Container(width: 1, height: 26, color: AppColors.outlineLight),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primarySoft,
              child: Text(
                (auth.currentUser?.name ?? 'U').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _pageTitle(String path) {
    if (path.startsWith('/table-order')) return 'Point of Sale';
    if (path.startsWith(AppRouter.tables)) return 'Tables';
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
