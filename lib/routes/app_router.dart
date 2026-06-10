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
import 'package:pos/screens/payment_screen.dart';
import 'package:pos/screens/payment_success_screen.dart';
import 'package:pos/screens/premium_billing_screen.dart';
import 'package:pos/screens/kitchen_display_screen.dart';
import 'package:pos/screens/premium_module_screen.dart';
import 'package:pos/screens/premium_ordering_screen.dart';
import 'package:pos/screens/pricing_screen.dart';
import 'package:pos/screens/purchase_return_screen.dart';
import 'package:pos/screens/restaurant_floor_plan_screen.dart';
import 'package:pos/screens/sale_screen.dart';
import 'package:pos/screens/sale_return_screen.dart';
import 'package:pos/utils/app_colors.dart';
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
import '../screens/ingredients_screen.dart';
import '../screens/customers_screen.dart';
import '../screens/table_management_screen.dart';
import '../components/layout/main_shell.dart';

class AppRouter {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String floorPlan = '/floor-plan';
  static const String ordering = '/ordering';
  static const String kitchenDisplay = '/kitchen-display';
  static const String billing = '/billing';
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
            builder: (context, state) => _premiumModule('menu'),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: dashboard,
            name: 'dashboard',
            builder: (context, state) => const RestaurantFloorPlanScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: floorPlan,
            name: 'floor-plan',
            builder: (context, state) => const RestaurantFloorPlanScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: '$ordering/:tableId',
            name: 'ordering',
            builder: (context, state) {
              final tableId = state.pathParameters['tableId']!;
              final table = _tableFromState(context, state, tableId);
              return PremiumOrderingScreen(table: table);
            },
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: kitchenDisplay,
            name: 'kitchen-display',
            builder: (context, state) => const KitchenDisplayScreen(),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: '$billing/:tableId',
            name: 'billing',
            builder: (context, state) {
              final tableId = state.pathParameters['tableId']!;
              final table = _tableFromState(context, state, tableId);
              return PremiumBillingScreen(table: table);
            },
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: products,
            name: 'products',
            builder: (context, state) => _premiumModule('store'),
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
            builder: (context, state) => _premiumModule('staff'),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: attendance,
            name: 'attendance',
            builder: (context, state) => _premiumModule('staff'),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: suppliers,
            name: 'suppliers',
            builder: (context, state) => _premiumModule('suppliers'),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: purchases,
            name: 'Operations',
            builder: (context, state) => _premiumModule('operations'),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: purchasesReturn,
            name: 'purchases-return',
            builder: (context, state) => _premiumModule('operations'),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: sales,
            name: 'sales',
            builder: (context, state) => _premiumModule('orders'),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: salesReturn,
            name: 'sales-return',
            builder: (context, state) => _premiumModule('orders'),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: storeOut,
            name: 'store-out',
            builder: (context, state) => _premiumModule('store'),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: settings,
            name: 'settings',
            builder: (context, state) => _premiumModule('settings'),
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
            builder: (context, state) => _premiumModule('recipes'),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: customers,
            name: 'customers',
            builder: (context, state) => _premiumModule('guests'),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: discounts,
            name: 'Goodies',
            builder: (context, state) => _premiumModule('promotions'),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          GoRoute(
            path: orders,
            name: 'orders',
            builder: (context, state) => _premiumModule('orders'),
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
            builder: (context, state) => _premiumModule('tables'),
            redirect: (context, state) => _checkSubscription(context, state),
          ),
          // In your AppRouter configuration
          GoRoute(
            path: '/table-order/:tableId',
            builder: (context, state) {
              final tableId = state.pathParameters['tableId']!;
              final table = _tableFromState(context, state, tableId);
              return PremiumOrderingScreen(table: table);
            },
            redirect: (context, state) => _checkSubscription(context, state),
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
        return floorPlan;
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
      // If user has valid subscription and is on pricing page, redirect to floor plan.
      if (hasValidSubscription && isPricingRoute) {
        return AppRouter.floorPlan;
      }
    }

    return null;
  }

  static Widget _premiumModule(String module) {
    switch (module) {
      case 'store':
        return const PremiumModuleScreen(
          eyebrow: 'Menu intelligence',
          title: 'Store Atelier',
          subtitle:
              'A premium catalog surface for ingredients, menu items, stock posture, and recipe-linked availability.',
          icon: Icons.inventory_2_outlined,
          accent: AppColors.restaurantGold,
          signals: [
            PremiumModuleSignal(
              label: 'Live items',
              value: 'Curated',
              icon: Icons.restaurant_menu_outlined,
              color: AppColors.restaurantGold,
            ),
            PremiumModuleSignal(
              label: 'Stock posture',
              value: 'Visible',
              icon: Icons.inventory_2_outlined,
              color: AppColors.restaurantEmerald,
            ),
            PremiumModuleSignal(
              label: 'Waste alerts',
              value: 'Quiet',
              icon: Icons.eco_outlined,
              color: AppColors.restaurantIndigo,
            ),
            PremiumModuleSignal(
              label: 'Cost drift',
              value: 'Watched',
              icon: Icons.trending_up_rounded,
              color: AppColors.restaurantAmber,
            ),
          ],
          capabilities: [
            PremiumModuleCapability(
              title: 'Recipe-aware availability',
              description:
                  'Menu items are presented as hospitality objects with cost, stock, and prep readiness context.',
              icon: Icons.auto_awesome_motion_outlined,
            ),
            PremiumModuleCapability(
              title: 'Invisible stock control',
              description:
                  'Waiters see availability cues while ingredient and recipe deductions stay in the background.',
              icon: Icons.visibility_off_outlined,
            ),
            PremiumModuleCapability(
              title: 'Premium item presentation',
              description:
                  'Products are prepared for image-led ordering surfaces instead of spreadsheet catalog rows.',
              icon: Icons.image_outlined,
            ),
          ],
          workflows: [
            'Review items that affect today service',
            'Promote best sellers into fast-order lanes',
            'Flag low-stock recipes before dinner rush',
            'Audit supplier cost movement discreetly',
          ],
        );
      case 'menu':
        return const PremiumModuleScreen(
          eyebrow: 'Menu architecture',
          title: 'Menu Rooms',
          subtitle:
              'Category and menu design for a restaurant team, organized around service speed and guest experience.',
          icon: Icons.menu_book_outlined,
          accent: AppColors.restaurantIndigo,
          signals: [
            PremiumModuleSignal(
              label: 'Active rooms',
              value: 'Service',
              icon: Icons.dashboard_customize_outlined,
              color: AppColors.restaurantIndigo,
            ),
            PremiumModuleSignal(
              label: 'Fast lanes',
              value: 'Ready',
              icon: Icons.bolt_outlined,
              color: AppColors.restaurantGold,
            ),
            PremiumModuleSignal(
              label: 'Modifiers',
              value: 'Guided',
              icon: Icons.tune_rounded,
              color: AppColors.restaurantPurple,
            ),
            PremiumModuleSignal(
              label: 'Images',
              value: 'Premium',
              icon: Icons.photo_library_outlined,
              color: AppColors.restaurantEmerald,
            ),
          ],
          capabilities: [
            PremiumModuleCapability(
              title: 'Service-first categories',
              description:
                  'Group dishes by how waiters sell and kitchens prepare them, not by back-office codes.',
              icon: Icons.room_service_outlined,
            ),
            PremiumModuleCapability(
              title: 'Modifiers and variants',
              description:
                  'Structure add-ons, portion sizes, and instructions for two-click ordering.',
              icon: Icons.account_tree_outlined,
            ),
            PremiumModuleCapability(
              title: 'Hospitality presentation',
              description:
                  'Create menu rooms that feel like a premium dining catalog inside the POS.',
              icon: Icons.workspace_premium_outlined,
            ),
          ],
          workflows: [
            'Curate today visible menu',
            'Surface chef specials',
            'Tune modifiers for speed',
            'Retire slow categories gracefully',
          ],
        );
      case 'staff':
        return const PremiumModuleScreen(
          eyebrow: 'People and service',
          title: 'Staff Performance',
          subtitle:
              'A calm command view for waiters, attendance, sections, service load, and shift performance.',
          icon: Icons.groups_2_outlined,
          accent: AppColors.restaurantEmerald,
          signals: [
            PremiumModuleSignal(
              label: 'Service team',
              value: 'On floor',
              icon: Icons.badge_outlined,
              color: AppColors.restaurantEmerald,
            ),
            PremiumModuleSignal(
              label: 'Sections',
              value: 'Balanced',
              icon: Icons.table_bar_outlined,
              color: AppColors.restaurantIndigo,
            ),
            PremiumModuleSignal(
              label: 'Speed',
              value: 'Tracked',
              icon: Icons.timer_outlined,
              color: AppColors.restaurantAmber,
            ),
            PremiumModuleSignal(
              label: 'Training',
              value: 'Guided',
              icon: Icons.school_outlined,
              color: AppColors.restaurantPurple,
            ),
          ],
          capabilities: [
            PremiumModuleCapability(
              title: 'Waiter sections',
              description:
                  'Keep table responsibility, handoffs, and service pressure visible to managers.',
              icon: Icons.person_pin_circle_outlined,
            ),
            PremiumModuleCapability(
              title: 'Shift rhythm',
              description:
                  'Attendance and breaks sit inside a service-aware control room, not a payroll grid.',
              icon: Icons.access_time_rounded,
            ),
            PremiumModuleCapability(
              title: 'Performance coaching',
              description:
                  'Highlight ticket averages, speed, upsells, and guest recovery opportunities.',
              icon: Icons.insights_outlined,
            ),
          ],
          workflows: [
            'Assign waiters to active sections',
            'Spot overloaded service stations',
            'Review shift performance',
            'Plan staffing for next rush',
          ],
        );
      case 'suppliers':
        return const PremiumModuleScreen(
          eyebrow: 'Procurement concierge',
          title: 'Supplier Network',
          subtitle:
              'A premium supplier relationship surface for cost, reliability, delivery rhythm, and purchase planning.',
          icon: Icons.local_shipping_outlined,
          accent: AppColors.restaurantAmber,
          signals: [
            PremiumModuleSignal(
              label: 'Supplier health',
              value: 'Stable',
              icon: Icons.handshake_outlined,
              color: AppColors.restaurantAmber,
            ),
            PremiumModuleSignal(
              label: 'Delivery risk',
              value: 'Low',
              icon: Icons.route_outlined,
              color: AppColors.restaurantEmerald,
            ),
            PremiumModuleSignal(
              label: 'Cost changes',
              value: 'Watched',
              icon: Icons.price_change_outlined,
              color: AppColors.restaurantGold,
            ),
            PremiumModuleSignal(
              label: 'Quality notes',
              value: 'Logged',
              icon: Icons.fact_check_outlined,
              color: AppColors.restaurantIndigo,
            ),
          ],
          capabilities: [
            PremiumModuleCapability(
              title: 'Cost-aware suppliers',
              description:
                  'Track supplier performance in the language of food cost and service reliability.',
              icon: Icons.payments_outlined,
            ),
            PremiumModuleCapability(
              title: 'Delivery rhythm',
              description:
                  'Keep expected purchase windows and urgent replenishment signals visible.',
              icon: Icons.schedule_send_outlined,
            ),
            PremiumModuleCapability(
              title: 'Quality memory',
              description:
                  'Maintain premium notes for ingredients, substitutions, and service-impacting issues.',
              icon: Icons.star_border_rounded,
            ),
          ],
          workflows: [
            'Review supplier reliability',
            'Prioritize urgent purchase needs',
            'Watch ingredient cost movement',
            'Prepare chef-approved substitutions',
          ],
        );
      case 'operations':
        return const PremiumModuleScreen(
          eyebrow: 'Back of house',
          title: 'Operations Control',
          subtitle:
              'Purchases, returns, store-out, waste, and branch movements presented as quiet operational signals.',
          icon: Icons.hub_outlined,
          accent: AppColors.restaurantPurple,
          signals: [
            PremiumModuleSignal(
              label: 'Purchases',
              value: 'Planned',
              icon: Icons.shopping_bag_outlined,
              color: AppColors.restaurantPurple,
            ),
            PremiumModuleSignal(
              label: 'Waste',
              value: 'Measured',
              icon: Icons.delete_sweep_outlined,
              color: AppColors.restaurantCrimson,
            ),
            PremiumModuleSignal(
              label: 'Transfers',
              value: 'Ready',
              icon: Icons.swap_horiz_rounded,
              color: AppColors.restaurantIndigo,
            ),
            PremiumModuleSignal(
              label: 'Returns',
              value: 'Controlled',
              icon: Icons.assignment_return_outlined,
              color: AppColors.restaurantAmber,
            ),
          ],
          capabilities: [
            PremiumModuleCapability(
              title: 'Operational calm',
              description:
                  'Move non-waiter inventory work away from the floor while keeping managers informed.',
              icon: Icons.spa_outlined,
            ),
            PremiumModuleCapability(
              title: 'Waste and variance',
              description:
                  'Surface exceptions elegantly so teams act before margins are damaged.',
              icon: Icons.warning_amber_rounded,
            ),
            PremiumModuleCapability(
              title: 'Branch movement',
              description:
                  'Prepare stock movement workflows for multi-branch hospitality groups.',
              icon: Icons.account_tree_outlined,
            ),
          ],
          workflows: [
            'Approve urgent procurement',
            'Review waste exceptions',
            'Prepare stock transfers',
            'Close purchase-return loops',
          ],
        );
      case 'recipes':
        return const PremiumModuleScreen(
          eyebrow: 'Culinary engine',
          title: 'Recipe Management',
          subtitle:
              'Recipe deduction, ingredient mapping, prep costs, and stock impact made invisible to waiters.',
          icon: Icons.soup_kitchen_outlined,
          accent: AppColors.restaurantEmerald,
          signals: [
            PremiumModuleSignal(
              label: 'Recipes',
              value: 'Linked',
              icon: Icons.receipt_long_outlined,
              color: AppColors.restaurantEmerald,
            ),
            PremiumModuleSignal(
              label: 'Ingredients',
              value: 'Mapped',
              icon: Icons.grass_outlined,
              color: AppColors.restaurantGold,
            ),
            PremiumModuleSignal(
              label: 'Deduction',
              value: 'Auto',
              icon: Icons.auto_mode_outlined,
              color: AppColors.restaurantIndigo,
            ),
            PremiumModuleSignal(
              label: 'Costing',
              value: 'Live',
              icon: Icons.calculate_outlined,
              color: AppColors.restaurantAmber,
            ),
          ],
          capabilities: [
            PremiumModuleCapability(
              title: 'Automatic deduction',
              description:
                  'Connect orders to ingredient movement without interrupting waiters or cashiers.',
              icon: Icons.sync_alt_outlined,
            ),
            PremiumModuleCapability(
              title: 'Chef-grade costing',
              description:
                  'Show food cost, substitution risk, and prep constraints as premium culinary signals.',
              icon: Icons.restaurant_outlined,
            ),
            PremiumModuleCapability(
              title: 'Availability intelligence',
              description:
                  'Use recipe stock to inform what can be sold during peak service.',
              icon: Icons.psychology_alt_outlined,
            ),
          ],
          workflows: [
            'Link ingredients to menu items',
            'Review food-cost drift',
            'Flag prep bottlenecks',
            'Forecast ingredient demand',
          ],
        );
      case 'guests':
        return const PremiumModuleScreen(
          eyebrow: 'Guest intelligence',
          title: 'Guest CRM',
          subtitle:
              'VIP profiles, loyalty, birthdays, visit history, favorite orders, and service preferences.',
          icon: Icons.diamond_outlined,
          accent: AppColors.restaurantGold,
          signals: [
            PremiumModuleSignal(
              label: 'VIP guests',
              value: 'Known',
              icon: Icons.workspace_premium_outlined,
              color: AppColors.restaurantGold,
            ),
            PremiumModuleSignal(
              label: 'Loyalty',
              value: 'Active',
              icon: Icons.card_giftcard_outlined,
              color: AppColors.restaurantEmerald,
            ),
            PremiumModuleSignal(
              label: 'Birthdays',
              value: 'Upcoming',
              icon: Icons.cake_outlined,
              color: AppColors.restaurantPurple,
            ),
            PremiumModuleSignal(
              label: 'Favorites',
              value: 'Remembered',
              icon: Icons.favorite_border_rounded,
              color: AppColors.restaurantCrimson,
            ),
          ],
          capabilities: [
            PremiumModuleCapability(
              title: 'VIP memory',
              description:
                  'Make repeat guests feel recognized with preferences, notes, and favorite orders.',
              icon: Icons.remember_me_outlined,
            ),
            PremiumModuleCapability(
              title: 'Loyalty with taste',
              description:
                  'Points and rewards appear as a hospitality layer, not coupon clutter.',
              icon: Icons.loyalty_outlined,
            ),
            PremiumModuleCapability(
              title: 'Visit timeline',
              description:
                  'Give managers the context to recover, delight, and retain important guests.',
              icon: Icons.timeline_outlined,
            ),
          ],
          workflows: [
            'Prepare VIP welcome notes',
            'Review birthdays this week',
            'Surface favorite orders',
            'Invite guests back with taste',
          ],
        );
      case 'promotions':
        return const PremiumModuleScreen(
          eyebrow: 'Revenue design',
          title: 'Goodies and Promotions',
          subtitle:
              'Discounts, coupons, packages, and upsell moments designed with restraint and brand control.',
          icon: Icons.local_offer_outlined,
          accent: AppColors.restaurantPurple,
          signals: [
            PremiumModuleSignal(
              label: 'Offers',
              value: 'Curated',
              icon: Icons.local_offer_outlined,
              color: AppColors.restaurantPurple,
            ),
            PremiumModuleSignal(
              label: 'Coupons',
              value: 'Controlled',
              icon: Icons.confirmation_number_outlined,
              color: AppColors.restaurantGold,
            ),
            PremiumModuleSignal(
              label: 'Margin guard',
              value: 'On',
              icon: Icons.security_outlined,
              color: AppColors.restaurantEmerald,
            ),
            PremiumModuleSignal(
              label: 'Campaigns',
              value: 'Planned',
              icon: Icons.campaign_outlined,
              color: AppColors.restaurantIndigo,
            ),
          ],
          capabilities: [
            PremiumModuleCapability(
              title: 'Brand-safe promotions',
              description:
                  'Keep discounts elegant, controlled, and aligned with premium hospitality.',
              icon: Icons.verified_outlined,
            ),
            PremiumModuleCapability(
              title: 'Upsell moments',
              description:
                  'Suggest high-value add-ons without cluttering the ordering flow.',
              icon: Icons.trending_up_rounded,
            ),
            PremiumModuleCapability(
              title: 'Margin awareness',
              description:
                  'Promotions are framed by food cost, timing, and operational capacity.',
              icon: Icons.account_balance_wallet_outlined,
            ),
          ],
          workflows: [
            'Prepare chef special offer',
            'Review coupon usage',
            'Protect margin thresholds',
            'Schedule quiet-hour promotions',
          ],
        );
      case 'orders':
        return const PremiumModuleScreen(
          eyebrow: 'Order orchestration',
          title: 'Order Concierge',
          subtitle:
              'A premium command view for dine-in, takeaway, delivery, payments, and guest recovery.',
          icon: Icons.room_service_outlined,
          accent: AppColors.restaurantIndigo,
          signals: [
            PremiumModuleSignal(
              label: 'Open orders',
              value: 'Live',
              icon: Icons.receipt_long_outlined,
              color: AppColors.restaurantIndigo,
            ),
            PremiumModuleSignal(
              label: 'Late risk',
              value: 'Watched',
              icon: Icons.timer_outlined,
              color: AppColors.restaurantCrimson,
            ),
            PremiumModuleSignal(
              label: 'Payments',
              value: 'Settled',
              icon: Icons.payments_outlined,
              color: AppColors.restaurantEmerald,
            ),
            PremiumModuleSignal(
              label: 'Recovery',
              value: 'Ready',
              icon: Icons.support_agent_outlined,
              color: AppColors.restaurantGold,
            ),
          ],
          capabilities: [
            PremiumModuleCapability(
              title: 'Service timeline',
              description:
                  'Keep order moments, kitchen state, payment, and guest experience in one calm view.',
              icon: Icons.timeline_outlined,
            ),
            PremiumModuleCapability(
              title: 'Delivery readiness',
              description:
                  'Surface takeaway and delivery as hospitality stations instead of back-office rows.',
              icon: Icons.delivery_dining_outlined,
            ),
            PremiumModuleCapability(
              title: 'Guest recovery',
              description:
                  'Highlight late or sensitive orders before they become bad experiences.',
              icon: Icons.volunteer_activism_outlined,
            ),
          ],
          workflows: [
            'Review open checks',
            'Spot late kitchen tickets',
            'Prepare delivery handoff',
            'Close payment exceptions',
          ],
        );
      case 'settings':
        return const PremiumModuleScreen(
          eyebrow: 'House configuration',
          title: 'Restaurant Settings',
          subtitle:
              'Branch identity, payment rules, taxes, service charges, users, and hospitality preferences.',
          icon: Icons.tune_rounded,
          accent: AppColors.restaurantGold,
          signals: [
            PremiumModuleSignal(
              label: 'Branch',
              value: 'Active',
              icon: Icons.apartment_rounded,
              color: AppColors.restaurantGold,
            ),
            PremiumModuleSignal(
              label: 'Payments',
              value: 'Ready',
              icon: Icons.credit_card_outlined,
              color: AppColors.restaurantEmerald,
            ),
            PremiumModuleSignal(
              label: 'Taxes',
              value: 'Set',
              icon: Icons.request_quote_outlined,
              color: AppColors.restaurantIndigo,
            ),
            PremiumModuleSignal(
              label: 'Access',
              value: 'Managed',
              icon: Icons.admin_panel_settings_outlined,
              color: AppColors.restaurantPurple,
            ),
          ],
          capabilities: [
            PremiumModuleCapability(
              title: 'Branch identity',
              description:
                  'Keep each location polished with logo, address, receipt, and local service rules.',
              icon: Icons.storefront_outlined,
            ),
            PremiumModuleCapability(
              title: 'Payment and tax rules',
              description:
                  'Configure checkout behavior without exposing complexity to service staff.',
              icon: Icons.rule_outlined,
            ),
            PremiumModuleCapability(
              title: 'Role-aware access',
              description:
                  'Shape the system around admins, managers, waiters, cashiers, and kitchen users.',
              icon: Icons.lock_person_outlined,
            ),
          ],
          workflows: [
            'Review branch profile',
            'Tune checkout rules',
            'Manage user access',
            'Prepare multi-branch reporting',
          ],
        );
      case 'tables':
      default:
        return const PremiumModuleScreen(
          eyebrow: 'Floor design',
          title: 'Floor Setup',
          subtitle:
              'Design service areas, table inventory, sections, reservations, and operational table behavior.',
          icon: Icons.table_restaurant_outlined,
          accent: AppColors.restaurantEmerald,
          signals: [
            PremiumModuleSignal(
              label: 'Areas',
              value: 'Mapped',
              icon: Icons.map_outlined,
              color: AppColors.restaurantEmerald,
            ),
            PremiumModuleSignal(
              label: 'Tables',
              value: 'Live',
              icon: Icons.table_bar_outlined,
              color: AppColors.restaurantGold,
            ),
            PremiumModuleSignal(
              label: 'Reservations',
              value: 'Ready',
              icon: Icons.event_available_outlined,
              color: AppColors.restaurantIndigo,
            ),
            PremiumModuleSignal(
              label: 'Sections',
              value: 'Balanced',
              icon: Icons.grid_view_rounded,
              color: AppColors.restaurantPurple,
            ),
          ],
          capabilities: [
            PremiumModuleCapability(
              title: 'Real floor areas',
              description:
                  'Main Hall, Family Hall, VIP, Outdoor, Rooftop, Take Away, and Delivery are first-class spaces.',
              icon: Icons.space_dashboard_outlined,
            ),
            PremiumModuleCapability(
              title: 'Table behavior',
              description:
                  'Each table carries status, waiter, bill, elapsed time, and operational urgency.',
              icon: Icons.sensors_outlined,
            ),
            PremiumModuleCapability(
              title: 'Reservation posture',
              description:
                  'Prepare the floor for reserved, occupied, ready, and attention-required states.',
              icon: Icons.book_online_outlined,
            ),
          ],
          workflows: [
            'Review floor area assignments',
            'Balance waiter sections',
            'Prepare VIP reservations',
            'Tune table service states',
          ],
        );
    }
  }

  // Role-based navigation items
  static List<NavigationItem> getNavigationItems(UserRole role) {
    final allItems = [
      NavigationItem(
        icon: Icons.grid_view_rounded,
        label: 'Floor',
        route: floorPlan,
        roles: [UserRole.admin, UserRole.staff, UserRole.kitchen],
      ),
      NavigationItem(
        icon: Icons.soup_kitchen_outlined,
        label: 'KDS',
        route: kitchenDisplay,
        roles: [UserRole.admin, UserRole.staff, UserRole.kitchen],
      ),
      NavigationItem(
        icon: Icons.restaurant_menu_outlined,
        label: 'Menu',
        route: products,
        roles: [UserRole.admin, UserRole.staff],
      ),
      NavigationItem(
        icon: Icons.groups_2_outlined,
        label: 'People',
        route: staff,
        roles: [UserRole.admin],
      ),
      // NavigationItem(
      //   icon: Icons.access_time,
      //   label: 'Attendance',
      //   route: attendance,
      //   roles: [UserRole.admin, UserRole.staff],
      // ),
      NavigationItem(
        icon: Icons.hub_outlined,
        label: 'Operations',
        route: purchases,
        roles: [UserRole.admin, UserRole.staff],
      ),
      NavigationItem(
        icon: Icons.local_shipping_outlined,
        label: 'Suppliers',
        route: suppliers,
        roles: [UserRole.admin, UserRole.staff],
      ),
      // NavigationItem(
      //   icon: Icons.keyboard_return_sharp,
      //   label: 'Purchases return',
      //   route: purchasesReturn,
      //   roles: [UserRole.admin, UserRole.staff],
      // ),
      // NavigationItem(
      //   icon: Icons.point_of_sale,
      //   label: 'sales',
      //   route: sales,
      //   roles: [UserRole.admin, UserRole.staff, UserRole.user],
      // ),
      // NavigationItem(
      //   icon: Icons.point_of_sale,
      //   label: 'Sales Return',
      //   route: salesReturn,
      //   roles: [UserRole.admin, UserRole.staff, UserRole.user],
      // ),
      NavigationItem(
        icon: Icons.soup_kitchen_outlined,
        label: 'Recipes',
        route: ingredients,
        roles: [UserRole.admin],
      ),
      NavigationItem(
        icon: Icons.diamond_outlined,
        label: 'Guests',
        route: customers,
        roles: [UserRole.admin],
      ),
      NavigationItem(
        icon: Icons.local_offer_outlined,
        label: 'Goodies',
        route: discounts,
        roles: [UserRole.admin],
      ),
      NavigationItem(
        icon: Icons.room_service_outlined,
        label: 'Orders',
        route: orders,
        roles: [UserRole.admin, UserRole.staff, UserRole.user],
      ),
      NavigationItem(
        icon: Icons.tune_rounded,
        label: 'House',
        route: settings,
        roles: [UserRole.admin],
      ),
    ];

    return allItems.where((item) => item.roles.contains(role)).toList();
  }

  static RestaurantTable _tableFromState(
    BuildContext context,
    GoRouterState state,
    String tableId,
  ) {
    final extra = state.extra;
    if (extra is RestaurantTable) return extra;
    final loadedTables = context.read<TableProvider>().tables;
    for (final table in loadedTables) {
      if (table.id == tableId) return table;
    }
    return RestaurantTable(
      id: tableId,
      tableNumber: tableId,
      numberOfSeats: 0,
      status: TableStatus.empty,
      createdAt: DateTime.now(),
    );
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
