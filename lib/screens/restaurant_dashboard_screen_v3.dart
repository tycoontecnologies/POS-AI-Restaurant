import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pos/models/sale.dart';
import 'package:pos/models/table.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/sale_provider.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/routes/app_router.dart';

const _ink = Color(0xFF101828);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE4E7EC);
const _soft = Color(0xFFF9FAFB);
const _purple = Color(0xFF6C4CF1);
const _green = Color(0xFF12B76A);
const _orange = Color(0xFFF79009);
const _blue = Color(0xFF2E90FA);
const _pink = Color(0xFFEE46BC);

class RestaurantDashboardScreenV3 extends StatefulWidget {
  const RestaurantDashboardScreenV3({super.key});

  @override
  State<RestaurantDashboardScreenV3> createState() =>
      _RestaurantDashboardScreenV3State();
}

class _RestaurantDashboardScreenV3State
    extends State<RestaurantDashboardScreenV3> {
  static const _allSections = <String, String>{
    'salesChart': 'Sales Overview',
    'recentOrders': 'Recent Orders',
    'topItems': 'Top Selling Items',
    'kitchen': 'Kitchen Performance',
    'alerts': 'Alerts & Notifications',
    'branches': 'Branch Performance',
  };

  bool _started = false;
  bool _prefsLoaded = false;
  bool _customizerShown = false;
  Set<String> _visible = _allSections.keys.toSet();

  DocumentReference<Map<String, dynamic>>? get _prefsRef {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance
        .collection('vendors')
        .doc(user.id)
        .collection('dashboardPreferences')
        .doc('${user.authUid.replaceAll('/', '_')}_pro');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        context.read<TableProvider>().loadTables();
        context.read<SaleProvider>().fetchSales(user.id);
      }
    }
    if (!_prefsLoaded) {
      _prefsLoaded = true;
      _loadPrefs();
    }
    final customize =
        GoRouterState.of(context).uri.queryParameters['customize'] == '1';
    if (customize && !_customizerShown) {
      _customizerShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _customize();
      });
    }
  }

  Future<void> _loadPrefs() async {
    try {
      final data = (await _prefsRef?.get())?.data();
      if (data == null || !mounted) return;
      final visible = (data['visibleSections'] as List?)
          ?.map((e) => e.toString())
          .where(_allSections.containsKey)
          .toSet();
      if (visible != null && visible.isNotEmpty)
        setState(() => _visible = visible);
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      await _prefsRef?.set({
        'visibleSections': _visible.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _customize() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || !user.canAddWidgets) return;
    final selected = Set<String>.from(_visible);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setModal) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Customize Dashboard'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _allSections.entries
                  .map(
                    (entry) => CheckboxListTile(
                      dense: true,
                      value: selected.contains(entry.key),
                      title: Text(
                        entry.value,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onChanged: (value) => setModal(
                        () => value == true
                            ? selected.add(entry.key)
                            : selected.remove(entry.key),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setModal(
                () => selected
                  ..clear()
                  ..addAll(_allSections.keys),
              ),
              child: const Text('Show all'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _visible = result);
      await _savePrefs();
      if (GoRouterState.of(
        context,
      ).uri.queryParameters.containsKey('customize')) {
        context.go(AppRouter.dashboard);
      }
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());

    final tables = context.watch<TableProvider>().tables;
    final sales = context.watch<SaleProvider>().sales;
    final now = DateTime.now();
    final todaySales = sales.where((s) => _sameDay(s.createdAt, now)).toList();
    final todayRevenue = todaySales.fold<double>(
      0,
      (sum, sale) => sum + sale.total,
    );
    final avgBill = todaySales.isEmpty ? 0.0 : todayRevenue / todaySales.length;
    final activeTables = tables
        .where((t) => t.status != TableStatus.empty)
        .length;
    final praFinalized = todaySales
        .where((s) => (s.praInvoiceNo ?? '').isNotEmpty)
        .length;
    final vendor = FirebaseFirestore.instance
        .collection('vendors')
        .doc(user.id);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: vendor.collection('tableOrders').snapshots(),
      builder: (_, orderSnapshot) {
        final orders =
            orderSnapshot.data?.docs ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final kitchenAverage = _averageKitchenTime(orders);
        return ColoredBox(
          color: _soft,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dashboard',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Overview of your restaurant operations',
                            style: TextStyle(fontSize: 11, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _line),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: _muted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Today, ${DateFormat('d MMM yyyy').format(now)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (user.canAddWidgets) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Customize widgets',
                        onPressed: _customize,
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (_, constraints) {
                    final width = constraints.maxWidth;
                    final columns = width >= 1350
                        ? 6
                        : width >= 900
                        ? 3
                        : width >= 560
                        ? 2
                        : 1;
                    final cardWidth = (width - (columns - 1) * 12) / columns;
                    final kpis = [
                      _Kpi(
                        'Total Sales',
                        'Rs ${_money(todayRevenue)}',
                        Icons.account_balance_wallet_outlined,
                        const Color(0xFF12B76A),
                        _salesTrend(sales),
                      ),
                      _Kpi(
                        'Orders',
                        '${todaySales.length}',
                        Icons.receipt_long_outlined,
                        _blue,
                        _orderTrend(sales),
                      ),
                      _Kpi(
                        'Average Bill',
                        'Rs ${_money(avgBill)}',
                        Icons.point_of_sale_outlined,
                        _purple,
                        const <double>[],
                      ),
                      _Kpi(
                        'Kitchen Time',
                        kitchenAverage == null
                            ? '—'
                            : _duration(kitchenAverage),
                        Icons.soup_kitchen_outlined,
                        _orange,
                        const <double>[],
                      ),
                      _Kpi(
                        'Active Tables',
                        '$activeTables / ${tables.length}',
                        Icons.table_restaurant_outlined,
                        const Color(0xFF06AED4),
                        const <double>[],
                      ),
                      _Kpi(
                        'PRA Finalized',
                        '$praFinalized / ${todaySales.length}',
                        Icons.verified_user_outlined,
                        _pink,
                        const <double>[],
                      ),
                    ];
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: kpis
                          .map(
                            (kpi) => SizedBox(
                              width: cardWidth,
                              child: _KpiCard(data: kpi),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (_, constraints) {
                    final wide = constraints.maxWidth >= 1120;
                    final medium = constraints.maxWidth >= 760;
                    final cardWidth = wide
                        ? (constraints.maxWidth - 24) / 3
                        : medium
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    final sections = <Widget>[];
                    if (_visible.contains('salesChart'))
                      sections.add(
                        SizedBox(
                          width: wide ? cardWidth * 1.35 : cardWidth,
                          height: 330,
                          child: _SalesOverviewCard(sales: sales),
                        ),
                      );
                    if (_visible.contains('recentOrders'))
                      sections.add(
                        SizedBox(
                          width: cardWidth,
                          height: 330,
                          child: _RecentOrdersCard(sales: sales),
                        ),
                      );
                    if (_visible.contains('topItems'))
                      sections.add(
                        SizedBox(
                          width: wide ? cardWidth * .65 : cardWidth,
                          height: 330,
                          child: _TopItemsCard(sales: sales),
                        ),
                      );
                    if (_visible.contains('kitchen'))
                      sections.add(
                        SizedBox(
                          width: cardWidth,
                          height: 260,
                          child: _KitchenCard(orders: orders),
                        ),
                      );
                    if (_visible.contains('alerts'))
                      sections.add(
                        SizedBox(
                          width: cardWidth,
                          height: 260,
                          child: _AlertsCard(user: user),
                        ),
                      );
                    if (_visible.contains('branches'))
                      sections.add(
                        SizedBox(
                          width: cardWidth,
                          height: 260,
                          child: _BranchCard(user: user, sales: todaySales),
                        ),
                      );
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: sections,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Duration? _averageKitchenTime(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
  ) {
    final durations = <Duration>[];
    for (final doc in orders) {
      final d = doc.data();
      final start = d['createdAt'];
      final end = d['readyAt'] ?? d['servedAt'];
      if (start is Timestamp &&
          end is Timestamp &&
          end.toDate().isAfter(start.toDate())) {
        durations.add(end.toDate().difference(start.toDate()));
      }
    }
    if (durations.isEmpty) return null;
    final milliseconds =
        durations.fold<int>(0, (sum, d) => sum + d.inMilliseconds) ~/
        durations.length;
    return Duration(milliseconds: milliseconds);
  }

  List<double> _salesTrend(List<Sale> sales) {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - i));
      return sales
          .where((s) => _sameDay(s.createdAt, day))
          .fold<double>(0, (a, b) => a + b.total);
    });
  }

  List<double> _orderTrend(List<Sale> sales) {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - i));
      return sales.where((s) => _sameDay(s.createdAt, day)).length.toDouble();
    });
  }

  String _money(double value) => NumberFormat('#,##0').format(value.round());
  String _duration(Duration d) =>
      '${d.inMinutes}m ${(d.inSeconds % 60).toString().padLeft(2, '0')}s';
}

class _Kpi {
  final String label, value;
  final IconData icon;
  final Color color;
  final List<double> trend;
  const _Kpi(this.label, this.value, this.icon, this.color, this.trend);
}

class _KpiCard extends StatelessWidget {
  final _Kpi data;
  const _KpiCard({required this.data});
  @override
  Widget build(BuildContext context) => Container(
    height: 132,
    padding: const EdgeInsets.all(14),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: .11),
                shape: BoxShape.circle,
              ),
              child: Icon(data.icon, color: data.color, size: 18),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                data.label,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: _muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          data.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
        if (data.trend.length > 1) ...[
          const Spacer(),
          SizedBox(
            height: 24,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(data.trend, data.color),
            ),
          ),
        ],
      ],
    ),
  );
}

class _SalesOverviewCard extends StatelessWidget {
  final List<Sale> sales;
  const _SalesOverviewCard({required this.sales});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - i)),
    );
    final values = days
        .map(
          (day) => sales
              .where((s) => _sameDayStatic(s.createdAt, day))
              .fold<double>(0, (a, b) => a + b.total),
        )
        .toList();
    final thisWeek = values.fold<double>(0, (a, b) => a + b);
    return _Panel(
      title: 'Sales Overview',
      trailing: const _PeriodChip('This Week'),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
              child: CustomPaint(
                size: Size.infinite,
                painter: _LineChartPainter(values),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: days
                .map(
                  (d) => Text(
                    DateFormat('EEE d').format(d),
                    style: const TextStyle(fontSize: 8.5, color: _muted),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    'This Week',
                    'Rs ${NumberFormat('#,##0').format(thisWeek.round())}',
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    'Orders',
                    '${sales.where((s) => days.any((d) => _sameDayStatic(s.createdAt, d))).length}',
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    'Daily Avg',
                    'Rs ${NumberFormat('#,##0').format((thisWeek / 7).round())}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentOrdersCard extends StatelessWidget {
  final List<Sale> sales;
  const _RecentOrdersCard({required this.sales});
  @override
  Widget build(BuildContext context) {
    final sorted = [...sales]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _Panel(
      title: 'Recent Orders',
      trailing: TextButton(
        onPressed: () => context.go(AppRouter.sales),
        child: const Text('View All'),
      ),
      child: ListView.separated(
        itemCount: math.min(6, sorted.length),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final sale = sorted[i];
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F3FF),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 17,
                color: _purple,
              ),
            ),
            title: Text(
              '#${sale.id}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              '${sale.tableNumber?.isNotEmpty == true ? 'Table ${sale.tableNumber}' : sale.paymentMethod} • ${DateFormat('h:mm a').format(sale.createdAt)}',
              style: const TextStyle(fontSize: 8.8, color: _muted),
            ),
            trailing: Text(
              'Rs ${NumberFormat('#,##0').format(sale.total.round())}',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopItemsCard extends StatelessWidget {
  final List<Sale> sales;
  const _TopItemsCard({required this.sales});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final qty = <String, int>{};
    final revenue = <String, double>{};
    for (final sale in sales.where((s) => !s.createdAt.isBefore(weekStart))) {
      for (final item in sale.items) {
        qty[item.productName] = (qty[item.productName] ?? 0) + item.quantity;
        revenue[item.productName] =
            (revenue[item.productName] ?? 0) + item.price * item.quantity;
      }
    }
    final names = qty.keys.toList()
      ..sort((a, b) => (qty[b] ?? 0).compareTo(qty[a] ?? 0));
    final maxQty = names.isEmpty ? 1 : qty[names.first] ?? 1;
    return _Panel(
      title: 'Top Selling Items',
      trailing: const _PeriodChip('This Week'),
      child: ListView.separated(
        itemCount: math.min(5, names.length),
        separatorBuilder: (_, __) => const SizedBox(height: 7),
        itemBuilder: (_, i) {
          final name = names[i];
          final count = qty[name] ?? 0;
          return Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _soft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: count / maxQty,
                        minHeight: 4,
                        backgroundColor: const Color(0xFFF2F4F7),
                        valueColor: const AlwaysStoppedAnimation(_purple),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Rs ${NumberFormat('#,##0').format((revenue[name] ?? 0).round())}',
                    style: const TextStyle(fontSize: 8.5, color: _muted),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KitchenCard extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> orders;
  const _KitchenCard({required this.orders});
  @override
  Widget build(BuildContext context) {
    var making = 0, ready = 0, served = 0;
    for (final doc in orders) {
      final status = (doc.data()['status'] ?? '').toString().toLowerCase();
      if (['open', 'sent', 'making', 'preparing'].contains(status)) making++;
      if (status == 'ready') ready++;
      if (['served', 'completed', 'checkout'].contains(status)) served++;
    }
    return _Panel(
      title: 'Kitchen Performance',
      trailing: const _PeriodChip('Live'),
      child: Row(
        children: [
          Expanded(child: _BigMiniStat('$making', 'Preparing', _orange)),
          const VerticalDivider(width: 1),
          Expanded(child: _BigMiniStat('$ready', 'Ready', _green)),
          const VerticalDivider(width: 1),
          Expanded(child: _BigMiniStat('$served', 'Served', _blue)),
        ],
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  final UserModel user;
  const _AlertsCard({required this.user});
  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('vendors')
        .doc(user.id)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(8);
    return _Panel(
      title: 'Alerts & Notifications',
      trailing: const Text(
        'Live',
        style: TextStyle(
          fontSize: 9,
          color: _purple,
          fontWeight: FontWeight.w800,
        ),
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (_, snapshot) {
          final docs =
              snapshot.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          if (docs.isEmpty)
            return const Center(
              child: Text(
                'No alerts',
                style: TextStyle(color: _muted, fontSize: 10),
              ),
            );
          return ListView.separated(
            itemCount: math.min(5, docs.length),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = docs[i].data();
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFAEB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    size: 15,
                    color: _orange,
                  ),
                ),
                title: Text(
                  (d['title'] ?? 'Alert').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  (d['message'] ?? '').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8.5, color: _muted),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  final UserModel user;
  final List<Sale> sales;
  const _BranchCard({required this.user, required this.sales});
  @override
  Widget build(BuildContext context) {
    final total = sales.fold<double>(0, (a, b) => a + b.total);
    return _Panel(
      title: 'Branch Performance',
      trailing: const _PeriodChip('Today'),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F3FF),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                size: 17,
                color: _purple,
              ),
            ),
            title: Text(
              user.branchName,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: Text(
              '${sales.length} orders',
              style: const TextStyle(fontSize: 9, color: _muted),
            ),
            trailing: Text(
              'Rs ${NumberFormat('#,##0').format(total.round())}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  'Restaurant',
                  user.restaurantName.isEmpty
                      ? 'Restaurant'
                      : user.restaurantName,
                ),
              ),
              Expanded(child: _MiniStat('Status', 'LIVE')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget trailing, child;
  const _Panel({
    required this.title,
    required this.trailing,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _cardDecoration(),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            trailing,
          ],
        ),
        const SizedBox(height: 8),
        Expanded(child: child),
      ],
    ),
  );
}

class _PeriodChip extends StatelessWidget {
  final String text;
  const _PeriodChip(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: _soft,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: _line),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 8.5,
        fontWeight: FontWeight.w700,
        color: _muted,
      ),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: const TextStyle(fontSize: 8.5, color: _muted)),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
      ),
    ],
  );
}

class _BigMiniStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _BigMiniStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        style: const TextStyle(
          fontSize: 9.5,
          color: _muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(13),
  border: Border.all(color: _line),
  boxShadow: const [
    BoxShadow(color: Color(0x08101828), blurRadius: 12, offset: Offset(0, 3)),
  ],
);

bool _sameDayStatic(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _SparklinePainter(this.values, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final span = math.max(1.0, maxV - minV);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - ((values[i] - minV) / span) * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  _LineChartPainter(this.values);
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFF2F4F7)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.length < 2) return;
    final maxV = math.max(1.0, values.reduce(math.max));
    final path = Path();
    final fill = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - (values[i] / maxV) * (size.height - 10);
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x336C4CF1), Color(0x006C4CF1)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _purple
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - (values[i] / maxV) * (size.height - 10);
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = _purple);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values;
}
