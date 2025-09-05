// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:pos/providers/attendance_provider.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/cart_provider.dart';
import 'package:pos/providers/category_provider.dart';
import 'package:pos/providers/draft_provider.dart';
import 'package:pos/providers/product_provider.dart';
import 'package:pos/providers/purchase_provider.dart';
import 'package:pos/providers/purchase_return_provider.dart';
import 'package:pos/providers/sale_provider.dart';
import 'package:pos/providers/sale_return_provider.dart';
import 'package:pos/providers/staff_provider.dart';
import 'package:pos/providers/statistics_provider.dart';
import 'package:pos/providers/store_out_provider.dart';
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
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

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
        ChangeNotifierProvider(create: (_) => DraftProvider()),
        ChangeNotifierProvider(create: (_) => StoreOutProvider()),
        ChangeNotifierProvider(create: (_) => StatisticsProvider()),
        ChangeNotifierProvider(create: (_) => SaleReturnProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseReturnProvider()),
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
      ],
      child: Consumer3<AuthProvider, ThemeProvider, LocaleProvider>(
        builder: (context, authProvider, themeProvider, localeProvider, child) {
          // Initialize auth if not already initialized
          if (!authProvider.isLoading && authProvider.currentUser == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              authProvider.initialize();
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
