import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/categories_screen.dart';
import '../screens/products_screen.dart';
import '../screens/staff_screen.dart';
import '../screens/attendance_screen.dart';
import '../screens/suppliers_screen.dart';
import '../screens/purchases_screen.dart';
import '../screens/sales_screen.dart';
import '../screens/drafts_screen.dart';
import '../screens/store_out_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/dashboard_screen.dart';
import '../components/layout/main_shell.dart';

class AppRouter {
  static const String dashboard = '/dashboard';
  static const String categories = '/categories';
  static const String products = '/products';
  static const String staff = '/staff';
  static const String attendance = '/attendance';
  static const String suppliers = '/suppliers';
  static const String purchases = '/purchases';
  static const String sales = '/sales';
  static const String drafts = '/drafts';
  static const String storeOut = '/store-out';
  static const String settings = '/settings';

  static final GoRouter router = GoRouter(
    initialLocation: dashboard,
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: dashboard,
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: categories,
            name: 'categories',
            builder: (context, state) => const CategoriesScreen(),
          ),
          GoRoute(
            path: products,
            name: 'products',
            builder: (context, state) => const ProductsScreen(),
          ),
          GoRoute(
            path: staff,
            name: 'staff',
            builder: (context, state) => const StaffScreen(),
          ),
          GoRoute(
            path: attendance,
            name: 'attendance',
            builder: (context, state) => const AttendanceScreen(),
          ),
          GoRoute(
            path: suppliers,
            name: 'suppliers',
            builder: (context, state) => const SuppliersScreen(),
          ),
          GoRoute(
            path: purchases,
            name: 'purchases',
            builder: (context, state) => const PurchasesScreen(),
          ),
          GoRoute(
            path: sales,
            name: 'sales',
            builder: (context, state) => const SalesScreen(),
          ),
          GoRoute(
            path: drafts,
            name: 'drafts',
            builder: (context, state) => const DraftsScreen(),
          ),
          GoRoute(
            path: storeOut,
            name: 'store-out',
            builder: (context, state) => const StoreOutScreen(),
          ),
          GoRoute(
            path: settings,
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );

  static List<NavigationItem> get navigationItems => [
    NavigationItem(icon: Icons.dashboard, label: 'dashboard', route: dashboard),
    NavigationItem(
      icon: Icons.category,
      label: 'categories',
      route: categories,
    ),
    NavigationItem(icon: Icons.inventory_2, label: 'products', route: products),
    NavigationItem(icon: Icons.group, label: 'staff', route: staff),
    NavigationItem(
      icon: Icons.access_time,
      label: 'attendance',
      route: attendance,
    ),
    NavigationItem(
      icon: Icons.local_shipping,
      label: 'suppliers',
      route: suppliers,
    ),
    NavigationItem(
      icon: Icons.shopping_cart,
      label: 'purchases',
      route: purchases,
    ),
    NavigationItem(icon: Icons.point_of_sale, label: 'sales', route: sales),
    NavigationItem(
      icon: Icons.archive_outlined,
      label: 'drafts',
      route: drafts,
    ),
    NavigationItem(
      icon: Icons.storefront_outlined,
      label: 'storeOut',
      route: storeOut,
    ),
    NavigationItem(icon: Icons.settings, label: 'settings', route: settings),
  ];
}

class NavigationItem {
  final IconData icon;
  final String label;
  final String route;

  const NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}
