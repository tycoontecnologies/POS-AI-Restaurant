import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/screens/employee_dashboard_screen.dart';
import 'package:pos/screens/restaurant_dashboard_screen_v3.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());

    return ColoredBox(
      color: const Color(0xFFF9FAFB),
      child: (user.role == UserRole.superAdmin ||
              user.role == UserRole.admin ||
              user.role == UserRole.auditor)
          ? const RestaurantDashboardScreenV3()
          : const EmployeeDashboardScreen(),
    );
  }
}
