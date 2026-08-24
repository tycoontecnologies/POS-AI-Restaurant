import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/routes/app_router.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _purple = Color(0xFF6C3BFF);
  static const _red = Color(0xFFD80000);
  static const _line = Color(0xFFE2E8F0);
  Color _accent = _purple;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _loadScheme();
  }

  Future<void> _loadScheme() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('vendors').doc(user.id).get();
      if (!mounted) return;
      setState(() => _accent = _accentFor((snap.data()?['uiColorScheme'] ?? 'purple').toString()));
    } catch (_) {}
  }

  Color _accentFor(String name) {
    switch (name) {
      case 'burgundy':
        return const Color(0xFF8B1E2D);
      case 'navy':
        return const Color(0xFF183B66);
      case 'emerald':
        return const Color(0xFF087F5B);
      case 'graphite':
        return const Color(0xFF374151);
      default:
        return _purple;
    }
  }

  Future<void> _setScheme(String name) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    setState(() => _accent = _accentFor(name));
    Navigator.of(context, rootNavigator: true).maybePop();
    await FirebaseFirestore.instance.collection('vendors').doc(user.id).set({'uiColorScheme': name}, SetOptions(merge: true));
  }

  bool _editingText() {
    final c = FocusManager.instance.primaryFocus?.context;
    return c != null && (c.widget is EditableText || c.findAncestorWidgetOfExactType<EditableText>() != null);
  }

  void _go(String route) {
    if (!_editingText()) context.go(route);
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
        const SingleActivator(LogicalKeyboardKey.keyE): () => _go(AppRouter.expenses),
        const SingleActivator(LogicalKeyboardKey.keyM): () => _go(AppRouter.storeOut),
        const SingleActivator(LogicalKeyboardKey.keyL): () => _go(AppRouter.branches),
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
                _SideRail(currentLocation: location, red: _red),
                Expanded(
                  child: Column(children: [
                    _TopBar(currentLocation: location, accent: _accent, onChooseColor: _showColors),
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
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Interface color'),
        content: Wrap(spacing: 12, runSpacing: 12, children: [
          _Scheme('purple', _purple, _setScheme),
          _Scheme('burgundy', const Color(0xFF8B1E2D), _setScheme),
          _Scheme('navy', const Color(0xFF183B66), _setScheme),
          _Scheme('emerald', const Color(0xFF087F5B), _setScheme),
          _Scheme('graphite', const Color(0xFF374151), _setScheme),
        ]),
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  final String currentLocation;
  final Color red;
  const _SideRail({required this.currentLocation, required this.red});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final items = AppRouter.getNavigationItems(auth.currentUser?.role ?? UserRole.admin);
    return Container(
      width: 64,
      color: red,
      child: Column(children: [
        const SizedBox(height: 8),
        Tooltip(
          message: 'Tycoon POS',
          child: InkWell(
            onTap: () => context.go(AppRouter.dashboard),
            child: const SizedBox(width: 52, height: 52, child: Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 30)),
          ),
        ),
        Divider(height: 1, color: Colors.white.withValues(alpha: .28)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: items.length,
            itemBuilder: (_, index) {
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
                      child: SizedBox(height: 43, child: Center(child: Icon(item.icon, size: 20, color: Colors.white))),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Divider(height: 1, color: Colors.white.withValues(alpha: .28)),
        const SizedBox(height: 8),
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white.withValues(alpha: .20),
          child: Text((auth.currentUser?.name ?? 'U').substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
        const SizedBox(height: 4),
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
        const SizedBox(height: 4),
      ]),
    );
  }
}

class _TopBar extends StatefulWidget {
  final String currentLocation;
  final Color accent;
  final VoidCallback onChooseColor;
  const _TopBar({required this.currentLocation, required this.accent, required this.onChooseColor});
  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(double by) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + by).clamp(0.0, _scroll.position.maxScrollExtent).toDouble();
    _scroll.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final title = _pageTitle(widget.currentLocation);
    final actions = _actions(user?.role ?? UserRole.user);
    final onDashboard = widget.currentLocation == AppRouter.dashboard;

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(children: [
        SizedBox(
          width: 210,
          child: Row(children: [
            if (!onDashboard)
              IconButton(tooltip: 'Back', onPressed: () => context.canPop() ? context.pop() : context.go(AppRouter.dashboard), icon: const Icon(Icons.arrow_back_rounded, size: 19)),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  InkWell(onTap: () => context.go(AppRouter.dashboard), child: const Text('Home', style: TextStyle(color: Color(0xFF64748B), fontSize: 10))),
                  if (!onDashboard) ...[
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Icon(Icons.chevron_right_rounded, size: 13, color: Color(0xFF94A3B8))),
                    Expanded(child: Text(title, overflow: TextOverflow.ellipsis, style: TextStyle(color: widget.accent, fontSize: 10, fontWeight: FontWeight.w700))),
                  ],
                ]),
                const SizedBox(height: 3),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.w800)),
              ]),
            ),
          ]),
        ),
        Container(width: 1, height: 34, color: const Color(0xFFE2E8F0)),
        IconButton(tooltip: 'Previous menu items', onPressed: () => _move(-360), icon: const Icon(Icons.chevron_left_rounded, size: 21, color: Color(0xFF475569))),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: Row(children: actions.map((a) {
              final selected = a.route == AppRouter.dashboard ? widget.currentLocation == a.route : widget.currentLocation.startsWith(a.route);
              return Padding(
                padding: const EdgeInsets.only(right: 7),
                child: Tooltip(
                  message: '${a.label} [${a.shortcut}]',
                  child: Material(
                    color: selected ? widget.accent.withValues(alpha: .08) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => context.go(a.route),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 39,
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: selected ? widget.accent : const Color(0xFFE2E8F0))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(a.icon, size: 16, color: selected ? widget.accent : const Color(0xFF334155)),
                          const SizedBox(width: 6),
                          Text(a.label, style: TextStyle(fontSize: 10.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? widget.accent : const Color(0xFF1E293B))),
                        ]),
                      ),
                    ),
                  ),
                ),
              );
            }).toList()),
          ),
        ),
        IconButton(tooltip: 'More menu items', onPressed: () => _move(360), icon: Icon(Icons.chevron_right_rounded, size: 22, color: widget.accent)),
        IconButton(tooltip: 'Interface color', onPressed: widget.onChooseColor, icon: Icon(Icons.palette_outlined, color: widget.accent, size: 19)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFFE8FFF4), borderRadius: BorderRadius.circular(18)),
          child: const Row(children: [Icon(Icons.circle, size: 7, color: Color(0xFF10B981)), SizedBox(width: 5), Text('Online', style: TextStyle(color: Color(0xFF047857), fontSize: 10.5, fontWeight: FontWeight.w700))]),
        ),
        const SizedBox(width: 4),
        _Notifications(user: user),
        const SizedBox(width: 4),
        CircleAvatar(radius: 16, backgroundColor: widget.accent.withValues(alpha: .10), child: Text((user?.name ?? 'U').substring(0, 1).toUpperCase(), style: TextStyle(color: widget.accent, fontWeight: FontWeight.w800, fontSize: 11))),
      ]),
    );
  }

  List<_Action> _actions(UserRole role) {
    if (role == UserRole.superAdmin || role == UserRole.admin) {
      return const [
        _Action('Dashboard', Icons.dashboard_outlined, AppRouter.dashboard, 'd'),
        _Action('Tables', Icons.table_restaurant_outlined, AppRouter.tables, 't'),
        _Action('Inventory', Icons.inventory_2_outlined, AppRouter.products, 'i'),
        _Action('Add Item', Icons.add_box_outlined, AppRouter.products, 'a'),
        _Action('Billing', Icons.receipt_long_outlined, AppRouter.orders, 'b'),
        _Action('Sales', Icons.point_of_sale_outlined, AppRouter.sales, 's'),
        _Action('Returns', Icons.assignment_return_outlined, AppRouter.salesReturn, 'r'),
        _Action('CRM', Icons.people_alt_outlined, AppRouter.customers, 'c'),
        _Action('Operations', Icons.settings_suggest_outlined, AppRouter.purchases, 'o'),
        _Action('Store', Icons.storefront_outlined, AppRouter.storeOut, 'm'),
        _Action('Expenses', Icons.payments_outlined, AppRouter.expenses, 'e'),
        _Action('Vendors', Icons.local_shipping_outlined, AppRouter.suppliers, 'v'),
        _Action('Recipes', Icons.menu_book_outlined, AppRouter.ingredients, 'k'),
        _Action('Branches', Icons.account_tree_outlined, AppRouter.branches, 'l'),
        _Action('PRA', Icons.verified_user_outlined, AppRouter.praSettings, 'p'),
        _Action('Users', Icons.manage_accounts_outlined, AppRouter.usersRoles, 'u'),
        _Action('Settings', Icons.settings_outlined, AppRouter.settings, 'p'),
      ];
    }
    if (role == UserRole.kitchen) {
      return const [_Action('Dashboard', Icons.dashboard_outlined, AppRouter.dashboard, 'd'), _Action('KOT', Icons.soup_kitchen_outlined, AppRouter.orders, 'b')];
    }
    if (role == UserRole.waiter) {
      return const [_Action('Dashboard', Icons.dashboard_outlined, AppRouter.dashboard, 'd'), _Action('Tables', Icons.table_restaurant_outlined, AppRouter.tables, 't'), _Action('Billing', Icons.receipt_long_outlined, AppRouter.orders, 'b')];
    }
    if (role == UserRole.accounts) {
      return const [
        _Action('Dashboard', Icons.dashboard_outlined, AppRouter.dashboard, 'd'),
        _Action('Sales', Icons.point_of_sale_outlined, AppRouter.sales, 's'),
        _Action('Expenses', Icons.payments_outlined, AppRouter.expenses, 'e'),
        _Action('Operations', Icons.settings_suggest_outlined, AppRouter.purchases, 'o'),
      ];
    }
    return AppRouter.getNavigationItems(role).map((e) => _Action(e.label, e.icon, e.route, e.label.substring(0, 1).toLowerCase())).toList();
  }

  String _pageTitle(String path) {
    if (path.startsWith('/table-order')) return 'POS';
    if (path.startsWith(AppRouter.tables)) return 'Tables';
    if (path.startsWith(AppRouter.products)) return 'Inventory';
    if (path.startsWith(AppRouter.orders)) return 'Billing / KOT';
    if (path.startsWith(AppRouter.customers)) return 'CRM';
    if (path.startsWith(AppRouter.purchases)) return 'Operations';
    if (path.startsWith(AppRouter.storeOut)) return 'Store';
    if (path.startsWith(AppRouter.expenses)) return 'Expenses';
    if (path.startsWith(AppRouter.ingredients)) return 'Kitchen Recipes';
    if (path.startsWith(AppRouter.suppliers)) return 'Vendors';
    if (path.startsWith(AppRouter.branches)) return 'Branches';
    if (path.startsWith(AppRouter.praSettings)) return 'PRA Integration';
    if (path.startsWith(AppRouter.usersRoles)) return 'Users & Roles';
    if (path.startsWith(AppRouter.settings)) return 'Preferences';
    if (path.startsWith(AppRouter.salesReturn)) return 'Returns';
    if (path.startsWith(AppRouter.sales)) return 'Sales';
    return 'Dashboard';
  }
}

class _Notifications extends StatelessWidget {
  final UserModel? user;
  const _Notifications({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();
    final ref = FirebaseFirestore.instance.collection('vendors').doc(user!.id).collection('notifications');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.orderBy('createdAt', descending: true).limit(30).snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final visible = docs.where((doc) {
          final data = doc.data();
          final target = data['targetAuthUid']?.toString();
          final roles = List<String>.from(data['targetRoles'] ?? const <String>[]);
          return (target == null || target.isEmpty || target == user!.authUid) && (roles.isEmpty || roles.contains(user!.role.name));
        }).toList();
        final unread = visible.where((doc) => !List<String>.from(doc.data()['readBy'] ?? const <String>[]).contains(user!.authUid)).length;
        return Stack(clipBehavior: Clip.none, children: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => _show(context, visible),
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF334155), size: 20),
          ),
          if (unread > 0)
            Positioned(
              right: 5,
              top: 5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 15),
                height: 15,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text(unread > 9 ? '9+' : '$unread', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
        ]);
      },
    );
  }

  Future<void> _show(BuildContext context, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(children: [const Expanded(child: Text('Notifications')), IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close_rounded))]),
        content: SizedBox(
          width: 560,
          height: 430,
          child: docs.isEmpty
              ? const Center(child: Text('No notifications.'))
              : ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final data = docs[i].data();
                    return ListTile(
                      leading: const CircleAvatar(backgroundColor: Color(0xFFF3EFFF), child: Icon(Icons.notifications_none_rounded, color: Color(0xFF6C3BFF), size: 18)),
                      title: Text((data['title'] ?? 'Notification').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text((data['message'] ?? '').toString()),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _Action {
  final String label;
  final IconData icon;
  final String route;
  final String shortcut;
  const _Action(this.label, this.icon, this.route, this.shortcut);
}

class _Scheme extends StatelessWidget {
  final String name;
  final Color color;
  final Future<void> Function(String) onTap;
  const _Scheme(this.name, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onTap(name),
        borderRadius: BorderRadius.circular(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(height: 5),
          Text(name, style: const TextStyle(fontSize: 10)),
        ]),
      );
}
