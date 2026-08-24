import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/models/user.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/utils/app_colors.dart';

class RoleHomeScreen extends StatelessWidget {
  final UserModel user;
  const RoleHomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final config = _configFor(user.role);
    return Container(
      color: AppColors.backgroundLight,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(config.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.grey900)),
            const SizedBox(height: 4),
            Text('${user.name} • ${user.department.isEmpty ? config.subtitle : user.department} • ${user.branchName}', style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (_, c) {
              final width = c.maxWidth >= 1100 ? (c.maxWidth - 36) / 4 : c.maxWidth >= 760 ? (c.maxWidth - 24) / 3 : (c.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: config.actions.map((a) => _ActionCard(width: width, action: a)).toList(),
              );
            }),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.outlineLight)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Your Workspace', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.grey900)),
                const SizedBox(height: 5),
                Text(config.helper, style: const TextStyle(fontSize: 11, color: AppColors.grey500, height: 1.45)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  _RoleHomeConfig _configFor(UserRole role) {
    switch (role) {
      case UserRole.manager:
        return const _RoleHomeConfig('Manager Control', 'Management', 'Monitor restaurant operations and open the area that needs attention.', [
          _RoleAction('Tables', 'Open floor operations', Icons.table_restaurant_outlined, AppRouter.tables, AppColors.warning),
          _RoleAction('Billing', 'Bills and active orders', Icons.receipt_long_outlined, AppRouter.orders, AppColors.primary),
          _RoleAction('Inventory', 'Stock visibility', Icons.inventory_2_outlined, AppRouter.products, AppColors.info),
          _RoleAction('Sales', 'Restaurant sales', Icons.point_of_sale_outlined, AppRouter.sales, AppColors.success),
          _RoleAction('CRM', 'Customers', Icons.people_alt_outlined, AppRouter.customers, AppColors.secondary),
          _RoleAction('Operations', 'Purchases and returns', Icons.settings_suggest_outlined, AppRouter.purchases, AppColors.grey700),
        ]);
      case UserRole.cashier:
      case UserRole.staff:
        return const _RoleHomeConfig('Cashier Workspace', 'Cash Counter', 'Open a table, manage its order, print the bill and collect payment.', [
          _RoleAction('Tables', 'Open or resume tables', Icons.table_restaurant_outlined, AppRouter.tables, AppColors.warning),
          _RoleAction('Billing', 'Open bills', Icons.receipt_long_outlined, AppRouter.orders, AppColors.primary),
          _RoleAction('Sales', 'Completed sales', Icons.point_of_sale_outlined, AppRouter.sales, AppColors.success),
        ]);
      case UserRole.waiter:
        return const _RoleHomeConfig('Service Workspace', 'Service', 'Manage assigned tables, add items and send orders to the kitchen.', [
          _RoleAction('Tables', 'Open or resume tables', Icons.table_restaurant_outlined, AppRouter.tables, AppColors.warning),
          _RoleAction('Billing', 'Request or review bills', Icons.receipt_long_outlined, AppRouter.orders, AppColors.primary),
        ]);
      case UserRole.kitchen:
        return const _RoleHomeConfig('Kitchen Display', 'Kitchen', 'Track incoming KOTs and move them through making and ready stages.', [
          _RoleAction('Billing', 'Incoming orders / KOTs', Icons.soup_kitchen_outlined, AppRouter.orders, AppColors.warning),
          _RoleAction('Recipes', 'Recipe reference', Icons.menu_book_outlined, AppRouter.ingredients, AppColors.primary),
        ]);
      case UserRole.operations:
        return const _RoleHomeConfig('Operations Workspace', 'Operations', 'Control purchases, suppliers, stock movement and recipe operations.', [
          _RoleAction('Operations', 'Purchases and returns', Icons.settings_suggest_outlined, AppRouter.purchases, AppColors.primary),
          _RoleAction('Inventory', 'Products and stock', Icons.inventory_2_outlined, AppRouter.products, AppColors.info),
          _RoleAction('Vendors', 'Suppliers', Icons.local_shipping_outlined, AppRouter.suppliers, AppColors.success),
          _RoleAction('Recipes', 'Recipe management', Icons.menu_book_outlined, AppRouter.ingredients, AppColors.warning),
        ]);
      case UserRole.accounts:
        return const _RoleHomeConfig('Accounts Workspace', 'Accounts', 'Review sales, purchases, returns and financial activity.', [
          _RoleAction('Sales', 'Sales transactions', Icons.point_of_sale_outlined, AppRouter.sales, AppColors.success),
          _RoleAction('Returns', 'Sales returns', Icons.assignment_return_outlined, AppRouter.salesReturn, AppColors.warning),
          _RoleAction('Operations', 'Purchases', Icons.receipt_long_outlined, AppRouter.purchases, AppColors.primary),
          _RoleAction('Vendors', 'Supplier ledgers', Icons.local_shipping_outlined, AppRouter.suppliers, AppColors.info),
        ]);
      case UserRole.inventory:
        return const _RoleHomeConfig('Inventory Workspace', 'Store', 'Manage products, stock, receiving and supplier-linked inventory activity.', [
          _RoleAction('Inventory', 'Products and quantities', Icons.inventory_2_outlined, AppRouter.products, AppColors.info),
          _RoleAction('Operations', 'Receiving and purchases', Icons.receipt_long_outlined, AppRouter.purchases, AppColors.primary),
          _RoleAction('Vendors', 'Suppliers', Icons.local_shipping_outlined, AppRouter.suppliers, AppColors.success),
        ]);
      case UserRole.delivery:
        return const _RoleHomeConfig('Delivery Workspace', 'Delivery', 'Track delivery orders and customer information.', [
          _RoleAction('Billing', 'Delivery orders', Icons.delivery_dining_outlined, AppRouter.orders, AppColors.warning),
          _RoleAction('CRM', 'Delivery customers', Icons.people_alt_outlined, AppRouter.customers, AppColors.primary),
        ]);
      case UserRole.reception:
        return const _RoleHomeConfig('Reception Workspace', 'Front Desk', 'See floor availability and manage guest-facing table activity.', [
          _RoleAction('Tables', 'Availability and tables', Icons.event_seat_outlined, AppRouter.tables, AppColors.success),
          _RoleAction('CRM', 'Customers', Icons.people_alt_outlined, AppRouter.customers, AppColors.primary),
        ]);
      case UserRole.auditor:
        return const _RoleHomeConfig('Owner / Auditor View', 'Audit', 'Read-only access to the restaurant areas that matter most.', [
          _RoleAction('Sales', 'Sales performance', Icons.point_of_sale_outlined, AppRouter.sales, AppColors.success),
          _RoleAction('Inventory', 'Inventory position', Icons.inventory_2_outlined, AppRouter.products, AppColors.info),
          _RoleAction('Operations', 'Purchases and activity', Icons.receipt_long_outlined, AppRouter.purchases, AppColors.primary),
        ]);
      default:
        return const _RoleHomeConfig('Restaurant Workspace', 'Restaurant', 'Open the operational area assigned to your account.', [
          _RoleAction('Tables', 'Restaurant floor', Icons.table_restaurant_outlined, AppRouter.tables, AppColors.warning),
          _RoleAction('Billing', 'Orders and bills', Icons.receipt_long_outlined, AppRouter.orders, AppColors.primary),
        ]);
    }
  }
}

class _ActionCard extends StatelessWidget {
  final double width;
  final _RoleAction action;
  const _ActionCard({required this.width, required this.action});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(13),
    child: InkWell(
      onTap: () => context.go(action.route),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: width,
        height: 108,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.outlineLight)),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: action.accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(11)), child: Icon(action.icon, color: action.accent, size: 21)),
          const SizedBox(width: 12),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(action.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.grey900)),
            const SizedBox(height: 4),
            Text(action.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.grey500)),
          ])),
          const Icon(Icons.arrow_forward_rounded, size: 17, color: AppColors.grey400),
        ]),
      ),
    ),
  );
}

class _RoleHomeConfig {
  final String title;
  final String subtitle;
  final String helper;
  final List<_RoleAction> actions;
  const _RoleHomeConfig(this.title, this.subtitle, this.helper, this.actions);
}

class _RoleAction {
  final String label;
  final String subtitle;
  final IconData icon;
  final String route;
  final Color accent;
  const _RoleAction(this.label, this.subtitle, this.icon, this.route, this.accent);
}
