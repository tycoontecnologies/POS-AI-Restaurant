import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../../routes/app_router.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/responsive.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.toString();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: _ModernAppHeader(currentLocation: currentLocation),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.02, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
        child: child,
      ),
    );
  }
}

class _ModernAppHeader extends StatelessWidget {
  final String currentLocation;

  const _ModernAppHeader({required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    // final l10n = AppLocalizations.of(context)!;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final items = AppRouter.getNavigationItems(
      authProvider.currentUser?.role ?? UserRole.admin,
    );
    // final localeProvider = Provider.of<LocaleProvider>(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = Responsive.isMobile(context);
              return Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (int i = 0; i < items.length; i++)
                            _ModernHeaderButton(
                              item: items[i],
                              selected: currentLocation == items[i].route,
                              onTap: () => context.go(items[i].route),
                              compact: isCompact,
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: AppSpacing.md),
                  _HeaderActions(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ModernHeaderButton extends StatefulWidget {
  final NavigationItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  const _ModernHeaderButton({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  @override
  State<_ModernHeaderButton> createState() => _ModernHeaderButtonState();
}

class _ModernHeaderButtonState extends State<_ModernHeaderButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = widget.selected
        ? AppColors.white
        : AppColors.white.withOpacity(0.8);

    String getLocalizedLabel() {
      switch (widget.item.label) {
        case 'categories':
          return l10n.categories;
        case 'products':
          return l10n.products;
        case 'staff':
          return l10n.staff;
        case 'attendance':
          return l10n.attendance;
        case 'suppliers':
          return l10n.suppliers;
        case 'purchases':
          return l10n.purchases;
        case 'sales':
          return l10n.sales;
        case 'drafts':
          return l10n.drafts;
        case 'storeOut':
          return l10n.storeOut;
        case 'settings':
          return l10n.settings;
        default:
          return widget.item.label;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovered = true);
          _animationController.forward();
        },
        onExit: (_) {
          setState(() => _isHovered = false);
          _animationController.reverse();
        },
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.compact
                          ? AppSpacing.sm
                          : AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: widget.selected
                          ? AppColors.white.withOpacity(0.2)
                          : _isHovered
                          ? AppColors.white.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: widget.selected
                          ? Border.all(color: AppColors.white.withOpacity(0.3))
                          : null,
                      boxShadow: widget.selected
                          ? [
                              BoxShadow(
                                color: AppColors.white.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.item.icon, color: color, size: 20),
                        if (!widget.compact) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            getLocalizedLabel(),
                            style: TextStyle(
                              color: color,
                              fontSize: 14,
                              fontWeight: widget.selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeaderActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Row(
      children: [
        // Language selector
        PopupMenuButton<Locale>(
          child: _ActionButton(
            icon: Icons.language,
            tooltip: 'Language',
            onTap: null,
          ),
          onSelected: (locale) {
            localeProvider.setLocale(locale);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: Locale('en'),
              child: Row(
                children: [Text('🇺🇸'), SizedBox(width: 8), Text('English')],
              ),
            ),
            const PopupMenuItem(
              value: Locale('ur'),
              child: Row(
                children: [Text('🇵🇰'), SizedBox(width: 8), Text('اردو')],
              ),
            ),
            const PopupMenuItem(
              value: Locale('ar'),
              child: Row(
                children: [Text('🇸🇦'), SizedBox(width: 8), Text('العربية')],
              ),
            ),
          ],
        ),

        const SizedBox(width: AppSpacing.sm),

        // Logout button
        _ActionButton(
          icon: Icons.logout,
          tooltip: 'Logout',
          onTap: () {
            _showLogoutConfirmationDialog(context, authProvider);
          },
        ),
      ],
    );
  }

  void _showLogoutConfirmationDialog(
    BuildContext context,
    AuthProvider authProvider,
  ) {

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Logout'),
          content: Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await authProvider.signOut();
                // Navigate to login screen after logout
                if (context.mounted) {
                  GoRouter.of(context).go(AppRouter.login);
                }
              },
              child: Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _ActionButton({required this.icon, required this.tooltip, this.onTap});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: _isHovered
                    ? AppColors.white.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: _isHovered
                    ? Border.all(color: AppColors.white.withOpacity(0.2))
                    : null,
              ),
              child: Icon(
                widget.icon,
                color: AppColors.white.withOpacity(0.9),
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
