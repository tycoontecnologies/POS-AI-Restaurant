import 'dart:async';

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
  static const ink = Color(0xFF101828);
  static const muted = Color(0xFF667085);
  static const line = Color(0xFFE4E7EC);
  static const soft = Color(0xFFF8FAFC);
  static const navy = Color(0xFF16233A);
  static const purple = Color(0xFF6C4CF1);
  static const burgundy = Color(0xFF7A1026);

  bool _loaded = false;
  bool _online = true;
  String _navPlacement = 'left';
  String _navBackground = 'white';
  String _buttonColor = 'purple';
  String _navDisplayMode = 'iconsNames';
  Set<String> _favorites = <String>{};

  UserModel? get _user => context.read<AuthProvider>().currentUser;
  DocumentReference<Map<String, dynamic>>? get _vendorRef {
    final user = _user;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('vendors').doc(user.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _loadPrefs();
    _ensureBillingState();
  }

  Future<void> _loadPrefs() async {
    try {
      final snap = await _vendorRef?.get();
      final data = snap?.data() ?? <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _navPlacement = (data['uiNavPlacement'] ?? 'left').toString();
        if (_navPlacement != 'left' && _navPlacement != 'right') {
          _navPlacement = 'left';
        }
        _navBackground = (data['uiNavBackground'] ?? 'white').toString();
        _buttonColor = (data['uiButtonColor'] ?? 'purple').toString();
        _navDisplayMode = (data['uiNavDisplayMode'] ?? 'iconsNames').toString();
        _favorites = Set<String>.from(
          (data['favoriteFeatures'] as List?)?.map((e) => e.toString()) ??
              const <String>[],
        );
        _online = (data['presenceOnline'] ?? true) == true;
      });
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      await _vendorRef?.set({
        'uiNavPlacement': _navPlacement,
        'uiNavBackground': _navBackground,
        'uiButtonColor': _buttonColor,
        'uiNavDisplayMode': _navDisplayMode,
        'favoriteFeatures': _favorites.toList(),
        'presenceOnline': _online,
        'uiPreferencesUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Color get _accent => switch (_buttonColor) {
    'burgundy' => burgundy,
    'red' => const Color(0xFFD92D20),
    'navy' => const Color(0xFF17365D),
    'emerald' => const Color(0xFF039855),
    'graphite' => const Color(0xFF344054),
    _ => purple,
  };

  Color get _navColor => switch (_navBackground) {
    'soft' => const Color(0xFFF7F8FA),
    'burgundy' => burgundy,
    'navy' => const Color(0xFF17365D),
    'graphite' => const Color(0xFF344054),
    _ => Colors.white,
  };

  Color get _navTextColor =>
      ['burgundy', 'navy', 'graphite'].contains(_navBackground)
      ? Colors.white
      : ink;

  String _shortcutFor(String label) {
    const map = <String, String>{
      'Dashboard': 'D',
      'Tables': 'T',
      'Billing': 'B',
      'KOT': 'K',
      'Inventory': 'I',
      'Store': 'M',
      'Expenses': 'E',
      'CRM': 'C',
      'Operations': 'O',
      'Kitchen Recipes': 'R',
      'Vendors': 'V',
      'Branches': 'N',
      'PRA': 'F',
      'Help AI': 'H',
    };
    return map[label] ?? label.substring(0, 1).toUpperCase();
  }

  Future<void> _toggleFavorite(String route) async {
    setState(() {
      _favorites.contains(route)
          ? _favorites.remove(route)
          : _favorites.add(route);
    });
    await _savePrefs();
  }

  Future<void> _setPresence(bool online) async {
    setState(() => _online = online);
    await _savePrefs();
    final user = _user;
    if (user == null) return;
    await _vendorRef?.collection('presence').doc(user.authUid).set({
      'online': online,
      'name': user.name,
      'role': user.role.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().signOut();
    if (mounted) context.go(AppRouter.login);
  }

  Future<void> _ensureBillingState() async {
    final user = _user;
    if (user == null || !user.isAdmin) return;
    try {
      final ref = FirebaseFirestore.instance.collection('vendors').doc(user.id);
      final snap = await ref.get();
      if (!snap.exists) return;
      final data = snap.data() ?? <String, dynamic>{};
      final plan = (data['billingPlanId'] ?? data['subscriptionType'] ?? '')
          .toString();
      if (plan != 'monthly' && plan != 'perTransaction') return;
      final now = DateTime.now();
      final status = (data['billingStatus'] ?? '').toString().toLowerCase();
      final usageDue = data['transactionUsageAmount'] is num
          ? (data['transactionUsageAmount'] as num).toDouble()
          : 0.0;
      final rawDue = data['nextPaymentDueAt'];
      final dueAt = rawDue is Timestamp
          ? rawDue.toDate()
          : DateTime(
              now.year,
              now.month + 1,
              1,
            ).subtract(const Duration(seconds: 1));
      if (rawDue == null) {
        await ref.set({
          'nextPaymentDueAt': Timestamp.fromDate(dueAt),
        }, SetOptions(merge: true));
      }
      final reminderKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final sent =
          (data['billingReminderMonth'] ?? '').toString() == reminderKey;
      final shouldRemind =
          now.day >= 25 &&
          !sent &&
          (plan == 'monthly' ? status != 'paid' : usageDue > 0);
      if (shouldRemind) {
        await NotificationService().publish(
          actor: user,
          type: 'billing_due',
          title: 'Tycoon POS fee due',
          message: plan == 'perTransaction'
              ? 'Current transaction usage fee: Rs ${usageDue.toStringAsFixed(0)}. Please pay by month-end.'
              : 'Your monthly Tycoon POS fee is due. Please pay by month-end.',
          targetRoles: const ['admin', 'superAdmin'],
          metadata: {
            'plan': plan,
            'amountDue': plan == 'perTransaction' ? usageDue : 7000,
          },
        );
        await ref.set({
          'billingReminderMonth': reminderKey,
          'billingReminderSentAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      final overdue =
          now.isAfter(dueAt) &&
          (plan == 'monthly' ? status != 'paid' : usageDue > 0);
      if (overdue) {
        await ref.set({
          'accessMode': 'basic',
          'billingStatus': 'overdue',
          'downgradedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final route = GoRouterState.of(context).uri.path;
    final items = AppRouter.getNavigationItems(user.role);
    NavigationItem? current;
    for (final item in items) {
      if (route == item.route ||
          (item.route != '/' && route.startsWith(item.route))) {
        current = item;
        break;
      }
    }
    final title =
        current?.label ??
        (route.startsWith('/table-order') ? 'POS' : 'Workspace');
    final vertical = _navPlacement == 'left' || _navPlacement == 'right';

    Widget center = Column(
      children: [
        _TopBar(
          user: user,
          title: title,
          accent: _accent,
          online: _online,
          onPresence: _setPresence,
          onInterfaceSettings: _showInterfaceSettings,
          onBilling: () => _showBillingMenu(user),
          onNotifications: () => _showNotificationHistory(user),
          onSettings: () => context.go(AppRouter.settings),
          onProfile: () => context.go(AppRouter.profileSettings),
          onLogout: _logout,
          onAddWidget: () => context.go('${AppRouter.dashboard}?customize=1'),
          onSearch: () => _showCommandSearch(items),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child:
                    route == AppRouter.dashboard ||
                        route.startsWith('/table-order')
                    ? widget.child
                    : _FeatureWorkspace(
                        title: title,
                        accent: _accent,
                        favorite:
                            current != null &&
                            _favorites.contains(current.route),
                        onFavorite: current == null
                            ? null
                            : () => _toggleFavorite(current!.route),
                        child: widget.child,
                      ),
              ),
              if (user.isAdmin)
                Positioned(
                  top: 12,
                  right: 12,
                  child: _UnreadNotificationRail(user: user),
                ),
            ],
          ),
        ),
      ],
    );

    if (vertical) {
      final rail = _VerticalNav(
        items: items,
        currentRoute: route,
        accent: _accent,
        background: _navColor,
        textColor: _navTextColor,
        favorites: _favorites,
        shortcutFor: _shortcutFor,
        displayMode: _navDisplayMode,
        onFavorite: _toggleFavorite,
      );
      center = Row(
        children: _navPlacement == 'left'
            ? [rail, Expanded(child: center)]
            : [Expanded(child: center), rail],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isAltPressed ||
              HardwareKeyboard.instance.isMetaPressed) {
            return KeyEventResult.ignored;
          }
          if (FocusManager.instance.primaryFocus?.context?.widget
              is EditableText) {
            return KeyEventResult.ignored;
          }
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
        child: Row(
          children: [
            if (!vertical)
              _BrandRail(
                user: user,
                items: items,
                currentRoute: route,
                shortcutFor: _shortcutFor,
              ),
            Expanded(child: center),
          ],
        ),
      ),
    );
  }

  Future<void> _showCommandSearch(List<NavigationItem> items) async {
    final result = await showSearch<NavigationItem?>(
      context: context,
      delegate: _NavigationSearch(items),
    );
    if (result != null && mounted) context.go(result.route);
  }

  Future<void> _showInterfaceSettings() async {
    String placement = _navPlacement;
    String background = _navBackground;
    String button = _buttonColor;
    String displayMode = _navDisplayMode;
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setModal) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Interface & Navigation'),
          content: SizedBox(
            width: 540,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Navigation position',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      const [
                            ('left', 'Left Vertical'),
                            ('right', 'Right Vertical'),
                          ]
                          .map(
                            (entry) => ChoiceChip(
                              label: Text(entry.$2),
                              selected: placement == entry.$1,
                              onSelected: (_) =>
                                  setModal(() => placement = entry.$1),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Navigation content',

                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),

                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,

                  runSpacing: 8,

                  children:
                      [
                            ('iconsOnly', 'Icons Only'),

                            ('iconsNames', 'Icons + Names'),

                            ('iconsKeys', 'Icons + Short Keys'),

                            ('full', 'Names + Icons + Short Keys'),
                          ]
                          .map(
                            (entry) => ChoiceChip(
                              label: Text(entry.$2),

                              selected: displayMode == entry.$1,

                              onSelected: (_) =>
                                  setModal(() => displayMode = entry.$1),
                            ),
                          )
                          .toList(),
                ),

                const SizedBox(height: 18),

                const Text(
                  'Navigation background',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['white', 'soft', 'burgundy', 'navy', 'graphite']
                      .map(
                        (value) => ChoiceChip(
                          label: Text(
                            value[0].toUpperCase() + value.substring(1),
                          ),
                          selected: background == value,
                          onSelected: (_) => setModal(() => background = value),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Accent color',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                            'purple',
                            'burgundy',
                            'red',
                            'navy',
                            'emerald',
                            'graphite',
                          ]
                          .map(
                            (value) => ChoiceChip(
                              label: Text(
                                value[0].toUpperCase() + value.substring(1),
                              ),
                              selected: button == value,
                              onSelected: (_) => setModal(() => button = value),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, [
                placement,
                background,
                button,
                displayMode,
              ]),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _navPlacement = result[0];
      _navBackground = result[1];
      _buttonColor = result[2];
      _navDisplayMode = result[3];
    });
    await _savePrefs();
  }

  Future<void> _showBillingMenu(UserModel user) async {
    final snap = await FirebaseFirestore.instance
        .collection('vendors')
        .doc(user.id)
        .get();
    if (!mounted) return;
    final data = snap.data() ?? <String, dynamic>{};
    final plan = (data['billingPlanId'] ?? data['subscriptionType'] ?? 'trial')
        .toString();
    final success = data['successfulReceiptCount'] is num
        ? (data['successfulReceiptCount'] as num).toInt()
        : 0;
    final unbilled = data['unbilledReceiptCount'] is num
        ? (data['unbilledReceiptCount'] as num).toInt()
        : 0;
    final rate = data['transactionRate'] is num
        ? (data['transactionRate'] as num).toDouble()
        : 1.0;
    final usage = data['transactionUsageAmount'] is num
        ? (data['transactionUsageAmount'] as num).toDouble()
        : 0.0;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Tycoon Account & Billing'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Package', _planLabel(plan)),
              if (plan == 'perTransaction') ...[
                _infoRow(
                  'Successful receipts',
                  '$success lifetime • $unbilled current',
                ),
                _infoRow(
                  'Usage rate',
                  'Rs ${rate.toStringAsFixed(rate % 1 == 0 ? 0 : 2)} / receipt',
                ),
                _infoRow(
                  'Current amount due',
                  'Rs ${usage.toStringAsFixed(0)}',
                ),
              ],
              const Divider(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      context.go(AppRouter.pricing);
                    },
                    icon: const Icon(
                      Icons.workspace_premium_outlined,
                      size: 17,
                    ),
                    label: const Text('Upgrade Package'),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      context.go(
                        '${AppRouter.payment}/${plan == 'trial' ? 'monthly' : plan}',
                      );
                    },
                    icon: const Icon(Icons.payments_outlined, size: 17),
                    label: const Text('Pay Tycoon Fee'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse('https://tycoon.technology');
                      if (await canLaunchUrl(uri))
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                    },
                    icon: const Icon(Icons.support_agent_rounded, size: 17),
                    label: const Text('Contact Tycoon'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(
          width: 145,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
          ),
        ),
      ],
    ),
  );

  String _planLabel(String plan) => switch (plan) {
    'perTransaction' => 'Rs 1 / successful receipt',
    'monthly' => 'Monthly • Rs 7,000',
    'yearly' => 'Yearly • Rs 80,000',
    'fiveYears' => '5 Years • Rs 200,000',
    _ => '3-day Trial',
  };

  Future<void> _showNotificationHistory(UserModel user) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _NotificationHistoryDialog(user: user),
    );
  }
}

class _TopBar extends StatelessWidget {
  final UserModel user;
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

  @override
  Widget build(BuildContext context) {
    final restaurant = user.restaurantName.isEmpty
        ? 'Restaurant'
        : user.restaurantName;
    final initials = user.name.trim().isEmpty
        ? 'U'
        : user.name.trim().substring(0, 1).toUpperCase();
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _MainShellState.line)),
      ),
      child: Row(
        children: [
          _RestaurantLogo(user: user, size: 48),
          const SizedBox(width: 10),
          SizedBox(
            width: 250,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        restaurant,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: _MainShellState.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${user.branchName} • $title',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: _MainShellState.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: InkWell(
              onTap: onSearch,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 44,
                constraints: const BoxConstraints(maxWidth: 470),
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _MainShellState.line),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: _MainShellState.muted,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Search anything…',
                        style: TextStyle(
                          fontSize: 12,
                          color: _MainShellState.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onAddWidget,
            icon: Icon(Icons.add_rounded, color: accent, size: 18),
            label: Text(
              'Add Widget',
              style: TextStyle(color: accent, fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: accent.withValues(alpha: .45)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<bool>(
            tooltip: 'Presence',
            onSelected: onPresence,
            itemBuilder: (_) => const [
              PopupMenuItem(value: true, child: Text('Go Online')),
              PopupMenuItem(value: false, child: Text('Go Offline')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: online ? const Color(0xFFECFDF3) : _MainShellState.soft,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 7,
                    color: online
                        ? const Color(0xFF12B76A)
                        : _MainShellState.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    online ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: online
                          ? const Color(0xFF027A48)
                          : _MainShellState.muted,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Packages, fees & usage',
            onPressed: onBilling,
            icon: Icon(Icons.account_balance_wallet_outlined, color: accent),
          ),
          _NotificationButton(user: user, onTap: onNotifications),
          IconButton(
            tooltip: 'Interface',
            onPressed: onInterfaceSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Profile',
            onSelected: (value) {
              if (value == 'profile') onProfile();
              if (value == 'settings') onSettings();
              if (value == 'logout') onLogout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('My Profile'),
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout_rounded),
                  title: Text('Logout'),
                ),
              ),
            ],
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFF2F4F7),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _MainShellState.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 95),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name.isEmpty ? 'User' : user.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        user.role.name,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: _MainShellState.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 17),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantLogo extends StatelessWidget {
  final UserModel user;
  final double size;
  const _RestaurantLogo({required this.user, required this.size});
  @override
  Widget build(BuildContext context) {
    final url = user.restaurantLogoUrl ?? '';
    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.storefront_rounded,
          color: _MainShellState.navy,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: const Color(0xFFF2F4F7),
          child: const Icon(Icons.storefront_rounded),
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  const _NotificationButton({required this.user, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('vendors')
        .doc(user.id)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (_, snapshot) {
        final count =
            (snapshot.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .where((doc) {
                  final d = doc.data();
                  final cleared = List<String>.from(
                    d['clearedBy'] ?? const <String>[],
                  ).contains(user.authUid);
                  final read = List<String>.from(
                    d['readBy'] ?? const <String>[],
                  ).contains(user.authUid);
                  return !cleared && !read && _visibleFor(user, d);
                })
                .length;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Notifications',
              onPressed: onTap,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            if (count > 0)
              Positioned(
                right: 5,
                top: 4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 17),
                  height: 17,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD92D20),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _KeyHint extends StatelessWidget {
  final String value;
  const _KeyHint(this.value);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: _MainShellState.line),
    ),
    child: Text(
      value,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: _MainShellState.muted,
      ),
    ),
  );
}

class _BrandRail extends StatelessWidget {
  final UserModel user;
  final List<NavigationItem> items;
  final String currentRoute;
  final String Function(String) shortcutFor;
  const _BrandRail({
    required this.user,
    required this.items,
    required this.currentRoute,
    required this.shortcutFor,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: 74,
    color: _MainShellState.navy,
    child: Column(
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: _RestaurantLogo(user: user, size: 54),
        ),
        const SizedBox(height: 9),
        Container(width: 22, height: 1, color: Colors.white24),
        const SizedBox(height: 5),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 3),
            children: items.map((item) {
              final selected =
                  currentRoute == item.route ||
                  (item.route != '/' && currentRoute.startsWith(item.route));
              return Tooltip(
                message: '${item.label} • ${shortcutFor(item.label)}',
                child: InkWell(
                  onTap: () => context.go(item.route),
                  child: Container(
                    height: 52,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? _MainShellState.purple
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            item.icon,
                            color: selected
                                ? Colors.white
                                : const Color(0xFFD0D5DD),
                            size: 21,
                          ),
                        ),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Text(
                            shortcutFor(item.label),
                            style: TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF98A2B3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 12),
          child: Column(
            children: [
              const TycoonPosLogo(width: 42, height: 42),
              const SizedBox(height: 4),
              Text(
                'Powered by',
                style: TextStyle(
                  fontSize: 7.5,
                  color: Colors.white.withValues(alpha: .55),
                ),
              ),
              const Text(
                'TYCOON',
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SmartNavBar extends StatefulWidget {
  final List<NavigationItem> items;
  final String currentRoute;
  final Color accent, background, textColor;
  final Set<String> favorites;
  final String Function(String) shortcutFor;
  final ValueChanged<String> onFavorite;
  const _SmartNavBar({
    required this.items,
    required this.currentRoute,
    required this.accent,
    required this.background,
    required this.textColor,
    required this.favorites,
    required this.shortcutFor,
    required this.onFavorite,
  });
  @override
  State<_SmartNavBar> createState() => _SmartNavBarState();
}

class _SmartNavBarState extends State<_SmartNavBar> {
  final ScrollController _controller = ScrollController();
  Timer? _timer;
  double _velocity = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _hover(PointerHoverEvent event, double width) {
    const edge = 130.0;
    final x = event.localPosition.dx;
    if (x < edge) {
      _velocity = -((edge - x) / edge) * 12;
    } else if (x > width - edge) {
      _velocity = ((x - (width - edge)) / edge) * 12;
    } else {
      _velocity = 0;
    }
    _timer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_controller.hasClients || _velocity == 0) return;
      final max = _controller.position.maxScrollExtent;
      final next = (_controller.offset + _velocity).clamp(0.0, max);
      _controller.jumpTo(next);
    });
  }

  void _stop() {
    _velocity = 0;
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.items]
      ..sort(
        (a, b) => (widget.favorites.contains(b.route) ? 1 : 0).compareTo(
          widget.favorites.contains(a.route) ? 1 : 0,
        ),
      );
    return LayoutBuilder(
      builder: (_, constraints) => MouseRegion(
        onHover: (e) => _hover(e, constraints.maxWidth),
        onExit: (_) => _stop(),
        child: Container(
          height: 72,
          color: widget.background,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: ScrollConfiguration(
            behavior: const _NoScrollbarBehavior(),
            child: ListView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              children: sorted.map((item) {
                final active =
                    widget.currentRoute == item.route ||
                    (item.route != '/' &&
                        widget.currentRoute.startsWith(item.route));
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => context.go(item.route),
                    onLongPress: () => widget.onFavorite(item.route),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: active
                            ? widget.accent.withValues(alpha: .09)
                            : widget.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active
                              ? widget.accent.withValues(alpha: .65)
                              : widget.textColor.withValues(alpha: .12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 17,
                            color: active ? widget.accent : widget.textColor,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                              color: active ? widget.accent : widget.textColor,
                            ),
                          ),
                          const SizedBox(width: 7),
                          _KeyHint(widget.shortcutFor(item.label)),
                          if (widget.favorites.contains(item.route)) ...[
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFF79009),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

class _VerticalNav extends StatelessWidget {
  final List<NavigationItem> items;
  final String currentRoute;
  final Color accent, background, textColor;
  final Set<String> favorites;
  final String Function(String) shortcutFor;
  final ValueChanged<String> onFavorite;
  final String displayMode;
  const _VerticalNav({
    required this.items,
    required this.currentRoute,
    required this.accent,
    required this.background,
    required this.textColor,
    required this.favorites,
    required this.shortcutFor,
    required this.onFavorite,
    required this.displayMode,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: displayMode == 'iconsOnly'
        ? 76
        : displayMode == 'iconsKeys'
        ? 135
        : displayMode == 'full'
        ? 260
        : 215,
    color: background,
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
    child: ListView(
      children: items.map((item) {
        final active =
            currentRoute == item.route ||
            (item.route != '/' && currentRoute.startsWith(item.route));
        return ListTile(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          selected: active,
          selectedTileColor: accent.withValues(alpha: .09),
          leading: Icon(
            item.icon,
            size: 18,
            color: active ? accent : textColor,
          ),
          title: displayMode == 'iconsOnly'
              ? null
              : displayMode == 'iconsKeys'
              ? _KeyHint(shortcutFor(item.label))
              : Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: active ? accent : textColor,
                  ),
                ),
          trailing: displayMode == 'full'
              ? _KeyHint(shortcutFor(item.label))
              : null,
          onTap: () => context.go(item.route),
          onLongPress: () => onFavorite(item.route),
        );
      }).toList(),
    ),
  );
}

class _FeatureWorkspace extends StatefulWidget {
  final String title;
  final Color accent;
  final bool favorite;
  final VoidCallback? onFavorite;
  final Widget child;
  const _FeatureWorkspace({
    required this.title,
    required this.accent,
    required this.favorite,
    required this.onFavorite,
    required this.child,
  });
  @override
  State<_FeatureWorkspace> createState() => _FeatureWorkspaceState();
}

class _FeatureWorkspaceState extends State<_FeatureWorkspace> {
  bool minimized = false;
  bool maximized = false;
  @override
  Widget build(BuildContext context) {
    if (minimized) {
      return Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: OutlinedButton.icon(
            onPressed: () => setState(() => minimized = false),
            icon: const Icon(Icons.open_in_full_rounded),
            label: Text('Restore ${widget.title}'),
          ),
        ),
      );
    }
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: EdgeInsets.all(maximized ? 0 : 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(maximized ? 0 : 14),
          border: maximized ? null : Border.all(color: _MainShellState.line),
          boxShadow: maximized
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x0A101828),
                    blurRadius: 16,
                    offset: Offset(0, 5),
                  ),
                ],
        ),
        child: Column(
          children: [
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _MainShellState.line)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go(AppRouter.dashboard);
                      }
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 19),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: widget.favorite ? 'Remove favorite' : 'Favorite',
                    onPressed: widget.onFavorite,
                    icon: Icon(
                      widget.favorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 18,
                      color: widget.favorite
                          ? const Color(0xFFF79009)
                          : _MainShellState.muted,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Minimize',
                    onPressed: () => setState(() => minimized = true),
                    icon: const Icon(Icons.remove_rounded, size: 18),
                  ),
                  IconButton(
                    tooltip: maximized ? 'Restore size' : 'Maximize',
                    onPressed: () => setState(() => maximized = !maximized),
                    icon: Icon(
                      maximized
                          ? Icons.close_fullscreen_rounded
                          : Icons.open_in_full_rounded,
                      size: 17,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Dashboard',
                    onPressed: () => context.go(AppRouter.dashboard),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}

class _UnreadNotificationRail extends StatelessWidget {
  final UserModel user;
  const _UnreadNotificationRail({required this.user});
  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('vendors')
        .doc(user.id)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(20);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (_, snapshot) {
        final docs =
            (snapshot.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .where((doc) {
                  final data = doc.data();
                  final cleared = List<String>.from(
                    data['clearedBy'] ?? const <String>[],
                  ).contains(user.authUid);
                  final read = List<String>.from(
                    data['readBy'] ?? const <String>[],
                  ).contains(user.authUid);
                  return !cleared && !read && _visibleFor(user, data);
                })
                .take(4)
                .toList();
        if (docs.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          width: 355,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: docs
                .map(
                  (doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _NotificationToast(user: user, doc: doc),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _NotificationToast extends StatelessWidget {
  final UserModel user;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _NotificationToast({required this.user, required this.doc});
  Future<void> _read() => NotificationService().markRead(
    restaurantId: user.id,
    notificationId: doc.id,
    authUid: user.authUid,
  );
  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _read,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4E5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF79009)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x16000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                color: Color(0xFFF79009),
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (data['title'] ?? 'Notification').toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (data['message'] ?? '').toString(),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: _MainShellState.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Mark read & hide',
                onPressed: _read,
                icon: const Icon(
                  Icons.done_rounded,
                  color: Color(0xFFF79009),
                  size: 18,
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: () => NotificationService().dismiss(
                  restaurantId: user.id,
                  notificationId: doc.id,
                  authUid: user.authUid,
                ),
                icon: const Icon(Icons.close_rounded, size: 17),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationHistoryDialog extends StatefulWidget {
  final UserModel user;
  const _NotificationHistoryDialog({required this.user});
  @override
  State<_NotificationHistoryDialog> createState() =>
      _NotificationHistoryDialogState();
}

class _NotificationHistoryDialogState
    extends State<_NotificationHistoryDialog> {
  String filter = 'all';
  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('vendors')
        .doc(widget.user.id)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(250);
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 820,
        height: 680,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (_, snapshot) {
            final all =
                (snapshot.data?.docs ??
                        const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .where((doc) {
                      final data = doc.data();
                      final cleared = List<String>.from(
                        data['clearedBy'] ?? const <String>[],
                      ).contains(widget.user.authUid);
                      return !cleared && _visibleFor(widget.user, data);
                    })
                    .toList();
            final now = DateTime.now();
            final docs = all.where((doc) {
              final data = doc.data();
              final read = List<String>.from(
                data['readBy'] ?? const <String>[],
              ).contains(widget.user.authUid);
              final raw = data['createdAt'];
              final date = raw is Timestamp
                  ? raw.toDate()
                  : DateTime.fromMillisecondsSinceEpoch(0);
              return switch (filter) {
                'unread' => !read,
                'read' => read,
                'today' => _sameDay(date, now),
                'yesterday' => _sameDay(
                  date,
                  now.subtract(const Duration(days: 1)),
                ),
                _ => true,
              };
            }).toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Notification History',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      DropdownButton<String>(
                        value: filter,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(
                            value: 'unread',
                            child: Text('Unread'),
                          ),
                          DropdownMenuItem(value: 'read', child: Text('Read')),
                          DropdownMenuItem(
                            value: 'today',
                            child: Text('Today'),
                          ),
                          DropdownMenuItem(
                            value: 'yesterday',
                            child: Text('Yesterday'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => filter = value ?? 'all'),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Clear history view',
                        onSelected: _clear,
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'today',
                            child: Text('Clear today'),
                          ),
                          PopupMenuItem(
                            value: 'yesterday',
                            child: Text('Clear yesterday'),
                          ),
                          PopupMenuItem(
                            value: 'date',
                            child: Text('Clear selected date…'),
                          ),
                          PopupMenuDivider(),
                          PopupMenuItem(value: 'all', child: Text('Clear all')),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: docs.isEmpty
                      ? const Center(
                          child: Text(
                            'No notifications in this view',
                            style: TextStyle(color: _MainShellState.muted),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final doc = docs[index];
                            final data = doc.data();
                            final read = List<String>.from(
                              data['readBy'] ?? const <String>[],
                            ).contains(widget.user.authUid);
                            return InkWell(
                              onTap: () => NotificationService().markRead(
                                restaurantId: widget.user.id,
                                notificationId: doc.id,
                                authUid: widget.user.authUid,
                              ),
                              borderRadius: BorderRadius.circular(11),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: read
                                      ? const Color(0xFFF8FAFC)
                                      : const Color(0xFFFFF4E5),
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: read
                                        ? _MainShellState.line
                                        : const Color(0xFFF79009),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      read
                                          ? Icons.done_all_rounded
                                          : Icons.done_rounded,
                                      color: read
                                          ? const Color(0xFF2E90FA)
                                          : const Color(0xFFF79009),
                                      size: 19,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (data['title'] ?? 'Notification')
                                                .toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            (data['message'] ?? '').toString(),
                                            style: const TextStyle(
                                              fontSize: 10.8,
                                              color: _MainShellState.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      read ? 'Read' : 'Unread',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: read
                                            ? const Color(0xFF2E90FA)
                                            : const Color(0xFFF79009),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _clear(String mode) async {
    DateTime? start;
    DateTime? end;
    final now = DateTime.now();
    if (mode == 'today') {
      start = DateTime(now.year, now.month, now.day);
      end = start.add(const Duration(days: 1));
    } else if (mode == 'yesterday') {
      end = DateTime(now.year, now.month, now.day);
      start = end.subtract(const Duration(days: 1));
    } else if (mode == 'date') {
      final chosen = await showDatePicker(
        context: context,
        firstDate: DateTime(now.year - 5),
        lastDate: now,
        initialDate: now,
      );
      if (chosen == null) return;
      start = DateTime(chosen.year, chosen.month, chosen.day);
      end = start.add(const Duration(days: 1));
    }
    await NotificationService().clearForUser(
      restaurantId: widget.user.id,
      authUid: widget.user.authUid,
      start: start,
      end: end,
    );
  }
}

class _NavigationSearch extends SearchDelegate<NavigationItem?> {
  final List<NavigationItem> items;
  _NavigationSearch(this.items);
  @override
  String get searchFieldLabel => 'Search features…';
  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(
      onPressed: () => query = '',
      icon: const Icon(Icons.clear_rounded),
    ),
  ];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back_rounded),
  );
  @override
  Widget buildResults(BuildContext context) => _results(context);
  @override
  Widget buildSuggestions(BuildContext context) => _results(context);
  Widget _results(BuildContext context) {
    final q = query.trim().toLowerCase();
    final result = items
        .where((e) => q.isEmpty || e.label.toLowerCase().contains(q))
        .toList();
    return ListView(
      children: result
          .map(
            (item) => ListTile(
              leading: Icon(item.icon),
              title: Text(item.label),
              onTap: () => close(context, item),
            ),
          )
          .toList(),
    );
  }
}

bool _visibleFor(UserModel user, Map<String, dynamic> data) {
  final roles = List<String>.from(data['targetRoles'] ?? const <String>[]);
  final users = List<String>.from(data['targetUserIds'] ?? const <String>[]);
  if (users.isNotEmpty &&
      !users.contains(user.authUid) &&
      !users.contains(user.id))
    return false;
  if (roles.isNotEmpty &&
      !roles.contains(user.role.name) &&
      !(user.isAdmin && roles.contains('admin')))
    return false;
  if (users.isEmpty && roles.isEmpty) return user.isAdmin;
  return true;
}
