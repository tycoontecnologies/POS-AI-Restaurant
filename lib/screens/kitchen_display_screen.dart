import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/components/premium/premium_restaurant_ui.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:pos/utils/app_spacing.dart';
import 'package:provider/provider.dart';

class KitchenDisplayScreen extends StatelessWidget {
  const KitchenDisplayScreen({super.key});

  static const List<_KdsColumnSpec> _columns = [
    _KdsColumnSpec('New', AppColors.restaurantIndigo, Icons.fiber_new_outlined),
    _KdsColumnSpec('Preparing', AppColors.restaurantPurple, Icons.soup_kitchen_outlined),
    _KdsColumnSpec('Ready', AppColors.restaurantAmber, Icons.notifications_active_outlined),
    _KdsColumnSpec('Served', AppColors.restaurantEmerald, Icons.check_circle_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final vendorId = context.watch<AuthProvider>().currentUser?.id;

    return PremiumRestaurantScaffold(
      eyebrow: 'Kitchen display system',
      title: 'Live Kitchen Tickets',
      subtitle:
          'A kanban command surface for new, preparing, ready, and served orders with urgency built in.',
      actions: [
        PremiumActionButton(
          label: 'Floor',
          icon: Icons.grid_view_rounded,
          filled: false,
          onPressed: () => context.go(AppRouter.floorPlan),
        ),
      ],
      child: vendorId == null
          ? const PremiumEmptyState(
              icon: Icons.lock_outline,
              title: 'Sign in required',
              message: 'Kitchen orders load once the restaurant account is active.',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('vendors')
                  .doc(vendorId)
                  .collection('tableOrders')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.restaurantGold,
                    ),
                  );
                }

                final tickets = snapshot.data?.docs
                        .map((doc) => _KitchenTicket.fromDoc(doc))
                        .where((ticket) => ticket.items.isNotEmpty)
                        .toList() ??
                    [];

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _columns.map((column) {
                    final columnTickets = tickets
                        .where((ticket) => ticket.stage == column.title)
                        .toList();
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: column.title == _columns.last.title
                              ? 0
                              : AppSpacing.md,
                        ),
                        child: _KdsColumn(
                          spec: column,
                          tickets: columnTickets,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
    );
  }
}

class _KdsColumn extends StatelessWidget {
  final _KdsColumnSpec spec;
  final List<_KitchenTicket> tickets;

  const _KdsColumn({required this.spec, required this.tickets});

  @override
  Widget build(BuildContext context) {
    return PremiumGlassPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: spec.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(spec.icon, color: spec.color, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  spec.title,
                  style: const TextStyle(
                    color: AppColors.restaurantInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              PremiumStatusPill(label: '${tickets.length}', color: spec.color),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: tickets.isEmpty
                ? Center(
                    child: Text(
                      'No ${spec.title.toLowerCase()} tickets',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.restaurantMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: tickets.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      return _KitchenTicketCard(
                        ticket: tickets[index],
                        color: spec.color,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _KitchenTicketCard extends StatelessWidget {
  final _KitchenTicket ticket;
  final Color color;

  const _KitchenTicketCard({required this.ticket, required this.color});

  @override
  Widget build(BuildContext context) {
    final urgent = ticket.elapsed.inMinutes >= 18;
    final cardColor = urgent ? AppColors.restaurantCrimson : color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: cardColor.withOpacity(0.42)),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(urgent ? 0.34 : 0.16),
            blurRadius: urgent ? 30 : 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${ticket.orderNumber}',
                  style: const TextStyle(
                    color: AppColors.restaurantInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              PremiumStatusPill(
                label: urgent ? 'Late ${_elapsed(ticket.elapsed)}' : _elapsed(ticket.elapsed),
                color: cardColor,
                icon: urgent ? Icons.priority_high_rounded : Icons.timer_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Table ${ticket.tableLabel}',
            style: const TextStyle(
              color: AppColors.restaurantGold,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final item in ticket.items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cardColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      '${item.quantity}',
                      style: TextStyle(
                        color: cardColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        color: AppColors.restaurantInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (ticket.note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.restaurantGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Text(
                ticket.note,
                style: const TextStyle(
                  color: AppColors.restaurantGoldSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              PremiumStatusPill(
                label: ticket.priority,
                color: urgent ? AppColors.restaurantCrimson : color,
                icon: Icons.local_fire_department_outlined,
              ),
              const Spacer(),
              const Text(
                'Tap status in backend',
                style: TextStyle(
                  color: AppColors.restaurantMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _elapsed(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    return '${duration.inMinutes}m';
  }
}

class _KitchenTicket {
  final String id;
  final String orderNumber;
  final String tableLabel;
  final String stage;
  final Duration elapsed;
  final List<_KitchenTicketItem> items;
  final String note;
  final String priority;

  const _KitchenTicket({
    required this.id,
    required this.orderNumber,
    required this.tableLabel,
    required this.stage,
    required this.elapsed,
    required this.items,
    required this.note,
    required this.priority,
  });

  factory _KitchenTicket.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdAt = _readDate(data['createdAt']) ?? DateTime.now();
    final elapsed = DateTime.now().difference(createdAt);
    final stage = _stageFromData(data, elapsed);
    final rawItems = List<Map<String, dynamic>>.from(data['items'] ?? []);
    final totalQuantity = rawItems.fold<int>(
      0,
      (sum, item) => sum + ((item['quantity'] ?? 0) as int),
    );

    return _KitchenTicket(
      id: doc.id,
      orderNumber: doc.id.length > 6 ? doc.id.substring(0, 6).toUpperCase() : doc.id,
      tableLabel: data['tableNumber']?.toString() ?? data['tableId']?.toString() ?? doc.id,
      stage: stage,
      elapsed: elapsed,
      items: rawItems
          .map(
            (item) => _KitchenTicketItem(
              name: item['productName']?.toString() ?? 'Menu item',
              quantity: item['quantity'] ?? 1,
            ),
          )
          .toList(),
      note: data['note']?.toString() ?? '',
      priority: elapsed.inMinutes >= 18 || totalQuantity >= 6 ? 'High priority' : 'Normal',
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static String _stageFromData(Map<String, dynamic> data, Duration elapsed) {
    final status = data['kitchenStatus']?.toString().toLowerCase();
    switch (status) {
      case 'preparing':
        return 'Preparing';
      case 'ready':
        return 'Ready';
      case 'served':
        return 'Served';
      case 'new':
        return 'New';
    }
    if (elapsed.inMinutes >= 22) return 'Ready';
    if (elapsed.inMinutes >= 8) return 'Preparing';
    return 'New';
  }
}

class _KitchenTicketItem {
  final String name;
  final int quantity;

  const _KitchenTicketItem({required this.name, required this.quantity});
}

class _KdsColumnSpec {
  final String title;
  final Color color;
  final IconData icon;

  const _KdsColumnSpec(this.title, this.color, this.icon);
}
