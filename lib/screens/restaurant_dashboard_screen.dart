import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pos/models/sale.dart';
import 'package:pos/models/table.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/sale_provider.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/routes/app_router.dart';

const _purple = Color(0xFF6C3BFF);
const _line = Color(0xFFE5E7EB);
const _ink = Color(0xFF111827);
const _muted = Color(0xFF6B7280);
const _soft = Color(0xFFF9FAFB);
const _orange = Color(0xFFF59E0B);
const _orangeSoft = Color(0xFFFFF4DE);
const _blue = Color(0xFF2563EB);
const _blueSoft = Color(0xFFEFF6FF);

class RestaurantDashboardScreen extends StatefulWidget {
  const RestaurantDashboardScreen({super.key});
  @override
  State<RestaurantDashboardScreen> createState() => _RestaurantDashboardScreenState();
}

class _RestaurantDashboardScreenState extends State<RestaurantDashboardScreen> {
  bool _started = false;
  bool _prefsLoaded = false;
  List<String> _order = List.from(_defaults);
  Set<String> _visible = Set.from(_defaults);
  Set<String> _minimized = {};
  String? _maximized;

  static const _defaults = <String>[
    'sales','orders','tables','kot','payments','pra','activity','leakage','expenses','store','branches','cameras'
  ];

  static const _labels = <String, String>{
    'sales': "Today's Sales",
    'orders': "Today's Receipts",
    'tables': 'Live Tables',
    'kot': 'Live KOT',
    'payments': 'Payments',
    'pra': 'PRA Monitor',
    'activity': 'Live Activity',
    'leakage': 'Leakage & Theft',
    'expenses': 'Expenses',
    'store': 'Store',
    'branches': 'Branches',
    'cameras': 'Cameras',
  };

  static const _permission = <String, String>{
    'tables': 'widget_tables',
    'kot': UserModel.viewKotWidgetPermission,
    'payments': UserModel.viewPaymentsWidgetPermission,
    'pra': UserModel.viewPraWidgetPermission,
    'leakage': UserModel.viewLeakageWidgetPermission,
    'expenses': UserModel.viewAccountsWidgetPermission,
    'store': UserModel.viewStoreWidgetPermission,
    'branches': UserModel.viewBranchesWidgetPermission,
    'cameras': UserModel.viewCamerasWidgetPermission,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      final u = context.read<AuthProvider>().currentUser;
      if (u != null) {
        context.read<TableProvider>().loadTables();
        context.read<SaleProvider>().fetchSales(u.id);
      }
    }
    if (!_prefsLoaded) {
      _prefsLoaded = true;
      _loadPrefs();
    }
  }

  DocumentReference<Map<String, dynamic>>? get _prefsRef {
    final u = context.read<AuthProvider>().currentUser;
    if (u == null) return null;
    final key = u.authUid.replaceAll('/', '_');
    return FirebaseFirestore.instance
        .collection('vendors').doc(u.id)
        .collection('dashboardPreferences').doc(key);
  }

  List<String> _allowed(UserModel u) => _defaults
      .where((id) => u.isAdmin || _permission[id] == null || u.hasPermission(_permission[id]!))
      .toList();

  Future<void> _loadPrefs() async {
    try {
      final d = await _prefsRef?.get();
      final x = d?.data();
      if (x == null || !mounted) return;
      final o = (x['order'] as List?)?.map((e) => e.toString()).where(_labels.containsKey).toList() ?? <String>[];
      final v = (x['visible'] as List?)?.map((e) => e.toString()).where(_labels.containsKey).toSet() ?? <String>{};
      final m = (x['minimized'] as List?)?.map((e) => e.toString()).where(_labels.containsKey).toSet() ?? <String>{};
      setState(() {
        _order = [...o, ..._defaults.where((e) => !o.contains(e))];
        _visible = v.isEmpty ? Set.from(_defaults) : v;
        _minimized = m;
      });
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      await _prefsRef?.set({
        'order': _order,
        'visible': _visible.toList(),
        'minimized': _minimized.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _customize() async {
    final u = context.read<AuthProvider>().currentUser;
    if (u == null || !u.canAddWidgets) return;
    final allowed = _allowed(u);
    final selected = Set<String>.from(_visible.intersection(allowed.toSet()));
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (_, setModal) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Add Widgets'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                children: allowed.map((id) => CheckboxListTile(
                  value: selected.contains(id),
                  dense: true,
                  title: Text(_labels[id]!),
                  onChanged: (v) => setModal(() => v == true ? selected.add(id) : selected.remove(id)),
                )).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => setModal(() { selected..clear()..addAll(allowed); }), child: const Text('Add all')),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, selected), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _visible = result);
      _savePrefs();
    }
  }

  void _hide(String id) {
    setState(() {
      _visible.remove(id);
      _minimized.remove(id);
      if (_maximized == id) _maximized = null;
    });
    _savePrefs();
  }

  void _toggleMin(String id) {
    setState(() {
      if (!_minimized.remove(id)) {
        _minimized.add(id);
        if (_maximized == id) _maximized = null;
      }
    });
    _savePrefs();
  }

  void _toggleMax(String id) {
    setState(() {
      _minimized.remove(id);
      _maximized = _maximized == id ? null : id;
    });
  }

  void _move(String from, String to) {
    if (from == to) return;
    final x = _order.indexOf(from);
    final y = _order.indexOf(to);
    if (x < 0 || y < 0) return;
    setState(() {
      final item = _order.removeAt(x);
      _order.insert(y, item);
    });
    _savePrefs();
  }

  bool _today(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AuthProvider>().currentUser;
    if (u == null) return const Center(child: CircularProgressIndicator());
    final tables = context.watch<TableProvider>().tables;
    final sales = context.watch<SaleProvider>().sales;
    final today = sales.where((s) => _today(s.createdAt)).toList();
    final revenue = today.fold<double>(0, (a, b) => a + b.total);
    final vendor = FirebaseFirestore.instance.collection('vendors').doc(u.id);
    final allowed = _allowed(u).toSet();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: vendor.collection('tableOrders').snapshots(),
      builder: (context, snap) {
        final orders = snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final ids = _order.where((e) => _visible.contains(e) && allowed.contains(e)).toList();
        final mins = ids.where(_minimized.contains).toList();
        final normal = ids.where((e) => !_minimized.contains(e) && e != _maximized).toList();
        return ColoredBox(
          color: Colors.white,
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(22, 22, u.isAdmin ? 350 : 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(u.restaurantName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _ink)),
                        const SizedBox(height: 3),
                        const Row(children: [
                          Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                          SizedBox(width: 6),
                          Text('LIVE • Updates automatically', style: TextStyle(fontSize: 11, color: _muted)),
                        ]),
                      ])),
                      if (u.canAddWidgets) OutlinedButton.icon(onPressed: _customize, icon: const Icon(Icons.add, size: 17), label: const Text('Add Widgets')),
                    ]),
                    if (mins.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(spacing: 8, runSpacing: 8, children: mins.map((id) => _MiniCard(title: _labels[id]!, onRestore: () => _toggleMin(id), onClose: () => _hide(id))).toList()),
                    ],
                    if (_maximized != null && ids.contains(_maximized)) ...[
                      const SizedBox(height: 12),
                      _dashWidget(_maximized!, revenue, today, tables, orders, sales, true),
                    ],
                    const SizedBox(height: 12),
                    LayoutBuilder(builder: (_, c) {
                      final cols = c.maxWidth > 1050 ? 3 : c.maxWidth > 650 ? 2 : 1;
                      final width = (c.maxWidth - (cols - 1) * 12) / cols;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: normal.map((id) => DragTarget<String>(
                          onWillAcceptWithDetails: (d) => d.data != id,
                          onAcceptWithDetails: (d) => _move(d.data, id),
                          builder: (_, __, ___) => LongPressDraggable<String>(
                            data: id,
                            feedback: Material(color: Colors.transparent, child: SizedBox(width: width, child: _dashWidget(id, revenue, today, tables, orders, sales, false))),
                            child: SizedBox(width: width, child: _dashWidget(id, revenue, today, tables, orders, sales, false)),
                          ),
                        )).toList(),
                      );
                    }),
                  ],
                ),
              ),
              if (u.isAdmin)
                Positioned(top: 14, right: 14, bottom: 14, width: 315, child: _AdminNotificationStack(user: u)),
            ],
          ),
        );
      },
    );
  }

  Widget _dashWidget(String id, double revenue, List<Sale> today, List<RestaurantTable> tables, List<QueryDocumentSnapshot<Map<String, dynamic>>> orders, List<Sale> sales, bool max) {
    final active = tables.where((t) => t.status != TableStatus.empty).length;
    final making = orders.where((d) => ['making','open','sent'].contains((d.data()['status'] ?? '').toString().toLowerCase())).length;
    final ready = orders.where((d) => (d.data()['status'] ?? '').toString().toLowerCase() == 'ready').length;
    final pra = today.where((s) => (s.praInvoiceNo ?? '').isNotEmpty).length;
    final reprints = today.where((s) => s.receiptPrintCount > 1).length;
    Widget card(String title, String subtitle, Widget child, VoidCallback tap) => _Card(title: title, subtitle: subtitle, onHide: () => _hide(id), onMinimize: () => _toggleMin(id), onMaximize: () => _toggleMax(id), maximized: max, onTap: tap, child: child);

    switch (id) {
      case 'sales': return card("Today's Sales", 'Realtime', _metricBody('Rs ${revenue.toStringAsFixed(0)}', Icons.account_balance_wallet_outlined), () => context.go(AppRouter.sales));
      case 'orders': return card("Today's Receipts", '${today.length} completed', _metricBody('${today.length}', Icons.receipt_long_outlined), () => context.go(AppRouter.sales));
      case 'tables': return card('Live Tables', '$active in service • ${tables.length - active} available', _tables(tables), () => context.go(AppRouter.tables));
      case 'kot': return card('Live KOT', '$making making • $ready ready', _kots(orders), () => context.go(AppRouter.orders));
      case 'payments': return card('Payments', 'Live completed receipts', _payments(today), () => context.go(AppRouter.sales));
      case 'pra': return card('PRA Monitor', '$pra / ${today.length} fiscalized', _metricBody('$pra / ${today.length} fiscalized', Icons.verified_user_outlined), () => context.go(AppRouter.praSettings));
      case 'activity': return card('Live Activity', 'Latest operational changes', _activity(orders, sales), () => context.go(AppRouter.orders));
      case 'leakage': return card('Leakage & Theft', '$reprints reprint alerts', _leakage(today, orders), () {});
      case 'expenses': return card('Expenses', 'Operating costs and expense controls', _metricBody('Open expenses', Icons.payments_outlined), () => context.go(AppRouter.expenses));
      case 'store': return card('Store', 'Stock issues and movement control', _metricBody('Open store', Icons.storefront_outlined), () => context.go(AppRouter.storeOut));
      case 'branches': return card('Branches', 'Multi-branch monitoring', _metricBody('Open branches', Icons.account_tree_outlined), () => context.go(AppRouter.branches));
      case 'cameras': return card('Cameras', 'CCTV / NVR feeds', _metricBody('Camera monitoring', Icons.videocam_outlined), () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configure CCTV/NVR feeds in settings.'))));
      default: return const SizedBox.shrink();
    }
  }

  Widget _metricBody(String value, IconData icon) => Row(children: [
    Container(width: 44, height: 44, decoration: BoxDecoration(color: _purple.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: _purple)),
    const SizedBox(width: 12),
    Expanded(child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _ink))),
  ]);

  Widget _tables(List<RestaurantTable> list) => ListView(children: list.take(8).map((t) => _row('Table ${t.tableNumber}', t.statusString.toUpperCase(), t.status == TableStatus.empty ? const Color(0xFF10B981) : _orange)).toList());

  String _kotName(Map<String, dynamic> a) {
    final table = (a['tableNumber'] ?? '').toString().trim();
    if (table.isNotEmpty) return 'Table $table';
    final kot = (a['kotNumber'] ?? '').toString().trim();
    return kot.isNotEmpty ? 'KOT $kot' : 'Kitchen order';
  }

  Widget _kots(List<QueryDocumentSnapshot<Map<String, dynamic>>> list) => ListView(children: list.take(8).map((d) {
    final a = d.data();
    final status = (a['status'] ?? 'open').toString();
    return _row(_kotName(a), status.toUpperCase(), status == 'ready' ? const Color(0xFF10B981) : _orange);
  }).toList());

  Widget _payments(List<Sale> list) => ListView(children: list.take(8).map((s) => _row('Rs ${s.total.toStringAsFixed(0)}', s.paymentMethod.toUpperCase(), _purple)).toList());

  Widget _activity(List<QueryDocumentSnapshot<Map<String, dynamic>>> orders, List<Sale> sales) => ListView(children: [
    ...orders.take(4).map((d) => _row(_kotName(d.data()), '${d.data()['status'] ?? 'UPDATED'}'.toUpperCase(), _purple)),
    ...sales.take(4).map((x) => _row('Receipt ${x.id.length > 12 ? x.id.substring(0, 12) : x.id}', 'PAID ${x.paymentMethod.toUpperCase()}', const Color(0xFF10B981))),
  ]);

  Widget _leakage(List<Sale> sales, List<QueryDocumentSnapshot<Map<String, dynamic>>> orders) {
    final items = <Widget>[];
    for (final x in sales.where((e) => e.receiptPrintCount > 1).take(4)) {
      items.add(_row('Receipt ${x.id} reprinted', '${x.receiptPrintCount} PRINTS', const Color(0xFFEF4444)));
    }
    for (final x in orders.where((e) => (e.data()['status'] ?? '') == 'cancelled').take(3)) {
      items.add(_row(_kotName(x.data()), 'CANCELLED • REVIEW', const Color(0xFFEF4444)));
    }
    return ListView(children: items.isEmpty ? [const Padding(padding: EdgeInsets.all(12), child: Text('No current leakage alerts', style: TextStyle(fontSize: 11, color: _muted)))] : items);
  }

  Widget _row(String left, String right, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 7),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(8)),
    child: Row(children: [
      Expanded(child: Text(left, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _ink))),
      Text(right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color)),
    ]),
  );
}

class _Card extends StatelessWidget {
  final String title, subtitle;
  final VoidCallback onHide, onMinimize, onMaximize, onTap;
  final bool maximized;
  final Widget child;
  const _Card({required this.title, required this.subtitle, required this.onHide, required this.onMinimize, required this.onMaximize, required this.maximized, required this.onTap, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    height: maximized ? 430 : 285,
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _line), borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 5),
        child: Row(children: [
          Expanded(child: InkWell(onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink)),
            Text(subtitle, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: _muted)),
          ]))),
          IconButton(tooltip: 'Minimize', visualDensity: VisualDensity.compact, onPressed: onMinimize, icon: const Icon(Icons.remove_rounded, size: 16, color: Color(0xFF64748B))),
          IconButton(tooltip: maximized ? 'Restore' : 'Maximize', visualDensity: VisualDensity.compact, onPressed: onMaximize, icon: Icon(maximized ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded, size: 15, color: const Color(0xFF64748B))),
          IconButton(tooltip: 'Remove widget', visualDensity: VisualDensity.compact, onPressed: onHide, icon: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF9CA3AF))),
        ]),
      ),
      Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(14, 2, 14, 12), child: child)),
    ]),
  );
}

class _MiniCard extends StatelessWidget {
  final String title;
  final VoidCallback onRestore, onClose;
  const _MiniCard({required this.title, required this.onRestore, required this.onClose});
  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    padding: const EdgeInsets.only(left: 12),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _line), borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
      IconButton(tooltip: 'Restore', onPressed: onRestore, icon: const Icon(Icons.add_rounded, size: 16)),
      IconButton(tooltip: 'Remove', onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 14)),
    ]),
  );
}

class _AdminNotificationStack extends StatelessWidget {
  final UserModel user;
  const _AdminNotificationStack({required this.user});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('vendors').doc(user.id).collection('notifications');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.orderBy('createdAt', descending: true).limit(40).snapshots(),
      builder: (_, snap) {
        final docs = (snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            .where((d) => !List<String>.from(d.data()['dismissedBy'] ?? const <String>[]).contains(user.authUid))
            .take(12)
            .toList();
        final unread = docs.where((d) => !List<String>.from(d.data()['readBy'] ?? const <String>[]).contains(user.authUid)).length;
        return Container(
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: _line), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 8),
              child: Row(children: [
                const Icon(Icons.notifications_active_outlined, size: 18),
                const SizedBox(width: 7),
                const Expanded(child: Text('Notifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900))),
                if (unread > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(12)), child: Text('$unread new', style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900))),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: docs.isEmpty
                  ? const Center(child: Text('No notifications', style: TextStyle(fontSize: 11, color: _muted)))
                  : ListView(
                      padding: const EdgeInsets.all(9),
                      children: docs.map((d) {
                        final a = d.data();
                        final read = List<String>.from(a['readBy'] ?? const <String>[]).contains(user.authUid);
                        return _NoticeCard(
                          title: (a['title'] ?? 'Notification').toString(),
                          message: (a['message'] ?? '').toString(),
                          read: read,
                          onRead: read ? null : () async {
                            await d.reference.set({'readBy': FieldValue.arrayUnion([user.authUid]), 'readAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                          },
                          onClose: () async {
                            await d.reference.set({'dismissedBy': FieldValue.arrayUnion([user.authUid])}, SetOptions(merge: true));
                          },
                        );
                      }).toList(),
                    ),
            ),
          ]),
        );
      },
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final String title, message;
  final bool read;
  final VoidCallback? onRead;
  final VoidCallback onClose;
  const _NoticeCard({required this.title, required this.message, required this.read, required this.onRead, required this.onClose});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onRead,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: read ? _blueSoft : _orangeSoft,
        border: Border.all(color: read ? const Color(0xFFBFDBFE) : const Color(0xFFFCD34D)),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .035), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 29,
          height: 29,
          decoration: BoxDecoration(color: (read ? _blue : _orange).withValues(alpha: .12), shape: BoxShape.circle),
          child: Icon(read ? Icons.notifications_none_rounded : Icons.notifications_active_rounded, size: 14, color: read ? _blue : _orange),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(message, style: const TextStyle(fontSize: 9.5, height: 1.25, color: _muted)),
          const SizedBox(height: 5),
          Row(children: [
            Icon(read ? Icons.done_all_rounded : Icons.done_rounded, size: 14, color: read ? _blue : _orange),
            const SizedBox(width: 4),
            Text(read ? 'Read' : 'Unread', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: read ? _blue : _orange)),
          ]),
        ])),
        IconButton(tooltip: 'Dismiss', visualDensity: VisualDensity.compact, onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF94A3B8))),
      ]),
    ),
  );
}
