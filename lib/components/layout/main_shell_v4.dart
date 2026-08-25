import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static const _brandRed = Color(0xFFD80000);
  static const _purple = Color(0xFF6C3BFF);
  static const _ink = Color(0xFF0F172A);
  static const _line = Color(0xFFE2E8F0);
  static const _canvas = Color(0xFFF8FAFC);

  Color _accent = _purple;
  Color _navBackground = Colors.white;
  String _navPlacement = 'top';
  bool _loaded = false;
  bool _featureMinimized = false;
  bool _featureMaximized = false;
  bool _featureFavorite = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('vendors').doc(user.id).get();
      final data = snap.data() ?? <String, dynamic>{};
      final route = GoRouterState.of(context).uri.path;
      if (!mounted) return;
      setState(() {
        _accent = _colorFor((data['uiButtonColor'] ?? data['uiColorScheme'] ?? 'purple').toString());
        _navBackground = _navColorFor((data['uiNavBackground'] ?? 'white').toString());
        _navPlacement = (data['uiNavPlacement'] ?? 'top').toString();
        _featureFavorite = List<String>.from(data['favoriteFeatures'] ?? const <String>[]).contains(route);
      });
      await _ensureBillingState(user, data);
    } catch (_) {}
  }

  Color _colorFor(String name) {
    switch (name) {
      case 'burgundy': return const Color(0xFF7A1026);
      case 'red': return _brandRed;
      case 'navy': return const Color(0xFF183B66);
      case 'emerald': return const Color(0xFF087F5B);
      case 'graphite': return const Color(0xFF374151);
      default: return _purple;
    }
  }

  Color _navColorFor(String name) {
    switch (name) {
      case 'soft': return const Color(0xFFF4F7FB);
      case 'burgundy': return const Color(0xFF6F1224);
      case 'navy': return const Color(0xFF102A43);
      case 'graphite': return const Color(0xFF1F2937);
      default: return Colors.white;
    }
  }

  Future<void> _saveUi({String? placement, String? buttonColor, String? navBackground}) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    if (mounted) {
      setState(() {
        if (placement != null) _navPlacement = placement;
        if (buttonColor != null) _accent = _colorFor(buttonColor);
        if (navBackground != null) _navBackground = _navColorFor(navBackground);
      });
    }
    await FirebaseFirestore.instance.collection('vendors').doc(user.id).set({
      if (placement != null) 'uiNavPlacement': placement,
      if (buttonColor != null) 'uiButtonColor': buttonColor,
      if (navBackground != null) 'uiNavBackground': navBackground,
      'uiPreferencesUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _ensureBillingState(UserModel user, Map<String, dynamic> data) async {
    if (!user.isAdmin) return;
    final plan = (data['billingPlanId'] ?? data['subscriptionType'] ?? '').toString();
    if (plan != 'monthly') return;
    final now = DateTime.now();
    final billingStatus = (data['billingStatus'] ?? '').toString().toLowerCase();
    final dueRaw = data['nextPaymentDueAt'];
    final due = dueRaw is Timestamp ? dueRaw.toDate() : null;
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    if (now.day >= 25 && billingStatus != 'paid' && data['billingReminderMonth'] != monthKey) {
      await NotificationService().publish(
        actor: user,
        type: 'subscription_payment_due',
        title: 'Tycoon POS fee due',
        message: 'Your monthly payment window is open. Please pay before the 1st to keep all features active.',
        severity: 'warning',
        targetRoles: const ['admin', 'superAdmin'],
        metadata: {'billingMonth': monthKey},
      );
      await FirebaseFirestore.instance.collection('vendors').doc(user.id).set({
        'billingReminderMonth': monthKey,
      }, SetOptions(merge: true));
    }

    if (due != null && now.isAfter(due) && billingStatus != 'paid') {
      await FirebaseFirestore.instance.collection('vendors').doc(user.id).set({
        'accessMode': 'basic',
        'downgradedAt': FieldValue.serverTimestamp(),
        'downgradeReason': 'monthly_payment_overdue',
      }, SetOptions(merge: true));
    }
  }

  bool _editingText() {
    final c = FocusManager.instance.primaryFocus?.context;
    return c != null && (c.widget is EditableText || c.findAncestorWidgetOfExactType<EditableText>() != null);
  }

  void _go(String route) {
    if (!_editingText()) context.go(route);
  }

  Map<ShortcutActivator, VoidCallback> _bindings(UserRole role) {
    final map = <ShortcutActivator, VoidCallback>{};
    for (final action in _actionsFor(role)) {
      final key = _logicalKey(action.shortcut);
      if (key != null) map[SingleActivator(key)] = () => _go(action.route);
    }
    return map;
  }

  LogicalKeyboardKey? _logicalKey(String value) {
    switch (value.toLowerCase()) {
      case 'a': return LogicalKeyboardKey.keyA;
      case 'b': return LogicalKeyboardKey.keyB;
      case 'c': return LogicalKeyboardKey.keyC;
      case 'd': return LogicalKeyboardKey.keyD;
      case 'e': return LogicalKeyboardKey.keyE;
      case 'f': return LogicalKeyboardKey.keyF;
      case 'i': return LogicalKeyboardKey.keyI;
      case 'k': return LogicalKeyboardKey.keyK;
      case 'l': return LogicalKeyboardKey.keyL;
      case 'm': return LogicalKeyboardKey.keyM;
      case 'o': return LogicalKeyboardKey.keyO;
      case 'p': return LogicalKeyboardKey.keyP;
      case 'r': return LogicalKeyboardKey.keyR;
      case 's': return LogicalKeyboardKey.keyS;
      case 't': return LogicalKeyboardKey.keyT;
      case 'u': return LogicalKeyboardKey.keyU;
      case 'v': return LogicalKeyboardKey.keyV;
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final location = GoRouterState.of(context).uri.path;
    final actions = _actionsFor(user.role);
    final isDashboard = location == AppRouter.dashboard;

    final workspace = isDashboard
        ? ColoredBox(color: Colors.white, child: widget.child)
        : _FeatureWorkspace(
            title: _pageTitle(location),
            route: location,
            accent: _accent,
            minimized: _featureMinimized,
            maximized: _featureMaximized,
            favorite: _featureFavorite,
            onMinimize: () => setState(() => _featureMinimized = !_featureMinimized),
            onMaximize: () => setState(() => _featureMaximized = !_featureMaximized),
            onClose: () => context.go(AppRouter.dashboard),
            onFavorite: () => _toggleFavorite(user, location),
            child: widget.child,
          );

    return CallbackShortcuts(
      bindings: _bindings(user.role),
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
                _BrandRail(currentLocation: location, actions: actions, red: _brandRed),
                Expanded(
                  child: Column(children: [
                    _HeaderBar(
                      title: _pageTitle(location),
                      currentLocation: location,
                      accent: _accent,
                      user: user,
                      onUiSettings: _showUiSettings,
                    ),
                    Expanded(
                      child: _NavWorkspace(
                        placement: _navPlacement,
                        navBackground: _navBackground,
                        accent: _accent,
                        currentLocation: location,
                        actions: actions,
                        workspace: workspace,
                      ),
                    ),
                  ]),
                ),
                _UnreadNotificationRail(user: user),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(UserModel user, String route) async {
    final next = !_featureFavorite;
    setState(() => _featureFavorite = next);
    await FirebaseFirestore.instance.collection('vendors').doc(user.id).set({
      'favoriteFeatures': next ? FieldValue.arrayUnion([route]) : FieldValue.arrayRemove([route]),
      'uiPreferencesUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _showUiSettings() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Interface & navigation'),
        content: SizedBox(
          width: 560,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Navigation position', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _ChoiceChip('Top / sticky', _navPlacement == 'top', () => _saveUi(placement: 'top')),
              _ChoiceChip('Bottom', _navPlacement == 'bottom', () => _saveUi(placement: 'bottom')),
              _ChoiceChip('Left / vertical', _navPlacement == 'left', () => _saveUi(placement: 'left')),
              _ChoiceChip('Right / vertical', _navPlacement == 'right', () => _saveUi(placement: 'right')),
            ]),
            const SizedBox(height: 18),
            const Text('Button color', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 10, children: [
              _ColorDot('purple', _purple, _saveUi),
              _ColorDot('burgundy', const Color(0xFF7A1026), _saveUi),
              _ColorDot('red', _brandRed, _saveUi),
              _ColorDot('navy', const Color(0xFF183B66), _saveUi),
              _ColorDot('emerald', const Color(0xFF087F5B), _saveUi),
              _ColorDot('graphite', const Color(0xFF374151), _saveUi),
            ]),
            const SizedBox(height: 18),
            const Text('Navigation background', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _ChoiceChip('White', _navBackground == Colors.white, () => _saveUi(navBackground: 'white')),
              _ChoiceChip('Soft', _navBackground == const Color(0xFFF4F7FB), () => _saveUi(navBackground: 'soft')),
              _ChoiceChip('Burgundy', _navBackground == const Color(0xFF6F1224), () => _saveUi(navBackground: 'burgundy')),
              _ChoiceChip('Navy', _navBackground == const Color(0xFF102A43), () => _saveUi(navBackground: 'navy')),
              _ChoiceChip('Graphite', _navBackground == const Color(0xFF1F2937), () => _saveUi(navBackground: 'graphite')),
            ]),
            const SizedBox(height: 14),
            const Text('Changes are saved automatically for this restaurant.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done'))],
      ),
    );
  }
}

class _NavWorkspace extends StatelessWidget {
  final String placement;
  final Color navBackground;
  final Color accent;
  final String currentLocation;
  final List<_Action> actions;
  final Widget workspace;
  const _NavWorkspace({required this.placement, required this.navBackground, required this.accent, required this.currentLocation, required this.actions, required this.workspace});

  @override
  Widget build(BuildContext context) {
    if (placement == 'left' || placement == 'right') {
      final nav = _VerticalActionBar(actions: actions, currentLocation: currentLocation, accent: accent, background: navBackground);
      return Row(children: [
        if (placement == 'left') nav,
        Expanded(child: workspace),
        if (placement == 'right') nav,
      ]);
    }
    final nav = _HorizontalActionBar(actions: actions, currentLocation: currentLocation, accent: accent, background: navBackground);
    return Column(children: [
      if (placement != 'bottom') nav,
      Expanded(child: workspace),
      if (placement == 'bottom') nav,
    ]);
  }
}

class _HeaderBar extends StatelessWidget {
  final String title;
  final String currentLocation;
  final Color accent;
  final UserModel user;
  final VoidCallback onUiSettings;
  const _HeaderBar({required this.title, required this.currentLocation, required this.accent, required this.user, required this.onUiSettings});

  @override
  Widget build(BuildContext context) {
    final onDashboard = currentLocation == AppRouter.dashboard;
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: _MainShellState._line))),
      child: Row(children: [
        if (!onDashboard)
          IconButton(
            tooltip: 'Back',
            onPressed: () => context.canPop() ? context.pop() : context.go(AppRouter.dashboard),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('TYCOON POS', style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: Color(0xFFD80000))),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _MainShellState._ink)),
        ]),
        const Spacer(),
        _ServerAndBillingMenu(user: user, accent: accent),
        IconButton(tooltip: 'Interface settings', onPressed: onUiSettings, icon: Icon(Icons.tune_rounded, color: accent, size: 20)),
        _PresenceToggle(user: user),
        const SizedBox(width: 2),
        _NotificationsButton(user: user),
        const SizedBox(width: 2),
        _ProfileMenu(user: user, accent: accent),
      ]),
    );
  }
}

class _BrandRail extends StatelessWidget {
  final String currentLocation;
  final List<_Action> actions;
  final Color red;
  const _BrandRail({required this.currentLocation, required this.actions, required this.red});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final railActions = actions.take(11).toList();
    return Container(
      width: 72,
      color: red,
      child: Column(children: [
        const SizedBox(height: 7),
        Tooltip(
          message: 'Tycoon POS',
          child: InkWell(
            onTap: () => context.go(AppRouter.dashboard),
            child: Container(
              width: 54,
              height: 54,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/logo.jpeg', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.shield_rounded, color: Color(0xFFD80000), size: 30)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Divider(height: 1, color: Colors.white.withValues(alpha: .28)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            itemCount: railActions.length,
            itemBuilder: (_, i) {
              final item = railActions[i];
              final selected = item.route == AppRouter.dashboard ? currentLocation == item.route : currentLocation.startsWith(item.route);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Tooltip(
                  message: '${item.label} • shortcut ${item.shortcut}',
                  child: Material(
                    color: selected ? Colors.white.withValues(alpha: .22) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => context.go(item.route),
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 46,
                        child: Stack(alignment: Alignment.center, children: [
                          Icon(item.icon, size: 21, color: Colors.white),
                          Positioned(
                            right: 3,
                            bottom: 3,
                            child: Container(
                              width: 15,
                              height: 15,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                              child: Text(item.shortcut, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: red)),
                            ),
                          ),
                        ]),
                      ),
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
          child: Text((user?.name ?? 'U').substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
        ),
        const SizedBox(height: 9),
      ]),
    );
  }
}

class _HorizontalActionBar extends StatefulWidget {
  final List<_Action> actions;
  final String currentLocation;
  final Color accent;
  final Color background;
  const _HorizontalActionBar({required this.actions, required this.currentLocation, required this.accent, required this.background});

  @override
  State<_HorizontalActionBar> createState() => _HorizontalActionBarState();
}

class _HorizontalActionBarState extends State<_HorizontalActionBar> {
  final _scroll = ScrollController();
  @override
  void dispose() { _scroll.dispose(); super.dispose(); }
  void _move(double by) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + by).clamp(0.0, _scroll.position.maxScrollExtent).toDouble();
    _scroll.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.background.computeLuminance() < .45;
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: widget.background, border: const Border(bottom: BorderSide(color: _MainShellState._line))),
      child: Row(children: [
        IconButton(tooltip: 'Previous', onPressed: () => _move(-420), icon: Icon(Icons.chevron_left_rounded, color: dark ? Colors.white : const Color(0xFF475569))),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: Row(children: widget.actions.map((a) => _ActionButton(action: a, currentLocation: widget.currentLocation, accent: widget.accent, darkBackground: dark)).toList()),
          ),
        ),
        IconButton(tooltip: 'More', onPressed: () => _move(420), icon: Icon(Icons.chevron_right_rounded, color: widget.accent)),
      ]),
    );
  }
}

class _VerticalActionBar extends StatelessWidget {
  final List<_Action> actions;
  final String currentLocation;
  final Color accent;
  final Color background;
  const _VerticalActionBar({required this.actions, required this.currentLocation, required this.accent, required this.background});

  @override
  Widget build(BuildContext context) {
    final dark = background.computeLuminance() < .45;
    return Container(
      width: 172,
      color: background,
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: actions.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _ActionButton(action: a, currentLocation: currentLocation, accent: accent, darkBackground: dark, vertical: true),
        )).toList(),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final _Action action;
  final String currentLocation;
  final Color accent;
  final bool darkBackground;
  final bool vertical;
  const _ActionButton({required this.action, required this.currentLocation, required this.accent, required this.darkBackground, this.vertical = false});

  @override
  Widget build(BuildContext context) {
    final selected = action.route == AppRouter.dashboard ? currentLocation == action.route : currentLocation.startsWith(action.route);
    final idle = darkBackground ? Colors.white : const Color(0xFF334155);
    return Padding(
      padding: EdgeInsets.only(right: vertical ? 0 : 7),
      child: Tooltip(
        message: '${action.label} — press ${action.shortcut}',
        child: Material(
          color: selected ? accent.withValues(alpha: darkBackground ? .32 : .10) : (darkBackground ? Colors.white.withValues(alpha: .06) : Colors.white),
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: () => context.go(action.route),
            borderRadius: BorderRadius.circular(9),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: selected ? accent : (darkBackground ? Colors.white24 : _MainShellState._line))),
              child: Row(mainAxisSize: vertical ? MainAxisSize.max : MainAxisSize.min, children: [
                Icon(action.icon, size: 17, color: selected ? accent : idle),
                const SizedBox(width: 7),
                Expanded(flex: vertical ? 1 : 0, child: Text(action.label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: selected ? FontWeight.w900 : FontWeight.w700, color: selected ? accent : idle))),
                const SizedBox(width: 7),
                Container(
                  width: 21,
                  height: 21,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: selected ? accent.withValues(alpha: .14) : (darkBackground ? Colors.white12 : const Color(0xFFF1F5F9)), borderRadius: BorderRadius.circular(6)),
                  child: Text(action.shortcut, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: selected ? accent : idle)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureWorkspace extends StatelessWidget {
  final String title;
  final String route;
  final Color accent;
  final bool minimized;
  final bool maximized;
  final bool favorite;
  final VoidCallback onMinimize;
  final VoidCallback onMaximize;
  final VoidCallback onClose;
  final VoidCallback onFavorite;
  final Widget child;
  const _FeatureWorkspace({required this.title, required this.route, required this.accent, required this.minimized, required this.maximized, required this.favorite, required this.onMinimize, required this.onMaximize, required this.onClose, required this.onFavorite, required this.child});

  @override
  Widget build(BuildContext context) {
    final body = Container(
      margin: EdgeInsets.all(maximized ? 0 : 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(maximized ? 0 : 14), border: Border.all(color: _MainShellState._line), boxShadow: maximized ? null : const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 14, offset: Offset(0, 4))]),
      child: Column(children: [
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _MainShellState._line))),
          child: Row(children: [
            Icon(Icons.widgets_outlined, size: 18, color: accent),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            const Spacer(),
            IconButton(tooltip: favorite ? 'Remove favorite' : 'Favorite widget', visualDensity: VisualDensity.compact, onPressed: onFavorite, icon: Icon(favorite ? Icons.star_rounded : Icons.star_border_rounded, size: 19, color: favorite ? const Color(0xFFF59E0B) : const Color(0xFF64748B))),
            IconButton(tooltip: minimized ? 'Restore' : 'Minimize', visualDensity: VisualDensity.compact, onPressed: onMinimize, icon: Icon(minimized ? Icons.add_rounded : Icons.remove_rounded, size: 19)),
            IconButton(tooltip: maximized ? 'Restore size' : 'Maximize', visualDensity: VisualDensity.compact, onPressed: onMaximize, icon: Icon(maximized ? Icons.fullscreen_exit_rounded : Icons.open_in_full_rounded, size: 18)),
            IconButton(tooltip: 'Close to dashboard', visualDensity: VisualDensity.compact, onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 18)),
          ]),
        ),
        if (!minimized) Expanded(child: ClipRRect(borderRadius: BorderRadius.vertical(bottom: Radius.circular(maximized ? 0 : 14)), child: child)),
      ]),
    );
    if (minimized) return Align(alignment: Alignment.topLeft, child: SizedBox(height: 62, child: body));
    return ColoredBox(color: _MainShellState._canvas, child: body);
  }
}

class _UnreadNotificationRail extends StatelessWidget {
  final UserModel user;
  const _UnreadNotificationRail({required this.user});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('vendors').doc(user.id).collection('notifications');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.orderBy('createdAt', descending: true).limit(40).snapshots(),
      builder: (_, snap) {
        final docs = _visibleNotifications(user, snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            .where((d) => !_read(d, user.authUid) && !_dismissed(d, user.authUid) && !_cleared(d, user.authUid))
            .take(4)
            .toList();
        if (docs.isEmpty) return const SizedBox.shrink();
        return Container(
          width: 330,
          color: const Color(0xFFF8FAFC),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Column(children: docs.map((doc) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _NotificationToast(user: user, doc: doc))).toList()),
        );
      },
    );
  }
}

class _NotificationToast extends StatelessWidget {
  final UserModel user;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _NotificationToast({required this.user, required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final title = (data['title'] ?? 'Notification').toString();
    final message = (data['message'] ?? '').toString();
    final service = NotificationService();
    return Material(
      elevation: 4,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => service.markRead(restaurantId: user.id, notificationId: doc.id, authUid: user.authUid),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(color: const Color(0xFFFFF3E6), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF59E0B))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CircleAvatar(radius: 17, backgroundColor: Color(0xFFFFE6CC), child: Icon(Icons.notifications_active_outlined, size: 18, color: Color(0xFFF97316))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900))), const Icon(Icons.done_rounded, size: 15, color: Color(0xFFF97316))]),
              const SizedBox(height: 3),
              Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, height: 1.3, color: Color(0xFF475569))),
            ])),
            IconButton(tooltip: 'Dismiss', visualDensity: VisualDensity.compact, onPressed: () => service.dismiss(restaurantId: user.id, notificationId: doc.id, authUid: user.authUid), icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8))),
          ]),
        ),
      ),
    );
  }
}

class _NotificationsButton extends StatelessWidget {
  final UserModel user;
  const _NotificationsButton({required this.user});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('vendors').doc(user.id).collection('notifications');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.orderBy('createdAt', descending: true).limit(100).snapshots(),
      builder: (_, snap) {
        final docs = _visibleNotifications(user, snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]).where((d) => !_cleared(d, user.authUid)).toList();
        final unread = docs.where((d) => !_read(d, user.authUid)).length;
        return Stack(clipBehavior: Clip.none, children: [
          IconButton(tooltip: 'Notification history', onPressed: () => _showNotificationHistory(context, user, docs), icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF334155), size: 20)),
          if (unread > 0) Positioned(right: 5, top: 4, child: Container(constraints: const BoxConstraints(minWidth: 16), height: 16, padding: const EdgeInsets.symmetric(horizontal: 3), alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(10)), child: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)))),
        ]);
      },
    );
  }
}

Future<void> _showNotificationHistory(BuildContext context, UserModel user, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
  String filter = 'all';
  final service = NotificationService();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(builder: (context, setLocal) {
      final now = DateTime.now();
      bool matches(QueryDocumentSnapshot<Map<String, dynamic>> d) {
        final read = _read(d, user.authUid);
        final raw = d.data()['createdAt'];
        final date = raw is Timestamp ? raw.toDate() : null;
        if (filter == 'unread') return !read;
        if (filter == 'read') return read;
        if (filter == 'today') return date != null && date.year == now.year && date.month == now.month && date.day == now.day;
        if (filter == 'yesterday') {
          final y = now.subtract(const Duration(days: 1));
          return date != null && date.year == y.year && date.month == y.month && date.day == y.day;
        }
        return true;
      }
      final filtered = docs.where(matches).toList();
      return AlertDialog(
        backgroundColor: Colors.white,
        title: Row(children: [
          const Expanded(child: Text('Notifications')),
          DropdownButton<String>(
            value: filter,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All')),
              DropdownMenuItem(value: 'unread', child: Text('Unread')),
              DropdownMenuItem(value: 'read', child: Text('Read')),
              DropdownMenuItem(value: 'today', child: Text('Today')),
              DropdownMenuItem(value: 'yesterday', child: Text('Yesterday')),
            ],
            onChanged: (v) { if (v != null) setLocal(() => filter = v); },
          ),
          PopupMenuButton<String>(
            tooltip: 'Clear notifications from my view',
            onSelected: (v) async {
              DateTime? start;
              DateTime? end;
              final today = DateTime(now.year, now.month, now.day);
              if (v == 'today') { start = today; end = today.add(const Duration(days: 1)); }
              if (v == 'yesterday') { start = today.subtract(const Duration(days: 1)); end = today; }
              if (v == 'date') {
                final picked = await showDatePicker(context: dialogContext, firstDate: DateTime(now.year - 2), lastDate: now, initialDate: now);
                if (picked == null) return;
                start = DateTime(picked.year, picked.month, picked.day);
                end = start.add(const Duration(days: 1));
              }
              await service.clearForUser(restaurantId: user.id, authUid: user.authUid, start: start, end: end);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'today', child: Text('Clear today')),
              PopupMenuItem(value: 'yesterday', child: Text('Clear yesterday')),
              PopupMenuItem(value: 'date', child: Text('Clear a date…')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'all', child: Text('Clear all')),
            ],
            icon: const Icon(Icons.cleaning_services_outlined, size: 20),
          ),
          IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close_rounded)),
        ]),
        content: SizedBox(
          width: 620,
          height: 470,
          child: filtered.isEmpty
              ? const Center(child: Text('No notifications in this view.'))
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 7),
                  itemBuilder: (_, i) {
                    final doc = filtered[i];
                    final data = doc.data();
                    final read = _read(doc, user.authUid);
                    return InkWell(
                      onTap: () => service.markRead(restaurantId: user.id, notificationId: doc.id, authUid: user.authUid),
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(color: read ? const Color(0xFFF8FBFF) : const Color(0xFFFFF3E6), borderRadius: BorderRadius.circular(10), border: Border.all(color: read ? const Color(0xFFBFDBFE) : const Color(0xFFF59E0B))),
                        child: Row(children: [
                          Icon(Icons.notifications_none_rounded, color: read ? const Color(0xFF2563EB) : const Color(0xFFF97316), size: 19),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text((data['title'] ?? 'Notification').toString(), style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text((data['message'] ?? '').toString(), style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))])),
                          Icon(read ? Icons.done_all_rounded : Icons.done_rounded, size: 17, color: read ? const Color(0xFF2563EB) : const Color(0xFFF97316)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      );
    }),
  );
}

class _ServerAndBillingMenu extends StatelessWidget {
  final UserModel user;
  final Color accent;
  const _ServerAndBillingMenu({required this.user, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (!user.isAdmin) return const SizedBox.shrink();
    final ref = FirebaseFirestore.instance.collection('vendors').doc(user.id);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (_, snap) {
        final data = snap.data?.data() ?? <String, dynamic>{};
        final plan = (data['billingPlanId'] ?? data['subscriptionType'] ?? 'trial').toString();
        final successful = (data['successfulReceiptCount'] ?? 0) as num;
        final rate = (data['transactionRate'] ?? 1) as num;
        final server = Map<String, dynamic>.from(data['serverMetrics'] ?? data['serverUsage'] ?? const <String, dynamic>{});
        return PopupMenuButton<String>(
          tooltip: 'Tycoon account, server & billing',
          offset: const Offset(0, 42),
          onSelected: (v) async {
            if (v == 'upgrade') context.go(AppRouter.pricing);
            if (v == 'pay') context.go(AppRouter.payment);
            if (v == 'contact') await launchUrl(Uri.parse('https://tycoon.technology'), mode: LaunchMode.externalApplication);
          },
          itemBuilder: (_) => [
            PopupMenuItem(enabled: false, child: SizedBox(width: 280, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TYCOON POS ACCOUNT', style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w900, color: Color(0xFFD80000))),
              const SizedBox(height: 8),
              Text('Package: ${_planLabel(plan)}', style: const TextStyle(fontWeight: FontWeight.w900)),
              if (plan == 'perTransaction') Text('$successful successful receipts × Rs ${rate.toStringAsFixed(rate % 1 == 0 ? 0 : 2)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              Text(server.isEmpty ? 'Server: online • detailed metrics feed not configured' : 'Server: CPU ${server['cpu'] ?? '-'} • RAM ${server['ram'] ?? '-'} • Disk ${server['disk'] ?? '-'}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
            ]))),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'pay', child: Row(children: [Icon(Icons.payments_outlined, size: 18), SizedBox(width: 10), Text('Pay Tycoon fee')])),
            const PopupMenuItem(value: 'upgrade', child: Row(children: [Icon(Icons.workspace_premium_outlined, size: 18), SizedBox(width: 10), Text('Upgrade package')])),
            const PopupMenuItem(value: 'contact', child: Row(children: [Icon(Icons.support_agent_rounded, size: 18), SizedBox(width: 10), Text('Contact Tycoon Technologies')])),
          ],
          child: Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(color: accent.withValues(alpha: .08), borderRadius: BorderRadius.circular(9), border: Border.all(color: accent.withValues(alpha: .20))),
            child: Row(children: [Icon(Icons.cloud_done_outlined, size: 17, color: accent), const SizedBox(width: 6), Text(_planLabel(plan), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: accent)), const SizedBox(width: 2), Icon(Icons.arrow_drop_down_rounded, size: 16, color: accent)]),
          ),
        );
      },
    );
  }
}

String _planLabel(String plan) {
  switch (plan) {
    case 'perTransaction': return 'Rs 1 / receipt';
    case 'monthly': return 'Monthly';
    case 'yearly': return 'Yearly';
    case 'fiveYears': return '5 Years';
    case 'lifetime': return '5 Years';
    default: return 'Trial';
  }
}

class _PresenceToggle extends StatelessWidget {
  final UserModel user;
  const _PresenceToggle({required this.user});

  Future<void> _setPresence(bool online) async {
    final ref = FirebaseFirestore.instance.collection('vendors').doc(user.id).collection('presence').doc(user.authUid);
    await ref.set({'authUid': user.authUid, 'name': user.name, 'role': user.role.name, 'branchId': user.branchId, 'branchName': user.branchName, 'online': online, 'manualOffline': !online, 'source': 'web', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    await NotificationService().publish(actor: user, type: online ? 'presence_online' : 'presence_offline', title: online ? 'Staff online' : 'Staff offline', message: '${user.name} is now ${online ? 'online' : 'offline'} at ${user.branchName}.', targetRoles: const ['admin', 'superAdmin'], metadata: {'online': online});
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('vendors').doc(user.id).collection('presence').doc(user.authUid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (_, snap) {
        final online = snap.hasData ? (snap.data!.data()?['online'] ?? true) == true : true;
        final bg = online ? const Color(0xFFE8FFF4) : const Color(0xFFF1F5F9);
        final fg = online ? const Color(0xFF047857) : const Color(0xFF64748B);
        return PopupMenuButton<bool>(
          tooltip: 'Presence status',
          onSelected: _setPresence,
          itemBuilder: (_) => const [
            PopupMenuItem(value: true, child: Row(children: [Icon(Icons.circle, size: 9, color: Color(0xFF10B981)), SizedBox(width: 9), Text('Go online')])),
            PopupMenuItem(value: false, child: Row(children: [Icon(Icons.circle_outlined, size: 13, color: Color(0xFF64748B)), SizedBox(width: 9), Text('Go offline')])),
          ],
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)), child: Row(children: [Icon(online ? Icons.circle : Icons.circle_outlined, size: 7, color: fg), const SizedBox(width: 5), Text(online ? 'Online' : 'Offline', style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.w800)), const SizedBox(width: 2), Icon(Icons.arrow_drop_down_rounded, size: 16, color: fg)])),
        );
      },
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  final UserModel user;
  final Color accent;
  const _ProfileMenu({required this.user, required this.accent});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return PopupMenuButton<String>(
      tooltip: 'Profile menu',
      offset: const Offset(0, 42),
      color: Colors.white,
      onSelected: (value) async {
        if (value == 'dashboard') context.go(AppRouter.dashboard);
        if (value == 'settings') context.go(AppRouter.settings);
        if (value == 'logout') { await auth.signOut(); if (context.mounted) context.go(AppRouter.login); }
      },
      itemBuilder: (_) => [
        PopupMenuItem(enabled: false, child: SizedBox(width: 210, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user.name, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(user.email, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))]))),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'dashboard', child: Row(children: [Icon(Icons.dashboard_outlined, size: 18), SizedBox(width: 10), Text('My Dashboard')])),
        const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings_outlined, size: 18), SizedBox(width: 10), Text('Preferences')])),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout_rounded, size: 18, color: Color(0xFFDC2626)), SizedBox(width: 10), Text('Logout', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w800))])),
      ],
      child: CircleAvatar(radius: 17, backgroundColor: accent.withValues(alpha: .10), child: Text(user.name.isEmpty ? 'U' : user.name.substring(0, 1).toUpperCase(), style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 11))),
    );
  }
}

List<QueryDocumentSnapshot<Map<String, dynamic>>> _visibleNotifications(UserModel user, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
  final isAdmin = user.role == UserRole.admin || user.role == UserRole.superAdmin;
  return docs.where((doc) {
    final data = doc.data();
    final target = data['targetAuthUid']?.toString();
    final roles = List<String>.from(data['targetRoles'] ?? const <String>[]);
    if (target != null && target.isNotEmpty) return target == user.authUid;
    if (roles.isNotEmpty) return roles.contains(user.role.name);
    return isAdmin;
  }).toList();
}

bool _read(QueryDocumentSnapshot<Map<String, dynamic>> doc, String authUid) => List<String>.from(doc.data()['readBy'] ?? const <String>[]).contains(authUid);
bool _dismissed(QueryDocumentSnapshot<Map<String, dynamic>> doc, String authUid) => List<String>.from(doc.data()['dismissedBy'] ?? const <String>[]).contains(authUid);
bool _cleared(QueryDocumentSnapshot<Map<String, dynamic>> doc, String authUid) => List<String>.from(doc.data()['clearedBy'] ?? const <String>[]).contains(authUid);

String _pageTitle(String path) {
  if (path.startsWith('/table-order')) return 'POS';
  if (path.startsWith(AppRouter.tables)) return 'Tables';
  if (path.startsWith(AppRouter.products)) return 'Inventory';
  if (path.startsWith(AppRouter.orders)) return 'Billing / KOT';
  if (path.startsWith(AppRouter.customers)) return 'CRM';
  if (path.startsWith(AppRouter.purchases)) return 'Operations';
  if (path.startsWith(AppRouter.storeOut)) return 'Materials';
  if (path.startsWith(AppRouter.expenses)) return 'Expenses';
  if (path.startsWith(AppRouter.ingredients)) return 'Kitchen Recipes';
  if (path.startsWith(AppRouter.suppliers)) return 'Vendors';
  if (path.startsWith(AppRouter.branches)) return 'Locations';
  if (path.startsWith(AppRouter.praSettings)) return 'Fiscal / PRA';
  if (path.startsWith(AppRouter.usersRoles)) return 'Users & Roles';
  if (path.startsWith(AppRouter.settings)) return 'Preferences';
  if (path.startsWith(AppRouter.salesReturn)) return 'Returns';
  if (path.startsWith(AppRouter.sales)) return 'Sales';
  return 'Dashboard';
}

List<_Action> _actionsFor(UserRole role) {
  if (role == UserRole.superAdmin || role == UserRole.admin) {
    return const [
      _Action('Dashboard', Icons.dashboard_outlined, AppRouter.dashboard, 'D'),
      _Action('Tables', Icons.table_restaurant_outlined, AppRouter.tables, 'T'),
      _Action('Inventory', Icons.inventory_2_outlined, AppRouter.products, 'I'),
      _Action('Add Item', Icons.add_box_outlined, AppRouter.products, 'A'),
      _Action('Billing', Icons.receipt_long_outlined, AppRouter.orders, 'B'),
      _Action('Sales', Icons.point_of_sale_outlined, AppRouter.sales, 'S'),
      _Action('Returns', Icons.assignment_return_outlined, AppRouter.salesReturn, 'R'),
      _Action('CRM', Icons.people_alt_outlined, AppRouter.customers, 'C'),
      _Action('Operations', Icons.settings_suggest_outlined, AppRouter.purchases, 'O'),
      _Action('Materials', Icons.storefront_outlined, AppRouter.storeOut, 'M'),
      _Action('Expenses', Icons.payments_outlined, AppRouter.expenses, 'E'),
      _Action('Vendors', Icons.local_shipping_outlined, AppRouter.suppliers, 'V'),
      _Action('Kitchen Recipes', Icons.menu_book_outlined, AppRouter.ingredients, 'K'),
      _Action('Locations', Icons.account_tree_outlined, AppRouter.branches, 'L'),
      _Action('Fiscal / PRA', Icons.verified_user_outlined, AppRouter.praSettings, 'F'),
      _Action('Users', Icons.manage_accounts_outlined, AppRouter.usersRoles, 'U'),
      _Action('Preferences', Icons.settings_outlined, AppRouter.settings, 'P'),
    ];
  }
  if (role == UserRole.kitchen) return const [_Action('Dashboard', Icons.dashboard_outlined, AppRouter.dashboard, 'D'), _Action('KOT', Icons.soup_kitchen_outlined, AppRouter.orders, 'K')];
  if (role == UserRole.waiter || role == UserRole.cashier || role == UserRole.staff) return const [_Action('Dashboard', Icons.dashboard_outlined, AppRouter.dashboard, 'D'), _Action('Tables', Icons.table_restaurant_outlined, AppRouter.tables, 'T'), _Action('Billing', Icons.receipt_long_outlined, AppRouter.orders, 'B'), _Action('CRM', Icons.people_alt_outlined, AppRouter.customers, 'C')];
  if (role == UserRole.accounts) return const [_Action('Dashboard', Icons.dashboard_outlined, AppRouter.dashboard, 'D'), _Action('Sales', Icons.point_of_sale_outlined, AppRouter.sales, 'S'), _Action('Expenses', Icons.payments_outlined, AppRouter.expenses, 'E'), _Action('Operations', Icons.settings_suggest_outlined, AppRouter.purchases, 'O')];
  return const [_Action('Dashboard', Icons.dashboard_outlined, AppRouter.dashboard, 'D')];
}

class _Action {
  final String label;
  final IconData icon;
  final String route;
  final String shortcut;
  const _Action(this.label, this.icon, this.route, this.shortcut);
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceChip(this.label, this.selected, this.onTap);
  @override
  Widget build(BuildContext context) => ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
}

class _ColorDot extends StatelessWidget {
  final String name;
  final Color color;
  final Future<void> Function({String? placement, String? buttonColor, String? navBackground}) save;
  const _ColorDot(this.name, this.color, this.save);
  @override
  Widget build(BuildContext context) => Tooltip(message: name, child: InkWell(onTap: () => save(buttonColor: name), borderRadius: BorderRadius.circular(30), child: Container(width: 38, height: 38, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 4)]))));
}
