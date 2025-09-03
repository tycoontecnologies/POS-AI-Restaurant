import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/models/user.dart';
import 'package:pos/screens/auth/login_screen.dart';
import 'package:pos/screens/auth/signup_screen.dart';
import 'package:pos/screens/purchase_return_screen.dart';
import 'package:pos/screens/sale_record_screen.dart';
import 'package:pos/screens/sale_return_screen.dart';
import 'package:provider/provider.dart';
import 'package:pos/screens/category_products_screen.dart';
import 'package:pos/providers/auth_provider.dart';
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
  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String categories = '/categories';
  static const String products = '/products';
  static const String staff = '/staff';
  static const String attendance = '/attendance';
  static const String suppliers = '/suppliers';
  static const String purchases = '/purchases';
  static const String purchasesReturn = '/purchases-return';
  static const String sales = '/sales';
  static const String salesReturn = '/sales-return';
  static const String drafts = '/drafts';
  static const String storeOut = '/store-out';
  static const String settings = '/settings';
  static const String salesRecord = '/sales-record';
  static const String categoryProducts = '/category-products';

  static final GoRouter router = GoRouter(
    initialLocation: login,
    routes: [
      GoRoute(
        path: login,
        name: 'login',
        builder: (context, state) => LoginScreen(
          onSignUpPressed: () => GoRouter.of(context).goNamed('signup'),
        ),
      ),
      GoRoute(
        path: signup,
        name: 'signup',
        builder: (context, state) => SignUpScreen(
          onLoginPressed: () => GoRouter.of(context).goNamed('login'),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          if (!authProvider.isAuthenticated) {
            return const LoginScreen();
          }
          return MainShell(child: child);
        },
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
            path: '/category-products/:categoryId',
            name: 'category-products',
            builder: (context, state) {
              final categoryId = state.pathParameters['categoryId']!;
              return CategoryProductsScreen(categoryName: categoryId);
            },
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
            path: purchasesReturn,
            name: 'purchases-return',
            builder: (context, state) => const PurchaseReturnScreen(),
          ),
          GoRoute(
            path: sales,
            name: 'sales',
            builder: (context, state) => const SalesScreen(),
          ),
          GoRoute(
            path: salesRecord,
            name: 'sales-record',
            builder: (context, state) => const SalesTableScreen(),
          ),
          GoRoute(
            path: salesReturn,
            name: 'sales-return',
            builder: (context, state) => const SaleReturnScreen(),
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
    redirect: (context, state) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isAuthenticated = authProvider.isAuthenticated;
      final isLoginRoute = state.matchedLocation == login;
      final isSignupRoute = state.matchedLocation == signup;

      if (!isAuthenticated && !isLoginRoute && !isSignupRoute) {
        return login;
      }

      if (isAuthenticated && (isLoginRoute || isSignupRoute)) {
        return dashboard;
      }

      return null;
    },
  );

  // Role-based navigation items
  static List<NavigationItem> getNavigationItems(UserRole role) {
    final allItems = [
      NavigationItem(
        icon: Icons.dashboard,
        label: 'Dashboard',
        route: dashboard,
        roles: [UserRole.admin, UserRole.staff, UserRole.kitchen],
      ),
      NavigationItem(
        icon: Icons.category,
        label: 'Categories',
        route: categories,
        roles: [UserRole.admin, UserRole.staff],
      ),
      NavigationItem(
        icon: Icons.inventory_2,
        label: 'Products',
        route: products,
        roles: [UserRole.admin, UserRole.staff],
      ),
      NavigationItem(
        icon: Icons.group,
        label: 'Staff',
        route: staff,
        roles: [UserRole.admin],
      ),
      NavigationItem(
        icon: Icons.access_time,
        label: 'Attendance',
        route: attendance,
        roles: [UserRole.admin, UserRole.staff],
      ),
      NavigationItem(
        icon: Icons.local_shipping,
        label: 'Suppliers',
        route: suppliers,
        roles: [UserRole.admin, UserRole.staff],
      ),
      NavigationItem(
        icon: Icons.shopping_cart,
        label: 'Purchases',
        route: purchases,
        roles: [UserRole.admin, UserRole.staff],
      ),
      NavigationItem(
        icon: Icons.keyboard_return_sharp,
        label: 'Purchases return',
        route: purchasesReturn,
        roles: [UserRole.admin, UserRole.staff],
      ),
      // NavigationItem(
      //   icon: Icons.point_of_sale,
      //   label: 'sales',
      //   route: sales,
      //   roles: [UserRole.admin, UserRole.staff, UserRole.user],
      // ),
      NavigationItem(
        icon: Icons.point_of_sale,
        label: 'Sales',
        route: salesRecord,
        roles: [UserRole.admin, UserRole.staff, UserRole.user],
      ),
      NavigationItem(
        icon: Icons.point_of_sale,
        label: 'Sales Return',
        route: salesReturn,
        roles: [UserRole.admin, UserRole.staff, UserRole.user],
      ),
      NavigationItem(
        icon: Icons.archive_outlined,
        label: 'Drafts',
        route: drafts,
        roles: [UserRole.admin, UserRole.staff],
      ),
      NavigationItem(
        icon: Icons.storefront_outlined,
        label: 'Store Out',
        route: storeOut,
        roles: [UserRole.admin, UserRole.staff],
      ),
      NavigationItem(
        icon: Icons.settings,
        label: 'Settings',
        route: settings,
        roles: [UserRole.admin],
      ),
    ];

    return allItems.where((item) => item.roles.contains(role)).toList();
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final String route;
  final List<UserRole> roles;

  const NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.roles,
  });
}
