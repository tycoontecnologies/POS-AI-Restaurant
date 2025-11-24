// main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:pos/providers/attendance_provider.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/cart_provider.dart';
import 'package:pos/providers/category_provider.dart';
import 'package:pos/providers/customer_provider.dart';
import 'package:pos/providers/order_provider.dart';
import 'package:pos/providers/product_provider.dart';
import 'package:pos/providers/purchase_provider.dart';
import 'package:pos/providers/purchase_return_provider.dart';
import 'package:pos/providers/sale_provider.dart';
import 'package:pos/providers/sale_return_provider.dart';
import 'package:pos/providers/staff_provider.dart';
import 'package:pos/providers/statistics_provider.dart';
import 'package:pos/providers/store_out_provider.dart';
import 'package:pos/providers/subscription_provider.dart';
import 'package:pos/providers/supplier_provider.dart';
import 'package:pos/services/staff_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'routes/app_router.dart';
import 'utils/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'package:pos/providers/ingredient_provider.dart';
import 'package:pos/providers/recipe_provider.dart';
import 'package:pos/providers/discount_provider.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:pos/providers/table_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kIsWeb) {
    // This removes the # from URLs on web
    setUrlStrategy(PathUrlStrategy());
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final provider = AuthProvider();
            provider.initialize();
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => SupplierProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseProvider()),
        ChangeNotifierProvider(create: (_) => SaleProvider()),
        ChangeNotifierProvider(create: (_) => StoreOutProvider()),
        ChangeNotifierProvider(create: (_) => StatisticsProvider()),
        ChangeNotifierProvider(create: (_) => SaleReturnProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseReturnProvider()),
        ChangeNotifierProvider(create: (_) => IngredientProvider()),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => DiscountProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProxyProvider<AuthProvider, StaffProvider>(
          create: (context) =>
              StaffProvider(FirebaseStaffService(context.read<AuthProvider>())),
          update: (context, auth, previous) =>
              StaffProvider(FirebaseStaffService(auth)),
        ),
        ChangeNotifierProxyProvider<AuthProvider, AttendanceProvider>(
          create: (context) => AttendanceProvider(
            Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (context, authProvider, attendanceProvider) =>
              attendanceProvider ?? AttendanceProvider(authProvider),
        ),
        ChangeNotifierProxyProvider<AuthProvider, CategoryProvider>(
          create: (context) => CategoryProvider(context.read<AuthProvider>()),
          update: (context, authProvider, categoryProvider) =>
              categoryProvider!,
        ),
        ChangeNotifierProxyProvider<AuthProvider, TableProvider>(
          create: (context) => TableProvider(context.read<AuthProvider>()),
          update: (context, authProvider, tableProvider) =>
              tableProvider ?? TableProvider(authProvider),
        ),
      ],
      child: Consumer3<AuthProvider, ThemeProvider, LocaleProvider>(
        builder: (context, authProvider, themeProvider, localeProvider, child) {
          // Initialize auth if not already initialized
          if (!authProvider.isLoading && authProvider.currentUser == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              authProvider.initialize();
            });

            // Add subscription check timer after auth is initialized
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final subscriptionProvider = Provider.of<SubscriptionProvider>(
                context,
                listen: false,
              );
              // Check subscription status periodically (every hour)
              Timer.periodic(Duration(hours: 1), (timer) async {
                if (!context.mounted) {
                  timer.cancel();
                  return;
                }

                final hasValidSubscription = await subscriptionProvider
                    .hasValidSubscription();
                final currentLocation = GoRouter.of(
                  context,
                ).routeInformationProvider.value.location;
                // ).routeInformationProvider.value.uri;

                if (!hasValidSubscription &&
                    currentLocation != AppRouter.pricing &&
                    currentLocation != AppRouter.payment &&
                    currentLocation != AppRouter.paymentSuccess) {
                  if (context.mounted) {
                    GoRouter.of(context).go(AppRouter.pricing);
                  }
                }
              });
            });
          }

          return MaterialApp.router(
            title: 'POS System - Modern Business Management',
            debugShowCheckedModeBanner: false,

            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,

            locale: localeProvider.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'), // English
              Locale('ur'), // Urdu
              Locale('ar'), // Arabic
            ],

            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
