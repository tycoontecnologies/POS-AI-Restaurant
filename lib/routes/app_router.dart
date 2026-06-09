import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/models/table.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/subscription_provider.dart';
import 'package:pos/screens/auth/login_screen.dart';
import 'package:pos/screens/auth/signup_screen.dart';
import 'package:pos/screens/discounts_screen.dart';
import 'package:pos/screens/orders_screen.dart';
import 'package:pos/screens/payment_screen.dart';
import 'package:pos/screens/payment_success_screen.dart';
import 'package:pos/screens/pricing_screen.dart';
import 'package:pos/screens/purchase_return_screen.dart';
import 'package:pos/screens/sale_screen.dart';
import 'package:pos/screens/sale_return_screen.dart';
import 'package:pos/screens/table_order_screen.dart';
import 'package:provider/provider.dart';
import 'package:pos/screens/category_products_screen.dart';
import 'package:pos/providers/auth_provider.dart';
import '../screens/categories_screen.dart';
import '../screens/products_screen.dart';
import '../screens/staff_screen.dart';
import '../screens/attendance_screen.dart';
import '../screens/suppliers_screen.dart';
import '../screens/purchases_screen.dart';
import '../screens/store_out_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/ingredients_screen.dart';
import '../screens/customers_screen.dart';
import '../screens/table_management_screen.dart';
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
  static const String categoryProducts = '/category-products';
  static const String pricing = '/pricing';
  static const String payment = '/payment';
  static const String paymentSuccess = '/payment-success';
  static const String ingredients = '/ingredients';
  static const String settings = '/settings';
  static const String salesReturn = '/salesReturn';
  static const String storeOut = '/storeOut';
  static const String customers = '/customers';
  static const String discounts = '/discounts';
  static const String orders = '/orders';
  static const String tables = '/tables';

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
          final authProvider = Provider.of<AuthProvider>(context, listen: true);

          // Show loading screen while auth is initializing
          if (authProvider.isLoading) {
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          if (!authProvider.isAuthenticated) {
            return const LoginScreen();
          }
          return MainShell(child: child);
        },
        routes: [
          GoRoute(
            path: categories,
            name: 'categories',
            builder: (context, state) => const CategoriesScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: dashboard,
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: products,
            name: 'products',
            builder: (context, state) => const StoreScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: '/category-products/:categoryId',
            name: 'category-products',
            builder: (context, state) {
              final categoryId = state.pathParameters['categoryId']!;
              return CategoryProductsScreen(categoryName: categoryId);
            },
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: staff,
            name: 'staff',
            builder: (context, state) => const StaffScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: attendance,
            name: 'attendance',
            builder: (context, state) => const AttendanceScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: suppliers,
            name: 'suppliers',
            builder: (context, state) => const SuppliersScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: purchases,
            name: 'Operations',
            builder: (context, state) => const OperationScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: purchasesReturn,
            name: 'purchases-return',
            builder: (context, state) => const PurchaseReturnScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: sales,
            name: 'sales',
            builder: (context, state) => const SaleScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: salesReturn,
            name: 'sales-return',
            builder: (context, state) => const SaleReturnScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: storeOut,
            name: 'store-out',
            builder: (context, state) => const StoreOutScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: settings,
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: pricing,
            name: 'pricing',
            builder: (context, state) => const PricingScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: '$payment/:plan',
            name: 'payment',
            builder: (context, state) =>
                PaymentScreen(plan: state.pathParameters['plan']!),
          ),
          GoRoute(
            path: ingredients,
            name: 'ingredients',
            builder: (context, state) => const IngredientsScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: customers,
            name: 'customers',
            builder: (context, state) => const CustomersScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: discounts,
            name: 'Goodies',
            builder: (context, state) => const DiscountsScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: orders,
            name: 'orders',
            builder: (context, state) => const OrdersScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: paymentSuccess,
            name: 'payment-success',
            builder: (context, state) => const PaymentSuccessScreen(),
          ),
          GoRoute(
            path: tables,
            name: 'tables',
            builder: (context, state) => const TableManagementScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          // In your AppRouter configuration
          GoRoute(
            path: '/table-order/:tableId',
            builder: (context, state) {
              final table = state.extra as RestaurantTable;
              return TableOrderScreen(table: table);
            },
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Wait until auth is initialized
      if (authProvider.isLoading) return null;

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

  static Future<String?> _checkSubscription(
    BuildContext context,
    GoRouterState state,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );

    if (authProvider.isAuthenticated) {
      final hasValidSubscription = await subscriptionProvider
          .hasValidSubscription();

      // Allow access to pricing and payment routes
      final isPricingRoute = state.uri.path == AppRouter.pricing;
      final isPaymentRoute = state.uri.path.startsWith(AppRouter.payment);
      final isPaymentSuccessRoute = state.uri.path == AppRouter.paymentSuccess;

      if (!hasValidSubscription &&
          !isPricingRoute &&
          !isPaymentRoute &&
          !isPaymentSuccessRoute) {
        return AppRouter.pricing;
      }
      // If user has valid subscription and is on pricing page, redirect to dashboard
      if (hasValidSubscription && isPricingRoute) {
        return AppRouter.dashboard;
      }
    }

    return null;
  }

  // Role-based navigation items
static List<NavigationItem> getNavigationItems(UserRole role) {
  final allItems = [
    NavigationItem(
      icon: Icons.dashboard_rounded,
      label: 'Dashboard',
      route: dashboard,
      roles: [UserRole.admin, UserRole.staff, UserRole.kitchen],
    ),
    NavigationItem(
      icon: Icons.table_restaurant_rounded,
      label: 'Tables',
      route: tables,
      roles: [UserRole.admin, UserRole.staff],
    ),
    NavigationItem(
      icon: Icons.shopping_bag_rounded,
      label: 'Orders',
      route: orders,
      roles: [UserRole.admin, UserRole.staff],
    ),
    NavigationItem(
      icon: Icons.inventory_2_rounded,
      label: 'Inventory',
      route: products,
      roles: [UserRole.admin, UserRole.staff],
    ),
    NavigationItem(
      icon: Icons.people_alt_rounded,
      label: 'Customers',
      route: customers,
      roles: [UserRole.admin, UserRole.staff],
    ),
    NavigationItem(
      icon: Icons.receipt_long_rounded,
      label: 'Operations',
      route: purchases,
      roles: [UserRole.admin, UserRole.staff],
    ),
    NavigationItem(
      icon: Icons.kitchen_rounded,
      label: 'Recipe Management',
      route: ingredients,
      roles: [UserRole.admin],
    ),
    NavigationItem(
      icon: Icons.local_shipping_rounded,
      label: 'Suppliers',
      route: suppliers,
      roles: [UserRole.admin, UserRole.staff],
    ),
    NavigationItem(
      icon: Icons.psychology_alt_rounded,
      label: 'AI Assistant',
      route: dashboard,
      roles: [UserRole.admin],
    ),
    NavigationItem(
      icon: Icons.settings_rounded,
      label: 'Settings',
      route: settings,
      roles: [UserRole.admin],
    ),
  ];

  return allItems.where((item) => item.roles.contains(role)).toList();
} // <-- THIS BRACE WAS MISSING
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