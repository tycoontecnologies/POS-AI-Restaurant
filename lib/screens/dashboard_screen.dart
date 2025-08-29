import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:pos/models/product.dart';
import '../utils/responsive.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../services/dummy_data_service.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/custom_button.dart';
import '../routes/app_router.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late List<Product> _products;
  late Map<String, int> _statistics;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    // Make enough dummy items to demonstrate pagination
    final base = DummyDataService.getProducts();
    _products = List<Product>.generate(60, (index) {
      final b = base[index % base.length];
      return Product(
        id: '${index + 1}',
        name: '${b.name} ${index + 1}',
        category: b.category,
        unit: b.unit,
        salePrice: b.salePrice,
        purchasePrice: b.purchasePrice,
        quantity: b.quantity,
        active: b.active,
      );
    });
    _statistics = {
      'staff': 12,
      'products': 38,
      'drafts': 6,
      'categories': 3,
      'sales': 4,
      'salesReturn': 0,
      'suppliers': 2,
      'purchases': 0,
      'purchaseReturn': 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    int totalPages(BuildContext context) {
      final isDesktop = Responsive.isDesktop(context);
      final isTablet = Responsive.isTablet(context);
      final crossAxisCount = isDesktop ? 7 : (isTablet ? 4 : 2);
      const rows = 3;
      final pageSize = crossAxisCount * rows;
      return (_products.length / pageSize).ceil().clamp(1, 999);
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Row(
        children: [
          // Main Content Area
          Expanded(
            flex: Responsive.isDesktop(context) ? 3 : 1,
            child: Column(
              children: [
                // Header with pagination
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _currentPage = (_currentPage - 1).clamp(
                              1,
                              totalPages(context),
                            );
                          });
                        },
                        icon: const Icon(Icons.chevron_left),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _PageIndicator(
                        current: _currentPage,
                        total: totalPages(context),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _currentPage = (_currentPage + 1).clamp(
                              1,
                              totalPages(context),
                            );
                          });
                        },
                        icon: const Icon(Icons.chevron_right),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
                // Product Grid
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: _PagedGrid(
                      products: _products,
                      currentPage: _currentPage,
                    ),
                  ),
                ),
                // Statistics Bar
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
                          children: _buildStatistics(l10n),
                        )
                      : Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.sm,
                          children: _buildStatistics(l10n),
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
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: const Icon(
                                Icons.store,
                                color: Colors.white,
                                size: 24,
                              ),
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
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.language, size: 16),
                              const SizedBox(width: AppSpacing.sm),
                              const Text('English'),
                              const Spacer(),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
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
                              childAspectRatio: 1.7,
                              children: [
                                _buildQuickActionButton(
                                  l10n.sales,
                                  Icons.shopping_cart,
                                  const Color(0xFF8B5CF6),
                                  () => context.go(AppRouter.sales),
                                ),
                                _buildQuickActionButton(
                                  l10n.products,
                                  Icons.add_box,
                                  AppColors.success,
                                  () => context.go(AppRouter.products),
                                ),
                                _buildQuickActionButton(
                                  l10n.staff,
                                  Icons.people,
                                  const Color(0xFF8B5CF6),
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
                                  const Color(0xFF10B981),
                                  () => context.go(AppRouter.purchases),
                                ),
                                _buildQuickActionButton(
                                  'Purchase Return',
                                  Icons.assignment_return,
                                  const Color(0xFF06B6D4),
                                  () => context.go(AppRouter.purchases),
                                ),
                                _buildQuickActionButton(
                                  l10n.sales,
                                  Icons.point_of_sale,
                                  const Color(0xFFEC4899),
                                  () => context.go(AppRouter.sales),
                                ),
                                _buildQuickActionButton(
                                  'Sales Return',
                                  Icons.assignment_return,
                                  AppColors.warning,
                                  () => context.go(AppRouter.sales),
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

  List<Widget> _buildStatistics(AppLocalizations l10n) {
    final stats = [
      {
        'label': l10n.staff,
        'value': _statistics['staff']!,
        'color': AppColors.primary,
      },
      {
        'label': l10n.products,
        'value': _statistics['products']!,
        'color': AppColors.success,
      },
      {
        'label': l10n.drafts,
        'value': _statistics['drafts']!,
        'color': AppColors.warning,
      },
      {
        'label': l10n.categories,
        'value': _statistics['categories']!,
        'color': AppColors.info,
      },
      {
        'label': l10n.sales,
        'value': _statistics['sales']!,
        'color': AppColors.error,
      },
      {
        'label': 'Sales Return',
        'value': _statistics['salesReturn']!,
        'color': AppColors.primary,
      },
      {
        'label': l10n.suppliers,
        'value': _statistics['suppliers']!,
        'color': AppColors.success,
      },
      {
        'label': l10n.purchases,
        'value': _statistics['purchases']!,
        'color': AppColors.warning,
      },
      {
        'label': 'Purchase Return',
        'value': _statistics['purchaseReturn']!,
        'color': AppColors.info,
      },
    ];

    return stats
        .map(
          (stat) => RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${stat['label']}: ',
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
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
        )
        .toList();
  }
}

class _PagedGrid extends StatelessWidget {
  final List<Product> products;
  final int currentPage;
  const _PagedGrid({required this.products, required this.currentPage});

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);
    final crossAxisCount = isDesktop ? 7 : (isTablet ? 4 : 2);
    // Fixed rows: 3 to emulate screenshot height; no internal scrolling
    final rows = 3;
    final pageSize = crossAxisCount * rows;
    final start = (currentPage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, products.length);
    final pageItems = products.sublist(start, end);

    // Build a fixed-size Grid without scroll: wrap in LayoutBuilder and use NeverScrollableScrollPhysics
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.0,
      ),
      itemCount: pageItems.length,
      itemBuilder: (context, index) {
        final product = pageItems[index];
        return CustomCard(
          color: Colors.white,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.image, color: Colors.grey.shade500, size: 30),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                product.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _PageIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$current / $total',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Note: _totalPages is defined inside the State build method for access to _products.
