import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:pos/models/category.dart';
import 'package:pos/providers/category_provider.dart';
import 'package:pos/providers/product_provider.dart';
import 'package:pos/providers/statistics_provider.dart';
import 'package:provider/provider.dart';
import '../utils/responsive.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../components/ui/custom_button.dart';
import '../routes/app_router.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late CategoryProvider _categoryProvider;
  late ProductProvider _productProvider;
  late StatisticsProvider _statisticsProvider;

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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        // Main Content Area
        Expanded(
          flex: Responsive.isDesktop(context) ? 3 : 1,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Consumer<CategoryProvider>(
                    builder: (context, categoryProvider, child) {
                      if (categoryProvider.isLoading &&
                          categoryProvider.allCategories.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
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

                      // Get product provider to filter categories
                      final productProvider = Provider.of<ProductProvider>(
                        context,
                        listen: false,
                      );

                      // Filter categories to only show those with products > 0
                      final categoriesWithProducts = categories.where((
                        category,
                      ) {
                        final productsInCategory = productProvider.products
                            .where(
                              (product) => product.category == category.name,
                            )
                            .length;
                        return productsInCategory > 0;
                      }).toList();

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
                                'No categories with products found',
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
              ), // Statistics Bar
              Container(
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
                child: Responsive.isDesktop(context)
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
                      ),
              ),
            ],
          ),
        ),
        // Right Sidebar (Desktop only)
        if (Responsive.isDesktop(context))
          Container(
            width: 300,
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
                // Header
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  color: Colors.blue.shade50,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Image.asset('assets/logo.jpeg'),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tycoon POS',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Point of Sales',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                        const Text(
                          'Quick Actions',
                          style: TextStyle(
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
                              _buildQuickActionButton(
                                l10n.drafts,
                                Icons.drafts,
                                AppColors.accentDark,
                                () => context.go(AppRouter.drafts),
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
        'label': l10n.drafts,
        'value': stats['drafts'] ?? 0,
        'color': Colors.purple,
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
              "No categories available",
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
      case 'bbq':
      case 'barbecue':
        return Icons.outdoor_grill;
      case 'seafood':
        return Icons.set_meal; // closest match for fish/dish
      case 'pizza':
        return Icons.local_pizza;
      case 'soups':
      case 'soup':
        return Icons.ramen_dining;
      case 'bakery':
        return Icons.cake;
      case 'vegan':
      case 'vegetarian':
        return Icons.eco;
      case 'coffee':
      case 'cafe':
        return Icons.coffee;
      case 'chinese':
        return Icons.rice_bowl;
      case 'indian':
        return Icons.local_fire_department;
      case 'salads':
        return Icons.grass;
      case 'burgers':
        return Icons.lunch_dining;
      case 'noodles':
        return Icons.ramen_dining;
      case 'combo meals':
        return Icons.fastfood;
      case 'grill':
        return Icons.outdoor_grill;
      case 'drinks':
        return Icons.local_bar;
      case 'ice cream':
        return Icons.icecream;
      case 'wraps':
      case 'sandwiches':
        return Icons.restaurant;
      case 'specials':
      case 'chef special':
        return Icons.star;
      default:
        return Icons.category; // fallback icon
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
              color: _isHovered
                  ? primaryColor
                  : Colors.grey.shade300, // Light border when not hovered
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
              Icon(
                getCategoryIcon(widget.category.name),
                size: 40,
                color: primaryColor,
              ),
              const SizedBox(height: 12),
              Text(
                widget.category.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Consumer<ProductProvider>(
                builder: (context, productProvider, child) {
                  final productsInCategory = productProvider.products
                      .where(
                        (product) => product.category == widget.category.name,
                      )
                      .length;
                  return Text(
                    '$productsInCategory ${productsInCategory == 1 ? 'product' : 'products'}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
