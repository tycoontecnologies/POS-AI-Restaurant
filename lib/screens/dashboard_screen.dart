import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/components/ui/shimmer_effect.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:pos/models/category.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/category_provider.dart';
import 'package:pos/providers/product_provider.dart';
import 'package:pos/providers/statistics_provider.dart';
import 'package:provider/provider.dart';
import '../utils/responsive.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../components/ui/custom_button.dart';
import '../routes/app_router.dart';
import 'package:pos/providers/auth_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late CategoryProvider _categoryProvider;
  late ProductProvider _productProvider;
  late StatisticsProvider _statisticsProvider;

  // Tutorial coach mark controller and targets
  // TutorialCoachMark? tutorialCoachMark;
  final GlobalKey _categoriesGridKey = GlobalKey();
  final GlobalKey _statisticsBarKey = GlobalKey();
  final GlobalKey _quickActionsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _categoryProvider = Provider.of<CategoryProvider>(context);
    _productProvider = Provider.of<ProductProvider>(context);
    _statisticsProvider = Provider.of<StatisticsProvider>(context);
    // Get auth provider

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load initial categories
      if (_categoryProvider.allCategories.isEmpty &&
          !_categoryProvider.isLoading) {
        _categoryProvider.loadInitialCategories();
      }

      // Load products for statistics
      final vendorId = _categoryProvider.authProvider?.currentUser?.id;
      if (vendorId != null &&
          _productProvider.products.isEmpty &&
          !_productProvider.isLoading) {
        _productProvider.loadProducts(vendorId);
      }

      // Load statistics if not already loading
      if (_statisticsProvider.isLoading) {
        _statisticsProvider.loadStatistics();
      }
    });
  }

  @override
  void dispose() {
    // tutorialCoachMark?.finish();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Expanded(
          flex: Responsive.isDesktop(context) ? 3 : 1,
          child: Column(
            children: [
              Expanded(
                key: _categoriesGridKey,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Consumer<CategoryProvider>(
                    builder: (context, categoryProvider, child) {
                      if (categoryProvider.isLoading &&
                          categoryProvider.allCategories.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: ShimmerCategoryGrid(
                            crossAxisCount: Responsive.isDesktop(context)
                                ? 4
                                : Responsive.isTablet(context)
                                ? 4
                                : 2,
                            itemCount: 8,
                          ),
                        );
                      }

                      if (categoryProvider.error != null) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error,
                                size: 64,
                                color: AppColors.error,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text('Error: ${categoryProvider.error}'),
                              const SizedBox(height: AppSpacing.md),
                              CustomButton(
                                text: 'Retry',
                                onPressed: () =>
                                    categoryProvider.refreshCategories(),
                                variant: ButtonVariant.filled,
                              ),
                            ],
                          ),
                        );
                      }

                      final categories = categoryProvider.allCategories;

                      Provider.of<ProductProvider>(context, listen: false);
                      final categoriesWithProducts = categories;

                      if (categoriesWithProducts.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.category,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                l10n.noCategoriesWithProductsFound,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              CustomButton(
                                text: 'Refresh',
                                onPressed: () =>
                                    categoryProvider.refreshCategories(),
                                variant: ButtonVariant.filled,
                              ),
                            ],
                          ),
                        );
                      }

                      return _PagedCategoryGrid(
                        categories: categoriesWithProducts,
                        currentPage: 1,
                        onCategoryTap: (category) {
                          context.go('/category-products/${category.name}');
                        },
                      );
                    },
                  ),
                ),
              ),
              // Statistics Bar
              Container(
                key: _statisticsBarKey,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Consumer<StatisticsProvider>(
                  builder: (context, statisticsProvider, child) {
                    if (statisticsProvider.isLoading) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(
                          8,
                          (index) => ShimmerEffect(
                            width: 80,
                            height: 20,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }

                    return Responsive.isDesktop(context)
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: _buildStatistics(
                              l10n,
                              _statisticsProvider.statistics,
                            ),
                          )
                        : Wrap(
                            spacing: AppSpacing.md,
                            runSpacing: AppSpacing.sm,
                            children: _buildStatistics(
                              l10n,
                              _statisticsProvider.statistics,
                            ),
                          );
                  },
                ),
              ),
            ],
          ),
        ),
        // Right Sidebar (Desktop only)
        if (Responsive.isDesktop(context))
          Container(
            key: _quickActionsKey,
            width: 325,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(-2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Updated Header with Restaurant Info
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    final user = authProvider.currentUser;

                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      color: Colors.blue.shade50,
                      child: Row(
                        children: [
                          // Restaurant Logo
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: _buildRestaurantLogo(user),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.restaurantName.isNotEmpty == true
                                      ? user!.restaurantName
                                      : 'My Restaurant',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  user?.location.isNotEmpty == true
                                      ? user!.location
                                      : 'My Restaurant Address',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Quick Actions
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          l10n.quickActions,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Expanded(
                          child: GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: AppSpacing.md,
                            mainAxisSpacing: AppSpacing.md,
                            childAspectRatio: 1.3,
                            children: [
                              _buildQuickActionButton(
                                l10n.sales,
                                Icons.shopping_cart,
                                const Color(0xFF8B5CF6),
                                () => context.go(AppRouter.salesRecord),
                              ),
                              _buildQuickActionButton(
                                l10n.products,
                                Icons.add_box,
                                AppColors.success,
                                () => context.go(AppRouter.products),
                              ),
                              _buildQuickActionButton(
                                l10n.categories,
                                Icons.category,
                                AppColors.info,
                                () => context.go(AppRouter.categories),
                              ),
                              _buildQuickActionButton(
                                l10n.staff,
                                Icons.people,
                                AppColors.primary,
                                () => context.go(AppRouter.staff),
                              ),
                              _buildQuickActionButton(
                                l10n.suppliers,
                                Icons.local_shipping,
                                AppColors.warning,
                                () => context.go(AppRouter.suppliers),
                              ),
                              _buildQuickActionButton(
                                l10n.purchases,
                                Icons.shopping_bag,
                                AppColors.error,
                                () => context.go(AppRouter.purchases),
                              ),
                              _buildQuickActionButton(
                                l10n.attendance,
                                Icons.timeline,
                                const Color(0xFF06B6D4),
                                () => context.go(AppRouter.attendance),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: CustomButton(
                            text: l10n.settings,
                            onPressed: () => context.go(AppRouter.settings),
                            variant: ButtonVariant.filled,
                            icon: Icons.settings,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Build restaurant logo widget
  Widget _buildRestaurantLogo(UserModel? user) {
    if (user?.restaurantLogoUrl != null &&
        user!.restaurantLogoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: user.restaurantLogoUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => ShimmerEffect(
          width: double.infinity,
          height: double.infinity,
          borderRadius: BorderRadius.circular(8),
        ),
        errorWidget: (context, url, error) => _buildDefaultLogo(),
      );
    }

    return _buildDefaultLogo();
  }

  // Default logo when no restaurant logo is available
  Widget _buildDefaultLogo() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.restaurant, size: 24, color: Colors.grey),
      ),
    );
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return CustomButton(
      text: label,
      onPressed: onPressed,
      variant: ButtonVariant.filled,
      icon: icon,
      color: color,
    );
  }

  // Update the statistics builder method
  List<Widget> _buildStatistics(AppLocalizations l10n, Map<String, int> stats) {
    final statistics = [
      {
        'label': l10n.categories,
        'value': stats['categories'] ?? 0,
        'color': AppColors.info,
      },
      {
        'label': l10n.products,
        'value': stats['products'] ?? 0,
        'color': AppColors.success,
      },
      {
        'label': l10n.staff,
        'value': stats['staff'] ?? 0,
        'color': AppColors.primary,
      },
      {
        'label': l10n.suppliers,
        'value': stats['suppliers'] ?? 0,
        'color': AppColors.success,
      },
      {
        'label': l10n.purchases,
        'value': stats['purchases'] ?? 0,
        'color': Colors.orange,
      },
      {
        'label': l10n.sales,
        'value': stats['sales'] ?? 0,
        'color': Colors.green,
      },
      {
        'label': "Store Out",
        'value': stats['storeOuts'] ?? 0,
        'color': Colors.red,
      },
    ];

    return statistics
        .map(
          (stat) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${stat['label']}: ',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: '${stat['value']}',
                    style: TextStyle(
                      color: stat['color'] as Color,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();
  }
}

// Rest of the code remains the same (_PagedCategoryGrid, HoverableCategoryCard, etc.)
class _PagedCategoryGrid extends StatelessWidget {
  final List<Category> categories;
  final int currentPage;
  final Function(Category) onCategoryTap;

  const _PagedCategoryGrid({
    required this.categories,
    required this.currentPage,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 4 : 2);
    const rows = 3;
    final pageSize = crossAxisCount * rows;
    final start = (currentPage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, categories.length);
    final pageItems = categories.sublist(start, end);

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noCategoriesWithProductsFound,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      padding: const EdgeInsets.all(0),
      itemCount: pageItems.length,
      itemBuilder: (context, index) {
        final category = pageItems[index];

        return HoverableCategoryCard(
          category: category,
          onTap: () => onCategoryTap(category),
        );
      },
    );
  }
}

// HoverableCategoryCard remains the same
class HoverableCategoryCard extends StatefulWidget {
  final Category category;
  final VoidCallback onTap;

  const HoverableCategoryCard({
    required this.category,
    required this.onTap,
    super.key,
  });

  @override
  State<HoverableCategoryCard> createState() => _HoverableCategoryCardState();
}

class _HoverableCategoryCardState extends State<HoverableCategoryCard> {
  bool _isHovered = false;

  // Fallback icon if no image
  IconData getCategoryIcon(String name) {
    switch (name.toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'dinner':
        return Icons.dinner_dining;
      case 'fast food':
        return Icons.fastfood;
      case 'beverages':
        return Icons.local_drink;
      case 'desserts':
        return Icons.icecream;
      case 'snacks':
        return Icons.lunch_dining;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered ? primaryColor : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: primaryColor.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
            ],
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.category.imageUrl.isNotEmpty)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: widget.category.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => ShimmerEffect(
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          getCategoryIcon(widget.category.name),
                          size: 30,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    getCategoryIcon(widget.category.name),
                    size: 30,
                    color: Colors.grey.shade600,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                widget.category.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
