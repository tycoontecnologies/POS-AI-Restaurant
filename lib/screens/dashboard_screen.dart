import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/screens/restaurant_command_center_screen.dart';
import 'package:pos/screens/table_management_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());

    if (user.isAdmin) {
      return const RestaurantCommandCenterScreen();
    }

    return const TableManagementScreen();
  }
}
