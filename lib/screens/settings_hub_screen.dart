import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/utils/app_colors.dart';

class SettingsHubScreen extends StatelessWidget {
  const SettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundLight,
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Settings', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: AppColors.grey900)),
        const SizedBox(height: 4),
        const Text('Restaurant configuration, accounts and access control.', style: TextStyle(fontSize: 12, color: AppColors.grey500)),
        const SizedBox(height: 22),
        Wrap(spacing: 14, runSpacing: 14, children: [
          _SettingsTile(
            icon: Icons.storefront_outlined,
            title: 'Restaurant Profile',
            subtitle: 'Restaurant name, logo, location, contact and account security.',
            onTap: () => context.go(AppRouter.profileSettings),
          ),
          _SettingsTile(
            icon: Icons.manage_accounts_outlined,
            title: 'Users & Roles',
            subtitle: 'Create department logins, assign roles, permissions and reset access.',
            onTap: () => context.go(AppRouter.usersRoles),
          ),
          const _SettingsTile(
            icon: Icons.account_tree_outlined,
            title: 'Branches',
            subtitle: 'Multi-branch setup is branch-ready and will be enabled in the next phase.',
          ),
          const _SettingsTile(
            icon: Icons.history_rounded,
            title: 'Audit & Sessions',
            subtitle: 'Login history and worked hours are captured for the Command Center.',
          ),
        ]),
      ]),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _SettingsTile({required this.icon, required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 145,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.outlineLight)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: AppColors.primary, size: 20)),
              const Spacer(),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.grey900)),
              const SizedBox(height: 4),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.grey500)),
            ]),
          ),
        ),
      ),
    );
  }
}
