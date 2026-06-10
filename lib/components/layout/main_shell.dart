import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/subscription_provider.dart';
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
        preferredSize: const Size.fromHeight(82),
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

class _ModernAppHeader extends StatefulWidget {
  final String currentLocation;

  const _ModernAppHeader({required this.currentLocation});

  @override
  State<_ModernAppHeader> createState() => _ModernAppHeaderState();
}

class _ModernAppHeaderState extends State<_ModernAppHeader> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }



  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final items = AppRouter.getNavigationItems(
      authProvider.currentUser?.role ?? UserRole.admin,
    );
    final isCompact = Responsive.isMobile(context);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.restaurantCharcoal,
            AppColors.restaurantCharcoalLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.32),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 82,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Row(
            children: [
              _RestaurantBrand(),
              const SizedBox(width: AppSpacing.xl),
              // Left Arrow
              // if (_showLeftArrow)
              // Container(
              //   decoration: BoxDecoration(
              //     color: Colors.white, // Background color
              //     shape: BoxShape.circle,
              //   ),
              //   child: IconButton(
              //     padding: EdgeInsets.all(0),
              //     icon: const Icon(
              //       Icons.arrow_back_ios_new_rounded,
              //       color: Colors.blue, // Icon color
              //       size: 20,
              //       weight: 200,
              //     ),
              //     onPressed: _scrollLeft,
              //     splashRadius: 20,
              //   ),
              // ),

              // Scrollable tabs
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < items.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: _ModernHeaderButton(
                            item: items[i],
                            selected: widget.currentLocation == items[i].route,
                            onTap: () async {
                              try {
                                final subscriptionProvider =
                                    Provider.of<SubscriptionProvider>(
                                      context,
                                      listen: false,
                                    );
                                final hasValidSubscription =
                                    await subscriptionProvider
                                        .hasValidSubscription();

                                if (!hasValidSubscription &&
                                    items[i].route != AppRouter.pricing) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please renew your subscription to access this feature',
                                      ),
                                      duration: Duration(seconds: 1),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  context.go(AppRouter.pricing);
                                } else {
                                  context.go(items[i].route);
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    duration: const Duration(seconds: 1),
                                    content: Text(
                                      'Error checking subscription: $e',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            compact: isCompact,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Right Arrow
              // Container(
              //   decoration: BoxDecoration(
              //     color: Colors.white, // Background color
              //     shape: BoxShape.circle,
              //   ),
              //   child: IconButton(
              //     padding: EdgeInsets.all(0),
              //     icon: const Icon(
              //       Icons.arrow_forward_ios_rounded,
              //       color: Colors.blue, // Icon color
              //       size: 20,
              //     ),
              //     onPressed: _scrollRight,
              //     splashRadius: 20,
              //   ),
              // ),
              const SizedBox(width: AppSpacing.md),
              _HeaderActions(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestaurantBrand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final restaurantName =
        context.watch<AuthProvider>().currentUser?.restaurantName.trim();
    final displayName = restaurantName == null || restaurantName.isEmpty
        ? 'Hospitality OS'
        : restaurantName;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            gradient: LinearGradient(
              colors: [
                AppColors.restaurantGold,
                AppColors.restaurantGoldSoft.withOpacity(0.7),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.restaurantGold.withOpacity(0.26),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Icon(
            Icons.restaurant_rounded,
            color: AppColors.restaurantCharcoal,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PREMIUM HOUSE',
              style: TextStyle(
                color: AppColors.restaurantGold,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.restaurantInk,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
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
        ? AppColors.restaurantGold
        : AppColors.restaurantInk.withOpacity(0.82);

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
        case 'storeOut':
          return l10n.storeOut;
        case 'Customers':
          return 'Customers';
        case 'Discounts':
          return 'Discounts';
        case 'Orders':
          return 'Orders';
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
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
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
                          ? AppColors.restaurantGold.withOpacity(0.14)
                          : _isHovered
                          ? AppColors.white.withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      border: widget.selected
                          ? Border.all(
                              color: AppColors.restaurantGold.withOpacity(0.38),
                            )
                          : Border.all(color: Colors.white.withOpacity(0.06)),
                      boxShadow: widget.selected
                          ? [
                              BoxShadow(
                                color: AppColors.restaurantGold.withOpacity(0.15),
                                blurRadius: 18,
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
                              fontSize: 16,
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
    Provider.of<LocaleProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.apartment_rounded,
                color: AppColors.restaurantGold,
                size: 18,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Main Branch',
                style: TextStyle(
                  color: AppColors.restaurantInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.restaurantMuted,
                size: 18,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Language selector
        // PopupMenuButton<Locale>(
        //   child: _ActionButton(
        //     icon: Icons.language,
        //     tooltip: 'Language',
        //     onTap: null,
        //   ),
        //   onSelected: (locale) {
        //     localeProvider.setLocale(locale);
        //   },
        //   itemBuilder: (context) => [
        //     const PopupMenuItem(
        //       value: Locale('en'),
        //       child: Row(
        //         children: [Text('🇺🇸'), SizedBox(width: 8), Text('English')],
        //       ),
        //     ),
        //     const PopupMenuItem(
        //       value: Locale('ur'),
        //       child: Row(
        //         children: [Text('🇵🇰'), SizedBox(width: 8), Text('اردو')],
        //       ),
        //     ),
        //     const PopupMenuItem(
        //       value: Locale('ar'),
        //       child: Row(
        //         children: [Text('🇸🇦'), SizedBox(width: 8), Text('العربية')],
        //       ),
        //     ),
        //   ],
        // ),

        // const SizedBox(width: AppSpacing.sm),

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
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: _isHovered
                    ? AppColors.restaurantCrimson.withOpacity(0.22)
                    : AppColors.restaurantCrimson.withOpacity(0.14),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                  color: AppColors.restaurantCrimson.withOpacity(0.25),
                ),
              ),
              child: Icon(widget.icon, color: AppColors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
