import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/screens/employee_dashboard_screen.dart';
import 'package:pos/screens/restaurant_dashboard_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());

    final dashboard = (user.role == UserRole.superAdmin ||
            user.role == UserRole.admin ||
            user.role == UserRole.auditor)
        ? const RestaurantDashboardScreen()
        : const EmployeeDashboardScreen();

    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            height: 58,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/logo.jpeg',
                height: 42,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  'TYCOON POS',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
            ),
          ),
          Expanded(child: dashboard),
        ],
      ),
    );
  }
}
