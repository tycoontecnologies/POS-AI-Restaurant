import 'package:flutter/material.dart';
import 'pages/categories_page.dart';
import 'pages/products_page.dart';
import 'pages/staff_page.dart';
import 'widgets/app_header.dart';
import 'pages/attendance_page.dart';
import 'pages/sales_page.dart';
import 'pages/drafts_page.dart';
import 'pages/suppliers_page.dart';
import 'pages/store_out_page.dart';
import 'pages/purchases_page.dart';
import 'pages/settings_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    CategoriesPage(),
    ProductsPage(),
    StaffPage(),
    AttendancePage(),
    SuppliersPage(),
    PurchasesPage(),
    SalesPage(),
    DraftsPage(),
    StoreOutPage(),
    SettingsPage(),
  ];

  void _onSelect(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: AppHeader(selectedIndex: _selectedIndex, onTap: _onSelect),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _pages[_selectedIndex],
      ),
    );
  }
}
