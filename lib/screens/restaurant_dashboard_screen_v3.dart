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
  List<String> _sectionOrder = _allSections.keys.toList();
  List<String> _kpiOrder = const [
    'sales',
    'orders',
    'avg',
    'kitchenTime',
    'tables',
    'pra',
  ].toList();

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
      final savedOrder = (data['sectionOrder'] as List?)
          ?.map((e) => e.toString())
          .where(_allSections.containsKey)
          .toList();
      final savedKpis = (data['kpiOrder'] as List?)
          ?.map((e) => e.toString())
          .where(
            const {
              'sales',
              'orders',
              'avg',
              'kitchenTime',
              'tables',
              'pra',
            }.contains,
          )
          .toList();
      setState(() {
        if (visible != null && visible.isNotEmpty) _visible = visible;
        if (savedOrder != null && savedOrder.isNotEmpty) {
          _sectionOrder = [
            ...savedOrder,
            ..._allSections.keys.where((x) => !savedOrder.contains(x)),
          ];
        }
        if (savedKpis != null && savedKpis.isNotEmpty) {
          _kpiOrder = [
            ...savedKpis,
            ...[
              'sales',
              'orders',
              'avg',
              'kitchenTime',
              'tables',
              'pra',
            ].where((x) => !savedKpis.contains(x)),
          ];
        }
      });
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      await _prefsRef?.set({
        'visibleSections': _visible.toList(),
        'sectionOrder': _sectionOrder,
        'kpiOrder': _kpiOrder,
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
                        'sales',
                        'Total Sales',
                        'Rs ${_money(todayRevenue)}',
                        Icons.account_balance_wallet_outlined,
                        const Color(0xFF12B76A),
                        _salesTrend(sales),
                        {
                          'Today': 'Rs ${_money(todayRevenue)}',
                          'Orders today': '${todaySales.length}',
                          'Average bill': 'Rs ${_money(avgBill)}',
                          '7-day total':
                              'Rs ${_money(_salesTrend(sales).fold<double>(0, (a, b) => a + b))}',
                        },
                      ),
                      _Kpi(
                        'orders',
                        'Orders',
                        '${todaySales.length}',
                        Icons.receipt_long_outlined,
                        _blue,
                        _orderTrend(sales),
                        {
                          'Today': '${todaySales.length}',
                          'Sales today': 'Rs ${_money(todayRevenue)}',
                          'Average bill': 'Rs ${_money(avgBill)}',
                          '7-day orders':
                              '${_orderTrend(sales).fold<double>(0, (a, b) => a + b).round()}',
                        },
                      ),
                      _Kpi(
                        'avg',
                        'Average Bill',
                        'Rs ${_money(avgBill)}',
                        Icons.point_of_sale_outlined,
                        _purple,
                        _averageBillTrend(sales),
                        {
                          'Average bill': 'Rs ${_money(avgBill)}',
                          'Sales today': 'Rs ${_money(todayRevenue)}',
                          'Orders today': '${todaySales.length}',
                        },
                      ),
                      _Kpi(
                        'kitchenTime',
                        'Kitchen Time',
                        kitchenAverage == null
                            ? '—'
                            : _duration(kitchenAverage),
                        Icons.soup_kitchen_outlined,
                        _orange,
                        const <double>[],
                        {
                          'Average kitchen time': kitchenAverage == null
                              ? 'Not available'
                              : _duration(kitchenAverage),
                          'Live kitchen orders': '${orders.length}',
                        },
                      ),
                      _Kpi(
                        'tables',
                        'Active Tables',
                        '$activeTables / ${tables.length}',
                        Icons.table_restaurant_outlined,
                        const Color(0xFF06AED4),
                        const <double>[],
                        {
                          'Active tables': '$activeTables',
                          'Total tables': '${tables.length}',
                          'Utilization': tables.isEmpty
                              ? '0%'
                              : '${((activeTables / tables.length) * 100).round()}%',
                        },
                      ),
                      _Kpi(
                        'pra',
                        'PRA Finalized',
                        '$praFinalized / ${todaySales.length}',
                        Icons.verified_user_outlined,
                        _pink,
                        _praTrend(sales),
                        {
                          'Finalized': '$praFinalized',
                          'Total receipts': '${todaySales.length}',
                          'Completion': todaySales.isEmpty
                              ? '0%'
                              : '${((praFinalized / todaySales.length) * 100).round()}%',
                        },
                      ),
                    ];
                    final byId = {for (final kpi in kpis) kpi.id: kpi};
                    final ordered = _kpiOrder
                        .map((id) => byId[id])
                        .whereType<_Kpi>()
                        .toList();
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: ordered.map((kpi) {
                        return DragTarget<String>(
                          onWillAcceptWithDetails: (d) =>
                              d.data != kpi.id && _kpiOrder.contains(d.data),
                          onAcceptWithDetails: (d) {
                            final from = _kpiOrder.indexOf(d.data);
                            final to = _kpiOrder.indexOf(kpi.id);
                            if (from < 0 || to < 0 || from == to) return;
                            setState(() {
                              final moved = _kpiOrder.removeAt(from);
                              _kpiOrder.insert(to, moved);
                            });
                            _savePrefs();
                          },
                          builder: (_, candidate, __) =>
                              LongPressDraggable<String>(
                                data: kpi.id,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: SizedBox(
                                    width: cardWidth,
                                    child: Opacity(
                                      opacity: .92,
                                      child: _KpiCard(data: kpi),
                                    ),
                                  ),
                                ),
                                childWhenDragging: SizedBox(
                                  width: cardWidth,
                                  child: Opacity(
                                    opacity: .30,
                                    child: _KpiCard(data: kpi),
                                  ),
                                ),
                                child: SizedBox(
                                  width: cardWidth,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => _showKpiDetails(kpi),
                                    child: _KpiCard(data: kpi),
                                  ),
                                ),
                              ),
                        );
                      }).toList(),
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
                    final widgets = <String, Widget>{};
                    if (_visible.contains('salesChart'))
                      widgets['salesChart'] = SizedBox(
                        width: wide ? cardWidth * 1.35 : cardWidth,
                        height: 330,
                        child: _SalesOverviewCard(sales: sales),
                      );
                    if (_visible.contains('recentOrders'))
                      widgets['recentOrders'] = SizedBox(
                        width: cardWidth,
                        height: 330,
                        child: _RecentOrdersCard(sales: sales),
                      );
                    if (_visible.contains('topItems'))
                      widgets['topItems'] = SizedBox(
                        width: wide ? cardWidth * .65 : cardWidth,
                        height: 330,
                        child: _TopItemsCard(sales: sales),
                      );
                    if (_visible.contains('kitchen'))
                      widgets['kitchen'] = SizedBox(
                        width: cardWidth,
                        height: 260,
                        child: _KitchenCard(orders: orders),
                      );
                    if (_visible.contains('alerts'))
                      widgets['alerts'] = SizedBox(
                        width: cardWidth,
                        height: 260,
                        child: _AlertsCard(user: user),
                      );
                    if (_visible.contains('branches'))
                      widgets['branches'] = SizedBox(
                        width: cardWidth,
                        height: 260,
                        child: _BranchCard(user: user, sales: todaySales),
                      );
                    final orderedIds = _sectionOrder
                        .where(widgets.containsKey)
                        .toList();
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: orderedIds.map((id) {
                        final child = widgets[id]!;
                        return DragTarget<String>(
                          onWillAcceptWithDetails: (d) =>
                              d.data != id && _sectionOrder.contains(d.data),
                          onAcceptWithDetails: (d) {
                            final from = _sectionOrder.indexOf(d.data);
                            final to = _sectionOrder.indexOf(id);
                            if (from < 0 || to < 0 || from == to) return;
                            setState(() {
                              final moved = _sectionOrder.removeAt(from);
                              _sectionOrder.insert(to, moved);
                            });
                            _savePrefs();
                          },
                          builder: (_, candidate, __) =>
                              LongPressDraggable<String>(
                                data: id,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth * .75,
                                    ),
                                    child: Opacity(opacity: .90, child: child),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: .28,
                                  child: child,
                                ),
                                child: child,
                              ),
                        );
                      }).toList(),
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

  Future<void> _showKpiDetails(_Kpi kpi) async {
    final trendTotal = kpi.trend.fold<double>(0, (a, b) => a + b);
    final trendAverage = kpi.trend.isEmpty
        ? 0.0
        : trendTotal / kpi.trend.length;
    final trendHigh = kpi.trend.isEmpty ? 0.0 : kpi.trend.reduce(math.max);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 650),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 58,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _line)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: kpi.color.withValues(alpha: .11),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(kpi.icon, color: kpi.color, size: 19),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          kpi.label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kpi.value,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (kpi.details.isNotEmpty)
                          LayoutBuilder(
                            builder: (_, constraints) {
                              final cardWidth = constraints.maxWidth >= 560
                                  ? (constraints.maxWidth - 12) / 2
                                  : constraints.maxWidth;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: kpi.details.entries
                                    .map(
                                      (entry) => Container(
                                        width: cardWidth,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: _soft,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(color: _line),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry.key,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: _muted,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              entry.value,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                color: _ink,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                        if (kpi.trend.length > 1) ...[
                          const SizedBox(height: 20),
                          const Text(
                            '7-Day Trend',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: 150,
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _line),
                            ),
                            child: CustomPaint(
                              painter: _SparklinePainter(kpi.trend, kpi.color),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _DetailChip(
                                '7-day total',
                                kpi.id == 'sales'
                                    ? 'Rs ${_money(trendTotal)}'
                                    : '${trendTotal.round()}',
                              ),
                              _DetailChip(
                                'Daily average',
                                kpi.id == 'sales'
                                    ? 'Rs ${_money(trendAverage)}'
                                    : trendAverage.toStringAsFixed(1),
                              ),
                              _DetailChip(
                                'Highest day',
                                kpi.id == 'sales'
                                    ? 'Rs ${_money(trendHigh)}'
                                    : '${trendHigh.round()}',
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

  List<double> _averageBillTrend(List<Sale> sales) {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - i));
      final daySales = sales.where((s) => _sameDay(s.createdAt, day)).toList();
      if (daySales.isEmpty) return 0.0;
      return daySales.fold<double>(0, (a, b) => a + b.total) / daySales.length;
    });
  }

  List<double> _praTrend(List<Sale> sales) {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - i));
      final daySales = sales.where((s) => _sameDay(s.createdAt, day)).toList();
      if (daySales.isEmpty) return 0.0;
      final done = daySales
          .where((s) => (s.praInvoiceNo ?? '').isNotEmpty)
          .length;
      return done / daySales.length * 100;
    });
  }

  String _money(double value) => NumberFormat('#,##0').format(value.round());
  String _duration(Duration d) =>
      '${d.inMinutes}m ${(d.inSeconds % 60).toString().padLeft(2, '0')}s';
}

class _Kpi {
  final String id, label, value;
  final IconData icon;
  final Color color;
  final List<double> trend;
  final Map<String, String> details;
  const _Kpi(
    this.id,
    this.label,
    this.value,
    this.icon,
    this.color,
    this.trend, [
    this.details = const <String, String>{},
  ]);
}

class _KpiCard extends StatelessWidget {
  final _Kpi data;

  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final hasTrend = data.trend.length > 1;

    return Container(
      height: 126,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: .11),
                  shape: BoxShape.circle,
                ),
                child: Icon(data.icon, color: data.color, size: 17),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (hasTrend)
                Icon(Icons.show_chart_rounded, size: 15, color: data.color),
            ],
          ),

          const SizedBox(height: 7),

          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),

          const Spacer(),

          if (hasTrend)
            SizedBox(
              height: 35,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(data.trend, data.color),
              ),
            )
          else
            const SizedBox(height: 35),
        ],
      ),
    );
  }
}

class _SalesOverviewCard extends StatefulWidget {
  final List<Sale> sales;
  const _SalesOverviewCard({required this.sales});
  @override
  State<_SalesOverviewCard> createState() => _SalesOverviewCardState();
}

class _SalesOverviewCardState extends State<_SalesOverviewCard> {
  int _days = 7;
  int? _selectedIndex;

  List<DateTime> _dates() {
    final now = DateTime.now();
    return List.generate(
      _days,
      (i) => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: _days - 1 - i)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dates = _dates();
    final values = dates
        .map(
          (day) => widget.sales
              .where((s) => _sameDayStatic(s.createdAt, day))
              .fold<double>(0, (a, b) => a + b.total),
        )
        .toList();
    final total = values.fold<double>(0, (a, b) => a + b);
    final orderCount = widget.sales
        .where((s) => dates.any((d) => _sameDayStatic(s.createdAt, d)))
        .length;
    final selected = _selectedIndex != null && _selectedIndex! < values.length
        ? _selectedIndex!
        : values.length - 1;

    return _Panel(
      title: 'Sales Overview',
      trailing: Wrap(
        spacing: 4,
        children: [7, 30, 90]
            .map(
              (days) => ChoiceChip(
                label: Text(
                  days == 7
                      ? '7D'
                      : days == 30
                      ? '30D'
                      : '90D',
                ),
                selected: _days == days,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() {
                  _days = days;
                  _selectedIndex = null;
                }),
              ),
            )
            .toList(),
      ),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  if (values.isEmpty || c.maxWidth <= 0) return;
                  final x = d.localPosition.dx.clamp(0.0, c.maxWidth);
                  final index = ((x / c.maxWidth) * (values.length - 1))
                      .round()
                      .clamp(0, values.length - 1);
                  setState(() => _selectedIndex = index);
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
                        child: CustomPaint(painter: _LineChartPainter(values)),
                      ),
                    ),
                    if (values.isNotEmpty)
                      Positioned(
                        left: 10,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: _line),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0D101828),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Text(
                            '${DateFormat('dd MMM').format(dates[selected])}  •  Rs ${NumberFormat('#,##0').format(values[selected].round())}',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('dd MMM').format(dates.first),
                style: const TextStyle(fontSize: 8.5, color: _muted),
              ),
              const Text(
                'Click chart to inspect a day',
                style: TextStyle(fontSize: 8.5, color: _muted),
              ),
              Text(
                DateFormat('dd MMM').format(dates.last),
                style: const TextStyle(fontSize: 8.5, color: _muted),
              ),
            ],
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
                    '$_days-Day Sales',
                    'Rs ${NumberFormat('#,##0').format(total.round())}',
                  ),
                ),
                Expanded(child: _MiniStat('Orders', '$orderCount')),
                Expanded(
                  child: _MiniStat(
                    'Daily Avg',
                    'Rs ${NumberFormat('#,##0').format((total / _days).round())}',
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
            onTap: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Order #${sale.id}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _OrderDetailLine(
                          'Date',
                          DateFormat(
                            'dd MMM yyyy • h:mm a',
                          ).format(sale.createdAt),
                        ),
                        _OrderDetailLine(
                          'Table / Type',
                          sale.tableNumber?.isNotEmpty == true
                              ? 'Table ${sale.tableNumber}'
                              : sale.paymentMethod,
                        ),
                        _OrderDetailLine('Payment', sale.paymentMethod),
                        const Divider(height: 24),
                        const Text(
                          'Items',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...sale.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.quantity} × ${item.productName}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                Text(
                                  'Rs ${NumberFormat('#,##0').format((item.price * item.quantity).round())}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 24),
                        _OrderDetailLine(
                          'Total',
                          'Rs ${NumberFormat('#,##0').format(sale.total.round())}',
                          strong: true,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      context.go(AppRouter.sales);
                    },
                    child: const Text('Open Sales'),
                  ),
                ],
              ),
            ),
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

class _OrderDetailLine extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;

  const _OrderDetailLine(this.label, this.value, {this.strong = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: _muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: strong ? 13 : 10.5,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
        ],
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

class _Panel extends StatefulWidget {
  final String title;
  final Widget trailing, child;
  const _Panel({
    required this.title,
    required this.trailing,
    required this.child,
  });

  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> {
  bool minimized = false;

  Future<void> _maximize() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1250, maxHeight: 820),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _line)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.drag_indicator_rounded,
                        size: 18,
                        color: _purple,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      widget.trailing,
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Restore size',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(
                          Icons.close_fullscreen_rounded,
                          size: 18,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _cardDecoration(),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(Icons.drag_indicator_rounded, size: 16, color: _purple),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            widget.trailing,
            const SizedBox(width: 5),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: minimized ? 'Restore' : 'Minimize',
              onPressed: () => setState(() => minimized = !minimized),
              icon: Icon(
                minimized ? Icons.add_rounded : Icons.remove_rounded,
                size: 17,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Maximize',
              onPressed: _maximize,
              icon: const Icon(Icons.open_in_full_rounded, size: 16),
            ),
          ],
        ),
        if (!minimized) ...[
          const SizedBox(height: 8),
          Expanded(child: widget.child),
        ],
      ],
    ),
  );
}

class _DetailChip extends StatelessWidget {
  final String label, value;
  const _DetailChip(this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: _soft,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 9.5, color: _muted)),
        Text(
          value,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
        ),
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
