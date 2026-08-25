import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/models/table.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/subscription_provider.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/screens/auth/login_screen.dart';
import 'package:pos/screens/auth/signup_screen.dart';
import 'package:pos/screens/discounts_screen.dart';
import 'package:pos/screens/orders_screen.dart';
import 'package:pos/screens/kitchen_kot_screen.dart';
import 'package:pos/screens/payment_screen.dart';
import 'package:pos/screens/payment_success_screen.dart';
import 'package:pos/screens/pricing_screen.dart';
import 'package:pos/screens/purchase_return_screen.dart';
import 'package:pos/screens/sale_screen.dart';
import 'package:pos/screens/sale_return_screen.dart';
import 'package:pos/screens/table_order_screen.dart';
import 'package:pos/screens/users_roles_screen.dart';
import 'package:pos/screens/settings_hub_screen.dart';
import 'package:pos/screens/expenses_screen.dart';
import 'package:pos/screens/branches_screen.dart';
import 'package:pos/screens/pra_settings_screen.dart';
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
  static const String profileSettings = '/settings/profile';
  static const String usersRoles = '/settings/users-roles';
  static const String praSettings = '/settings/pra';
  static const String salesReturn = '/salesReturn';
  static const String storeOut = '/storeOut';
  static const String expenses = '/expenses';
  static const String branches = '/branches';
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
        builder: (context, state) => LoginScreen(onSignUpPressed: () => GoRouter.of(context).goNamed('signup')),
      ),
      GoRoute(
        path: signup,
        name: 'signup',
        builder: (context, state) => SignUpScreen(onLoginPressed: () => GoRouter.of(context).goNamed('login')),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final authProvider = Provider.of<AuthProvider>(context, listen: true);
          if (authProvider.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (!authProvider.isAuthenticated) return const LoginScreen();
          return MainShell(child: child);
        },
        routes: [
          GoRoute(path: categories, name: 'categories', builder: (context, state) => const CategoriesScreen(), redirect: _checkSubscription),
          GoRoute(path: dashboard, name: 'dashboard', builder: (context, state) => const DashboardScreen(), redirect: _checkSubscription),
          GoRoute(path: products, name: 'products', builder: (context, state) => const StoreScreen(), redirect: _checkSubscription),
          GoRoute(path: '/category-products/:categoryId', name: 'category-products', builder: (context, state) => CategoryProductsScreen(categoryName: state.pathParameters['categoryId']!), redirect: _checkSubscription),
          GoRoute(path: staff, name: 'staff', builder: (context, state) => const StaffScreen(), redirect: _checkSubscription),
          GoRoute(path: attendance, name: 'attendance', builder: (context, state) => const AttendanceScreen(), redirect: _checkSubscription),
          GoRoute(path: suppliers, name: 'suppliers', builder: (context, state) => const SuppliersScreen(), redirect: _checkSubscription),
          GoRoute(path: purchases, name: 'Operations', builder: (context, state) => const OperationScreen(), redirect: _checkSubscription),
          GoRoute(path: purchasesReturn, name: 'purchases-return', builder: (context, state) => const PurchaseReturnScreen(), redirect: _checkSubscription),
          GoRoute(path: sales, name: 'sales', builder: (context, state) => const SaleScreen(), redirect: _checkSubscription),
          GoRoute(path: salesReturn, name: 'sales-return', builder: (context, state) => const SaleReturnScreen(), redirect: _checkSubscription),
          GoRoute(path: storeOut, name: 'store-out', builder: (context, state) => const StoreOutScreen(), redirect: _checkSubscription),
          GoRoute(path: expenses, name: 'expenses', builder: (context, state) => const ExpensesScreen(), redirect: _checkSubscription),
          GoRoute(path: branches, name: 'branches', builder: (context, state) => const BranchesScreen(), redirect: _checkSubscription),
          GoRoute(path: settings, name: 'settings', builder: (context, state) => const SettingsHubScreen(), redirect: _checkSubscription),
          GoRoute(path: profileSettings, name: 'profile-settings', builder: (context, state) => const SettingsScreen(), redirect: _checkSubscription),
          GoRoute(path: usersRoles, name: 'users-roles', builder: (context, state) => const UsersRolesScreen(), redirect: _checkSubscription),
          GoRoute(path: praSettings, name: 'pra-settings', builder: (context, state) => const PraSettingsScreen(), redirect: _checkSubscription),
          GoRoute(path: pricing, name: 'pricing', builder: (context, state) => const PricingScreen()),
          GoRoute(path: '$payment/:plan', name: 'payment', builder: (context, state) => PaymentScreen(plan: state.pathParameters['plan']!)),
          GoRoute(path: ingredients, name: 'ingredients', builder: (context, state) => const IngredientsScreen(), redirect: _checkSubscription),
          GoRoute(path: customers, name: 'customers', builder: (context, state) => const CustomersScreen(), redirect: _checkSubscription),
          GoRoute(path: discounts, name: 'Goodies', builder: (context, state) => const DiscountsScreen(), redirect: _checkSubscription),
          GoRoute(
            path: orders,
            name: 'orders',
            builder: (context, state) {
              final role = context.watch<AuthProvider>().currentUser?.role;
              return role == UserRole.kitchen ? const KitchenKotScreen() : const OrdersScreen();
            },
            redirect: _checkSubscription,
          ),
          GoRoute(path: paymentSuccess, name: 'payment-success', builder: (context, state) => const PaymentSuccessScreen()),
          GoRoute(path: tables, name: 'tables', builder: (context, state) => const TableManagementScreen(), redirect: _checkSubscription),
          GoRoute(
            path: '/table-order/:tableId',
            builder: (context, state) {
              final extra = state.extra;
              if (extra is RestaurantTable) return TableOrderScreen(table: extra);
              return _TableOrderRouteResolver(tableId: state.pathParameters['tableId'] ?? '');
            },
            redirect: _checkSubscription,
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isLoading) return null;
      final isAuthenticated = authProvider.isAuthenticated;
      final isLoginRoute = state.matchedLocation == login;
      final isSignupRoute = state.matchedLocation == signup;
      if (!isAuthenticated && !isLoginRoute && !isSignupRoute) return login;
      if (isAuthenticated && (isLoginRoute || isSignupRoute)) return dashboard;
      return null;
    },
  );

  static Future<String?> _checkSubscription(BuildContext context, GoRouterState state) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) return null;

    final access = await subscriptionProvider.getAccessLevel();
    final path = state.uri.path;
    final isCommercialRoute = path == pricing || path.startsWith(payment) || path == paymentSuccess;

    if (access == SubscriptionAccessLevel.locked && !isCommercialRoute) return pricing;

    if (access == SubscriptionAccessLevel.basic) {
      final allowedBasic = path == dashboard || path == tables || path == orders || path.startsWith('/table-order') || isCommercialRoute;
      if (!allowedBasic) return dashboard;
    }

    return null;
  }

  static List<NavigationItem> getNavigationItems(UserRole role) {
    const adminRoles = [UserRole.superAdmin, UserRole.admin];
    const managementRoles = [UserRole.superAdmin, UserRole.admin, UserRole.manager];
    const serviceRoles = [UserRole.superAdmin, UserRole.admin, UserRole.manager, UserRole.cashier, UserRole.waiter, UserRole.staff, UserRole.reception];
    const orderRoles = [UserRole.superAdmin, UserRole.admin, UserRole.manager, UserRole.cashier, UserRole.waiter, UserRole.staff, UserRole.kitchen, UserRole.delivery];
    const inventoryRoles = [UserRole.superAdmin, UserRole.admin, UserRole.manager, UserRole.operations, UserRole.inventory];
    const customerRoles = [UserRole.superAdmin, UserRole.admin, UserRole.manager, UserRole.cashier, UserRole.delivery, UserRole.reception];
    const operationsRoles = [UserRole.superAdmin, UserRole.admin, UserRole.manager, UserRole.operations, UserRole.accounts, UserRole.inventory];

    final allItems = [
      NavigationItem(icon: Icons.dashboard_rounded, label: 'Dashboard', route: dashboard, roles: [...managementRoles, UserRole.cashier, UserRole.waiter, UserRole.staff, UserRole.kitchen, UserRole.accounts, UserRole.operations, UserRole.auditor]),
      NavigationItem(icon: Icons.table_restaurant_rounded, label: 'Tables', route: tables, roles: serviceRoles),
      NavigationItem(icon: role == UserRole.kitchen ? Icons.soup_kitchen_rounded : Icons.shopping_bag_rounded, label: role == UserRole.kitchen ? 'KOT' : 'Billing', route: orders, roles: orderRoles),
      NavigationItem(icon: Icons.inventory_2_rounded, label: 'Inventory', route: products, roles: inventoryRoles),
      NavigationItem(icon: Icons.storefront_outlined, label: 'Store', route: storeOut, roles: [UserRole.superAdmin, UserRole.admin, UserRole.manager, UserRole.operations, UserRole.inventory]),
      NavigationItem(icon: Icons.payments_outlined, label: 'Expenses', route: expenses, roles: [UserRole.superAdmin, UserRole.admin, UserRole.manager, UserRole.accounts]),
      NavigationItem(icon: Icons.people_alt_rounded, label: 'CRM', route: customers, roles: customerRoles),
      NavigationItem(icon: Icons.receipt_long_rounded, label: 'Operations', route: purchases, roles: operationsRoles),
      NavigationItem(icon: Icons.kitchen_rounded, label: 'Kitchen Recipes', route: ingredients, roles: [UserRole.superAdmin, UserRole.admin, UserRole.operations]),
      NavigationItem(icon: Icons.local_shipping_rounded, label: 'Vendors', route: suppliers, roles: [UserRole.superAdmin, UserRole.admin, UserRole.manager, UserRole.operations, UserRole.accounts, UserRole.inventory]),
      NavigationItem(icon: Icons.account_tree_outlined, label: 'Branches', route: branches, roles: adminRoles),
      NavigationItem(icon: Icons.verified_user_outlined, label: 'PRA', route: praSettings, roles: adminRoles),
      NavigationItem(icon: Icons.psychology_alt_rounded, label: 'Help AI', route: dashboard, roles: adminRoles),
    ];
    return allItems.where((item) => item.roles.contains(role)).toList();
  }
}

class _TableOrderRouteResolver extends StatefulWidget {
  final String tableId;
  const _TableOrderRouteResolver({required this.tableId});

  @override
  State<_TableOrderRouteResolver> createState() => _TableOrderRouteResolverState();
}

class _TableOrderRouteResolverState extends State<_TableOrderRouteResolver> {
  bool _requestedLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<TableProvider>();
    if (!_requestedLoad && provider.tables.every((t) => t.id != widget.tableId)) {
      _requestedLoad = true;
      provider.loadTables();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TableProvider>();
    RestaurantTable? table;
    for (final item in provider.tables) {
      if (item.id == widget.tableId) {
        table = item;
        break;
      }
    }
    if (table != null) return TableOrderScreen(table: table);
    if (provider.isLoading || !_requestedLoad) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.table_restaurant_outlined, size: 42),
      const SizedBox(height: 12),
      const Text('Table could not be loaded.'),
      const SizedBox(height: 12),
      FilledButton(onPressed: () => context.go(AppRouter.tables), child: const Text('Back to Tables')),
    ])));
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final String route;
  final List<UserRole> roles;
  const NavigationItem({required this.icon, required this.label, required this.route, required this.roles});
}
