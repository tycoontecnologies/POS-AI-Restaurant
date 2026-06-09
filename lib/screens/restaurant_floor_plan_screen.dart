import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/components/premium/premium_restaurant_ui.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/table_order_provider.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:pos/utils/app_spacing.dart';
import 'package:provider/provider.dart';

class RestaurantFloorPlanScreen extends StatefulWidget {
  const RestaurantFloorPlanScreen({super.key});

  @override
  State<RestaurantFloorPlanScreen> createState() =>
      _RestaurantFloorPlanScreenState();
}

class _RestaurantFloorPlanScreenState extends State<RestaurantFloorPlanScreen> {
  static const List<String> _zones = [
    'Main Hall',
    'Family Hall',
    'VIP Hall',
    'Outdoor',
    'Rooftop',
    'Take Away',
    'Delivery',
  ];

  String _selectedZone = _zones.first;
  bool _ordersHydrated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tableProvider = context.read<TableProvider>();
      if (tableProvider.tables.isEmpty && !tableProvider.isLoading) {
        await tableProvider.loadTables();
      }
      await _hydrateVisibleOrders();
    });
  }

  Future<void> _hydrateVisibleOrders() async {
    if (_ordersHydrated || !mounted) return;
    final tableProvider = context.read<TableProvider>();
    final tableOrderProvider = context.read<TableOrderProvider>();
    for (final table in tableProvider.tables) {
      await tableOrderProvider.loadTableOrder(table.id);
    }
    if (mounted) {
      setState(() => _ordersHydrated = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumRestaurantScaffold(
      eyebrow: 'Luxury restaurant control room',
      title: 'Restaurant Floor',
      subtitle:
          'Live floor orchestration for dine-in, VIP, outdoor, takeaway, and delivery service.',
      actions: [
        PremiumActionButton(
          label: 'KDS',
          icon: Icons.soup_kitchen_outlined,
          onPressed: () => context.go(AppRouter.kitchenDisplay),
          filled: false,
          color: AppColors.restaurantAmber,
        ),
        PremiumActionButton(
          label: 'Manage tables',
          icon: Icons.table_restaurant_outlined,
          onPressed: () => context.go(AppRouter.tables),
        ),
      ],
      child: Consumer2<TableProvider, TableOrderProvider>(
        builder: (context, tableProvider, orderProvider, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 900;
              final tables = tableProvider.tables;
              final visibleTables = tables
                  .where((table) => _zoneForTable(table) == _selectedZone)
                  .toList();
              final totalRevenue = tables.fold<double>(0, (sum, table) {
                final items = orderProvider.getOrderForTable(table.id);
                return sum +
                    items.fold<double>(
                      0,
                      (itemSum, item) => itemSum + item.totalPrice,
                    );
              });
              final occupied = tables
                  .where((table) => _tableState(table, orderProvider).isActive)
                  .length;
              final attention = tables
                  .where(
                    (table) =>
                        _tableState(table, orderProvider).label ==
                        'Attention Required',
                  )
                  .length;

              final metrics = [
                PremiumMetric(
                  label: 'Occupied',
                  value: '$occupied/${tables.length}',
                  icon: Icons.event_seat_outlined,
                  color: AppColors.restaurantIndigo,
                ),
                PremiumMetric(
                  label: 'Open checks',
                  value: 'Rs ${totalRevenue.toStringAsFixed(0)}',
                  icon: Icons.receipt_long_outlined,
                ),
                PremiumMetric(
                  label: 'Attention',
                  value: '$attention',
                  icon: Icons.notifications_active_outlined,
                  color: AppColors.restaurantCrimson,
                ),
              ];

              final metricsRow = compact
                  ? Column(
                      children: [
                        for (final metric in metrics) ...[
                          metric,
                          if (metric != metrics.last)
                            const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    )
                  : Row(
                      children: [
                        for (final metric in metrics) ...[
                          Expanded(child: metric),
                          if (metric != metrics.last)
                            const SizedBox(width: AppSpacing.md),
                        ],
                      ],
                    );

              final floorCanvas = PremiumGlassPanel(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: tableProvider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.restaurantGold,
                        ),
                      )
                    : tables.isEmpty
                        ? PremiumEmptyState(
                            icon: Icons.table_bar_outlined,
                            title: 'Design your first dining room',
                            message:
                                'Create tables from Manage tables, then this screen becomes your live operational floor plan.',
                          )
                        : _FloorCanvas(
                            zone: _selectedZone,
                            tables: visibleTables,
                            stateForTable: (table) =>
                                _tableState(table, orderProvider),
                            onTableTap: (table) => context.go(
                              '${AppRouter.ordering}/${table.id}',
                              extra: table,
                            ),
                          ),
              );

              final zoneRail = _ZoneRail(
                selectedZone: _selectedZone,
                onZoneSelected: (zone) => setState(() => _selectedZone = zone),
                horizontal: compact,
              );

              return Column(
                children: [
                  metricsRow,
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: compact
                        ? Column(
                            children: [
                              SizedBox(height: 112, child: zoneRail),
                              const SizedBox(height: AppSpacing.md),
                              Expanded(child: floorCanvas),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(width: 220, child: zoneRail),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(child: floorCanvas),
                            ],
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _zoneForTable(RestaurantTable table) {
    final index = table.tableNumber.codeUnits.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    return _zones[index % 5];
  }

  _OperationalTableState _tableState(
    RestaurantTable table,
    TableOrderProvider orderProvider,
  ) {
    final items = orderProvider.getOrderForTable(table.id);
    final info = orderProvider.getOrderInfo(table.id);
    final total = items.fold<double>(0, (sum, item) => sum + item.totalPrice);
    final orderCount = items.fold<int>(0, (sum, item) => sum + item.quantity);
    final createdAt = _readDate(info['createdAt']) ?? table.createdAt;
    final elapsed = DateTime.now().difference(createdAt);

    if (table.status == TableStatus.empty && items.isEmpty) {
      return _OperationalTableState(
        label: 'Available',
        color: AppColors.restaurantEmerald,
        waiter: 'Unassigned',
        billAmount: 0,
        orderCount: 0,
        elapsed: Duration.zero,
        isActive: false,
      );
    }

    if (table.status == TableStatus.cleared) {
      return _OperationalTableState(
        label: 'Reserved',
        color: AppColors.restaurantMuted,
        waiter: _waiterFor(table),
        billAmount: total,
        orderCount: orderCount,
        elapsed: elapsed,
        isActive: false,
      );
    }

    if (table.status == TableStatus.served) {
      return _OperationalTableState(
        label: 'Served',
        color: AppColors.restaurantEmerald,
        waiter: _waiterFor(table),
        billAmount: total,
        orderCount: orderCount,
        elapsed: elapsed,
        isActive: true,
      );
    }

    if (elapsed.inMinutes >= 28) {
      return _OperationalTableState(
        label: 'Attention Required',
        color: AppColors.restaurantCrimson,
        waiter: _waiterFor(table),
        billAmount: total,
        orderCount: orderCount,
        elapsed: elapsed,
        isActive: true,
      );
    }

    if (elapsed.inMinutes >= 18) {
      return _OperationalTableState(
        label: 'Ready',
        color: AppColors.restaurantAmber,
        waiter: _waiterFor(table),
        billAmount: total,
        orderCount: orderCount,
        elapsed: elapsed,
        isActive: true,
      );
    }

    if (items.isNotEmpty && elapsed.inMinutes >= 8) {
      return _OperationalTableState(
        label: 'Preparing',
        color: AppColors.restaurantPurple,
        waiter: _waiterFor(table),
        billAmount: total,
        orderCount: orderCount,
        elapsed: elapsed,
        isActive: true,
      );
    }

    return _OperationalTableState(
      label: items.isEmpty ? 'Waiting' : 'Ordered',
      color: items.isEmpty
          ? AppColors.restaurantIndigo
          : AppColors.restaurantIndigo,
      waiter: _waiterFor(table),
      billAmount: total,
      orderCount: orderCount,
      elapsed: elapsed,
      isActive: true,
    );
  }

  DateTime? _readDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  String _waiterFor(RestaurantTable table) {
    const waiters = ['Ayan', 'Sara', 'Usman', 'Mina', 'Omar', 'Zara'];
    final index = table.tableNumber.codeUnits.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    return waiters[index % waiters.length];
  }
}

class _ZoneRail extends StatelessWidget {
  final String selectedZone;
  final ValueChanged<String> onZoneSelected;
  final bool horizontal;

  const _ZoneRail({
    required this.selectedZone,
    required this.onZoneSelected,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumGlassPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionTitle(
            title: 'Service areas',
            subtitle: 'Switch the floor in one tap.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ListView.separated(
              scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
              itemCount: _RestaurantFloorPlanScreenState._zones.length,
              separatorBuilder: (_, __) => SizedBox(
                width: horizontal ? AppSpacing.sm : 0,
                height: horizontal ? 0 : AppSpacing.sm,
              ),
              itemBuilder: (context, index) {
                final zone = _RestaurantFloorPlanScreenState._zones[index];
                return _ZoneButton(
                  label: zone,
                  selected: selectedZone == zone,
                  onTap: () => onZoneSelected(zone),
                );
              },
            ),
          ),
          if (!horizontal) ...[
            const SizedBox(height: AppSpacing.md),
            PremiumStatusPill(
              label: 'Live service',
              color: AppColors.restaurantEmerald,
              icon: Icons.circle,
            ),
          ],
        ],
      ),
    );
  }
}

class _ZoneButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ZoneButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm2,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.restaurantGold.withOpacity(0.16)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: selected
                ? AppColors.restaurantGold.withOpacity(0.5)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _iconForZone(label),
              color: selected
                  ? AppColors.restaurantGold
                  : AppColors.restaurantMuted,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppColors.restaurantInk
                      : AppColors.restaurantMuted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForZone(String zone) {
    switch (zone) {
      case 'VIP Hall':
        return Icons.workspace_premium_outlined;
      case 'Outdoor':
        return Icons.park_outlined;
      case 'Rooftop':
        return Icons.roofing_outlined;
      case 'Take Away':
        return Icons.takeout_dining_outlined;
      case 'Delivery':
        return Icons.delivery_dining_outlined;
      case 'Family Hall':
        return Icons.family_restroom_outlined;
      default:
        return Icons.dinner_dining_outlined;
    }
  }
}

class _FloorCanvas extends StatelessWidget {
  final String zone;
  final List<RestaurantTable> tables;
  final _OperationalTableState Function(RestaurantTable table) stateForTable;
  final ValueChanged<RestaurantTable> onTableTap;

  const _FloorCanvas({
    required this.zone,
    required this.tables,
    required this.stateForTable,
    required this.onTableTap,
  });

  @override
  Widget build(BuildContext context) {
    if (zone == 'Take Away' || zone == 'Delivery') {
      return _ServiceStation(zone: zone);
    }

    if (tables.isEmpty) {
      return PremiumEmptyState(
        icon: Icons.chair_alt_outlined,
        title: '$zone is calm',
        message:
            'No tables are assigned to this area yet. Add or rename tables to populate this room.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 980
            ? 4
            : constraints.maxWidth > 720
                ? 3
                : 2;
        return GridView.builder(
          itemCount: tables.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.lg,
            crossAxisSpacing: AppSpacing.lg,
            childAspectRatio: 1.18,
          ),
          itemBuilder: (context, index) {
            final table = tables[index];
            return _LiveTableTile(
              table: table,
              state: stateForTable(table),
              onTap: () => onTableTap(table),
            );
          },
        );
      },
    );
  }
}

class _LiveTableTile extends StatefulWidget {
  final RestaurantTable table;
  final _OperationalTableState state;
  final VoidCallback onTap;

  const _LiveTableTile({
    required this.table,
    required this.state,
    required this.onTap,
  });

  @override
  State<_LiveTableTile> createState() => _LiveTableTileState();
}

class _LiveTableTileState extends State<_LiveTableTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
      lowerBound: 0.45,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shouldPulse = widget.state.label == 'Attention Required';
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = shouldPulse ? _pulseController.value : 0.75;
        return InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.055),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              border: Border.all(color: widget.state.color.withOpacity(0.42)),
              boxShadow: [
                BoxShadow(
                  color: widget.state.color.withOpacity(0.34 * pulse),
                  blurRadius: 28,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PremiumStatusPill(
                      label: widget.state.label,
                      color: widget.state.color,
                    ),
                    Text(
                      _formatElapsed(widget.state.elapsed),
                      style: const TextStyle(
                        color: AppColors.restaurantMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Center(
                  child: CustomPaint(
                    painter: _RestaurantTablePainter(
                      color: widget.state.color,
                      seats: widget.table.numberOfSeats,
                      round: widget.table.numberOfSeats <= 4,
                    ),
                    child: SizedBox(
                      width: 124,
                      height: 90,
                      child: Center(
                        child: Text(
                          widget.table.tableNumber,
                          style: const TextStyle(
                            color: AppColors.restaurantInk,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    _TinyTableMetric(
                      label: 'Seats',
                      value: '${widget.table.numberOfSeats}',
                    ),
                    _TinyTableMetric(
                      label: 'Waiter',
                      value: widget.state.waiter,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _TinyTableMetric(
                      label: 'Orders',
                      value: '${widget.state.orderCount}',
                    ),
                    _TinyTableMetric(
                      label: 'Bill',
                      value: 'Rs ${widget.state.billAmount.toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatElapsed(Duration duration) {
    if (duration == Duration.zero) return '00m';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '${hours}h ${minutes}m' : '${duration.inMinutes}m';
  }
}

class _TinyTableMetric extends StatelessWidget {
  final String label;
  final String value;

  const _TinyTableMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.restaurantMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.restaurantInk,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantTablePainter extends CustomPainter {
  final Color color;
  final int seats;
  final bool round;

  _RestaurantTablePainter({
    required this.color,
    required this.seats,
    required this.round,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final seatPaint = Paint()
      ..color = color.withOpacity(0.24)
      ..style = PaintingStyle.fill;
    final tablePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withOpacity(0.48), color.withOpacity(0.13)],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = color.withOpacity(0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final center = Offset(size.width / 2, size.height / 2);
    final seatCount = seats.clamp(2, 10);
    for (var i = 0; i < seatCount; i++) {
      final angle = (math.pi * 2 / seatCount) * i;
      final seatCenter = center + Offset(math.cos(angle) * 52, math.sin(angle) * 34);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: seatCenter, width: 18, height: 12),
          const Radius.circular(6),
        ),
        seatPaint,
      );
    }

    if (round) {
      canvas.drawOval(
        Rect.fromCenter(center: center, width: 76, height: 58),
        tablePaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: center, width: 76, height: 58),
        borderPaint,
      );
    } else {
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 88, height: 56),
        const Radius.circular(18),
      );
      canvas.drawRRect(rect, tablePaint);
      canvas.drawRRect(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RestaurantTablePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.seats != seats ||
        oldDelegate.round != round;
  }
}

class _ServiceStation extends StatelessWidget {
  final String zone;

  const _ServiceStation({required this.zone});

  @override
  Widget build(BuildContext context) {
    final isDelivery = zone == 'Delivery';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: PremiumGlassPanel(
          backgroundColor: Colors.white.withOpacity(0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDelivery
                    ? Icons.delivery_dining_outlined
                    : Icons.takeout_dining_outlined,
                color: AppColors.restaurantGold,
                size: 54,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '$zone command station',
                style: const TextStyle(
                  color: AppColors.restaurantInk,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Phase 1 keeps takeaway and delivery visible from the floor. Dedicated order queues can plug into this station without changing the premium shell.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.restaurantMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationalTableState {
  final String label;
  final Color color;
  final String waiter;
  final double billAmount;
  final int orderCount;
  final Duration elapsed;
  final bool isActive;

  const _OperationalTableState({
    required this.label,
    required this.color,
    required this.waiter,
    required this.billAmount,
    required this.orderCount,
    required this.elapsed,
    required this.isActive,
  });
}
