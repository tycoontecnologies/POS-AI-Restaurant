import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'routes/app_router.dart';
import 'utils/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';

void main() {
  if (kIsWeb) {
    // This removes the # from URLs on web
    // GoRouter.optionURLReflectsImperativeAPIs = true;
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, child) {
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
