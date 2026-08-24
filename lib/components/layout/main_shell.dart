import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../../routes/app_router.dart';
import '../../utils/app_colors.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const brandRed = Color(0xFF8D0200);
  Color _accent = brandRed;
  bool _loadedPreference = false;

  bool _editingText() {
    final c = FocusManager.instance.primaryFocus?.context;
    if (c == null) return false;
    return c.widget is EditableText || c.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _go(String route) {
    if (!_editingText()) context.go(route);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedPreference) {
      _loadedPreference = true;
      _loadPreference();
    }
  }

  Future<void> _loadPreference() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('vendors').doc(user.authUid).get();
      if (!mounted) return;
      setState(() => _accent = _accentFor((snap.data()?['uiColorScheme'] ?? 'burgundy').toString()));
    } catch (_) {}
  }

  Color _accentFor(String name) {
    switch (name) {
      case 'purple': return const Color(0xFF6C3BFF);
      case 'navy': return const Color(0xFF183B66);
      case 'emerald': return const Color(0xFF087F5B);
      case 'graphite': return const Color(0xFF374151);
      default: return brandRed;
    }
  }

  Future<void> _setScheme(String name) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    setState(() => _accent = _accentFor(name));
    Navigator.of(context, rootNavigator: true).maybePop();
    try {
      await FirebaseFirestore.instance.collection('vendors').doc(user.authUid).set({'uiColorScheme': name}, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final location = GoRouterState.of(context).uri.toString();
    final canSeeSales = user.role != UserRole.waiter && user.role != UserRole.reception && user.role != UserRole.kitchen;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyD): () => _go(AppRouter.dashboard),
        const SingleActivator(LogicalKeyboardKey.keyT): () => _go(AppRouter.tables),
        const SingleActivator(LogicalKeyboardKey.keyI): () => _go(AppRouter.products),
        const SingleActivator(LogicalKeyboardKey.keyA): () => _go(AppRouter.products),
        const SingleActivator(LogicalKeyboardKey.keyB): () => _go(AppRouter.orders),
        if (canSeeSales) const SingleActivator(LogicalKeyboardKey.keyS): () => _go(AppRouter.sales),
        if (canSeeSales) const SingleActivator(LogicalKeyboardKey.keyR): () => _go(AppRouter.salesReturn),
        const SingleActivator(LogicalKeyboardKey.keyC): () => _go(AppRouter.customers),
        const SingleActivator(LogicalKeyboardKey.keyO): () => _go(AppRouter.purchases),
        const SingleActivator(LogicalKeyboardKey.keyV): () => _go(AppRouter.suppliers),
        const SingleActivator(LogicalKeyboardKey.keyK): () => _go(AppRouter.ingredients),
        const SingleActivator(LogicalKeyboardKey.keyU): () => _go(AppRouter.usersRoles),
        const SingleActivator(LogicalKeyboardKey.keyP): () => _go(AppRouter.settings),
      },
      child: Focus(
        autofocus: true,
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: _accent, brightness: Brightness.light),
            scaffoldBackgroundColor: Colors.white,
          ),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Row(children: [
                _IconRail(currentLocation: location),
                Expanded(
                  child: Column(children: [
                    _QuickTopBar(
                      currentLocation: location,
                      accent: _accent,
                      onChooseColor: _showColors,
                    ),
                    Expanded(child: ColoredBox(color: Colors.white, child: widget.child)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _showColors() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Interface color'),
        content: Wrap(spacing: 12, runSpacing: 12, children: [
          _SchemeDot('burgundy', brandRed, _setScheme),
          _SchemeDot('purple', const Color(0xFF6C3BFF), _setScheme),
          _SchemeDot('navy', const Color(0xFF183B66), _setScheme),
          _SchemeDot('emerald', const Color(0xFF087F5B), _setScheme),
          _SchemeDot('graphite', const Color(0xFF374151), _setScheme),
        ]),
      ),
    );
  }
}

class _IconRail extends StatelessWidget {
  final String currentLocation;
  const _IconRail({required this.currentLocation});

  static const brandRed = Color(0xFF8D0200);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final items = AppRouter.getNavigationItems(auth.currentUser?.role ?? UserRole.admin);

    return Container(
      width: 66,
      color: brandRed,
      child: Column(children: [
        const SizedBox(height: 8),
        Tooltip(
          message: 'Tycoon POS',
          child: InkWell(
            onTap: () => context.go(AppRouter.dashboard),
            child: SizedBox(
              width: 54,
              height: 54,
              child: Image.asset(
                'assets/tycoon_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.shield_outlined, color: Colors.white, size: 32),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Divider(height: 1, color: Colors.white.withValues(alpha: .20)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final selected = currentLocation == item.route || (item.route != '/' && currentLocation.startsWith(item.route));
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Tooltip(
                  message: item.label,
                  child: Material(
                    color: selected ? Colors.white.withValues(alpha: .22) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => context.go(item.route),
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 44,
                        child: Center(child: Icon(item.icon, size: 20, color: selected ? Colors.white : const Color(0xFFF2CFCF))),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Divider(height: 1, color: Colors.white.withValues(alpha: .20)),
        const SizedBox(height: 8),
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white.withValues(alpha: .20),
          child: Text(
            (auth.currentUser?.name ?? 'U').substring(0, 1).toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
        const SizedBox(height: 6),
        Tooltip(
          message: 'Logout',
          child: IconButton(
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) context.go(AppRouter.login);
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 19),
          ),
        ),
        const SizedBox(height: 6),
      ]),
    );
  }
}

class _QuickTopBar extends StatelessWidget {
  final String currentLocation;
  final Color accent;
  final VoidCallback onChooseColor;
  const _QuickTopBar({required this.currentLocation, required this.accent, required this.onChooseColor});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final title = _pageTitle(currentLocation);
    final actions = _quickActions(user?.role ?? UserRole.user);
    final onDashboard = currentLocation == AppRouter.dashboard;

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.outlineLight)),
      ),
      child: Row(children: [
        SizedBox(
          width: 220,
          child: Row(children: [
            if (!onDashboard)
              IconButton(
                tooltip: 'Back',
                onPressed: () => context.canPop() ? context.pop() : context.go(AppRouter.dashboard),
                icon: const Icon(Icons.arrow_back_rounded, size: 19),
              ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    InkWell(
                      onTap: () => context.go(AppRouter.dashboard),
                      child: const Text('Home', style: TextStyle(color: AppColors.grey500, fontSize: 10)),
                    ),
                    if (!onDashboard) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        child: Icon(Icons.chevron_right_rounded, size: 13, color: AppColors.grey400),
                      ),
                      Expanded(child: Text(title, overflow: TextOverflow.ellipsis, style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w700))),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.grey900, fontSize: 17, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ]),
        ),
        Container(width: 1, height: 34, color: AppColors.outlineLight),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: actions.map((a) {
                final selected = _selected(a.route, currentLocation);
                return Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: Tooltip(
                    message: '${a.label} [${a.shortcut}]',
                    child: Material(
                      color: selected ? accent.withValues(alpha: .08) : Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      child: InkWell(
                        onTap: () => context.go(a.route),
                        borderRadius: BorderRadius.circular(9),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: selected ? accent : AppColors.outlineLight),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(a.icon, size: 16, color: selected ? accent : AppColors.grey700),
                            const SizedBox(width: 6),
                            Text(
                              a.label,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                color: selected ? accent : AppColors.grey800,
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 5),
        IconButton(tooltip: 'Interface color', onPressed: onChooseColor, icon: Icon(Icons.palette_outlined, color: accent, size: 19)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(18)),
          child: const Row(children: [
            Icon(Icons.circle, size: 7, color: AppColors.success),
            SizedBox(width: 5),
            Text('Online', style: TextStyle(color: AppColors.successDark, fontSize: 10.5, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 5),
        _NotificationBell(user: user, accent: accent),
        const SizedBox(width: 4),
        CircleAvatar(
          radius: 16,
          backgroundColor: accent.withValues(alpha: .10),
          child: Text((user?.name ?? 'U').substring(0, 1).toUpperCase(), style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 11)),
        ),
      ]),
    );
  }

  bool _selected(String route, String location) => route == AppRouter.dashboard ? location == route : location.startsWith(route);

  List<_QuickAction> _quickActions(UserRole role) {
    if (role == UserRole.superAdmin || role == UserRole.admin) {
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
        _QuickAction('Recipes', Icons.menu_book_outlined, AppRouter.ingredients, 'k'),
        _QuickAction('Users', Icons.manage_accounts_outlined, AppRouter.usersRoles, 'u'),
        _QuickAction('Settings', Icons.settings_outlined, AppRouter.settings, 'p'),
      ];
    }
    if (role == UserRole.waiter) {
      return const [
        _QuickAction('Dashboard', Icons.dashboard_outlined, AppRouter.dashboard, 'd'),
        _QuickAction('Tables', Icons.table_restaurant_outlined, AppRouter.tables, 't'),
        _QuickAction('Billing', Icons.receipt_long_outlined, AppRouter.orders, 'b'),
      ];
    }
    if (role == UserRole.kitchen) {
      return const [
        _QuickAction('Dashboard', Icons.dashboard_outlined, AppRouter.dashboard, 'd'),
        _QuickAction('Kitchen', Icons.soup_kitchen_outlined, AppRouter.orders, 'b'),
      ];
    }
    if (role == UserRole.accounts) {
      return const [
        _QuickAction('Dashboard', Icons.dashboard_outlined, AppRouter.dashboard, 'd'),
        _QuickAction('Sales', Icons.point_of_sale_outlined, AppRouter.sales, 's'),
        _QuickAction('Returns', Icons.assignment_return_outlined, AppRouter.salesReturn, 'r'),
        _QuickAction('Operations', Icons.settings_suggest_outlined, AppRouter.purchases, 'o'),
      ];
    }
    return const [
      _QuickAction('Dashboard', Icons.dashboard_outlined, AppRouter.dashboard, 'd'),
      _QuickAction('Tables', Icons.table_restaurant_outlined, AppRouter.tables, 't'),
      _QuickAction('Billing', Icons.receipt_long_outlined, AppRouter.orders, 'b'),
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

class _NotificationBell extends StatelessWidget {
  final UserModel? user;
  final Color accent;
  const _NotificationBell({required this.user, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();
    final ref = FirebaseFirestore.instance.collection('vendors').doc(user!.id).collection('notifications');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.orderBy('createdAt', descending: true).limit(30).snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final visible = docs.where((doc) {
          final d = doc.data();
          final target = d['targetAuthUid']?.toString();
          final roles = List<String>.from(d['targetRoles'] ?? const <String>[]);
          return (target == null || target.isEmpty || target == user!.authUid) && (roles.isEmpty || roles.contains(user!.role.name));
        }).toList();
        final unread = visible.where((doc) => !List<String>.from(doc.data()['readBy'] ?? const <String>[]).contains(user!.authUid)).length;
        return Stack(clipBehavior: Clip.none, children: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => _show(context, visible),
            icon: const Icon(Icons.notifications_none_rounded, color: AppColors.grey700, size: 20),
          ),
          if (unread > 0)
            Positioned(
              right: 5,
              top: 5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 15),
                height: 15,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text(unread > 9 ? '9+' : '$unread', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
        ]);
      },
    );
  }

  void _show(BuildContext context, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SizedBox(
        height: MediaQuery.of(sheet).size.height * .62,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
            child: Row(children: [
              const Expanded(child: Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
              Text('${docs.length} events', style: const TextStyle(fontSize: 10, color: AppColors.grey500)),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(sheet),
                icon: const Icon(Icons.close_rounded),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: docs.isEmpty
                ? const Center(child: Text('No notifications yet.', style: TextStyle(color: AppColors.grey500)))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final doc = docs[i];
                      final d = doc.data();
                      final readBy = List<String>.from(d['readBy'] ?? const <String>[]);
                      final unread = !readBy.contains(user!.authUid);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        leading: CircleAvatar(
                          backgroundColor: unread ? accent.withValues(alpha: .10) : AppColors.grey100,
                          child: Icon(_eventIcon((d['type'] ?? '').toString()), color: unread ? accent : AppColors.grey500, size: 18),
                        ),
                        title: Text((d['title'] ?? 'Event').toString(), style: TextStyle(fontSize: 12, fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
                        subtitle: Text((d['message'] ?? '').toString(), style: const TextStyle(fontSize: 10.5, color: AppColors.grey500)),
                        onTap: () async {
                          await doc.reference.set({'readBy': FieldValue.arrayUnion([user!.authUid])}, SetOptions(merge: true));
                        },
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'work_started': return Icons.login_rounded;
      case 'work_ended': return Icons.logout_rounded;
      case 'review': return Icons.star_outline_rounded;
      case 'wage_cut': return Icons.money_off_csred_outlined;
      case 'late_start': return Icons.schedule_rounded;
      case 'missing': return Icons.person_off_outlined;
      case 'account_created': return Icons.person_add_alt_1_rounded;
      default: return Icons.notifications_active_outlined;
    }
  }
}

class _SchemeDot extends StatelessWidget {
  final String name;
  final Color color;
  final Future<void> Function(String) onTap;
  const _SchemeDot(this.name, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => Tooltip(
        message: name,
        child: InkWell(
          onTap: () => onTap(name),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 5)]),
          ),
        ),
      );
}

class _QuickAction {
  final String label;
  final IconData icon;
  final String route;
  final String shortcut;
  const _QuickAction(this.label, this.icon, this.route, this.shortcut);
}
