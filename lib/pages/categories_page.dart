import 'package:flutter/material.dart';
import 'package:pos/l10n/app_localizations.dart';
import '../models/category.dart';
import '../services/dummy_data_service.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/custom_input.dart';
import '../components/ui/status_badge.dart';
import '../components/ui/data_table_widget.dart';
import '../components/ui/search_bar_widget.dart';
import '../utils/responsive.dart';
import '../utils/app_spacing.dart';
import '../utils/app_colors.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<Category> _categories = [];
  List<Category> _filteredCategories = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchController.addListener(_filterCategories);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCategories() {
    setState(() {
      _categories = DummyDataService.getCategories();
      _filteredCategories = _categories;
    });
  }

  void _filterCategories() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCategories = _categories
          .where((category) => category.name.toLowerCase().contains(query))
          .toList();
    });
  }

  void _createOrEdit({Category? item}) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: item?.name ?? '');
    bool isActive = item?.active ?? true;

    final result = await showDialog<_CategoryFormResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFDFDFE), // Soft off-white
              surfaceTintColor:
                  Colors.transparent, // Prevents Material 3 color overlay
              title: Text(item == null ? l10n.addCategory : l10n.editCategory),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomInput(
                      label: l10n.name,
                      controller: controller,
                      hint: 'Enter category name',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Text(
                          l10n.active,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const Spacer(),
                        Switch(
                          value: isActive,
                          onChanged: (v) => setDialogState(() => isActive = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                CustomButton(
                  text: l10n.cancel,
                  variant: ButtonVariant.text,
                  onPressed: () => Navigator.pop(context),
                ),
                CustomButton(
                  text: l10n.save,
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      Navigator.pop(
                        context,
                        _CategoryFormResult(
                          name: controller.text.trim(),
                          active: isActive,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    setState(() {
      if (item == null) {
        _categories.add(
          Category(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: result.name,
            active: result.active,
          ),
        );
      } else {
        item.name = result.name;
        item.active = result.active;
      }
      _filterCategories();
    });
  }

  void _delete(Category item) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFDFDFE), // Soft off-white
        surfaceTintColor:
            Colors.transparent, // Prevents Material 3 color overlay

        title: Text(l10n.deleteConfirmTitle('Category')),
        content: Text(l10n.deleteConfirmMessage(item.name)),
        actions: [
          CustomButton(
            text: l10n.cancel,
            variant: ButtonVariant.text,
            onPressed: () => Navigator.pop(context, false),
          ),
          CustomButton(
            text: l10n.delete,
            color: AppColors.error,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _categories.removeWhere((c) => c.id == item.id);
        _filterCategories();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: Responsive.getPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.categories,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.grey800,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Manage your product categories',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              CustomButton(
                text: l10n.addCategory,
                icon: Icons.add,
                onPressed: () => _createOrEdit(),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          SearchBarWidget(
            controller: _searchController,
            hint: 'Search categories...',
            onChanged: (_) => _filterCategories(),
            onClear: () => _filterCategories(),
          ),

          Flexible(
            fit: FlexFit.loose,
            child: CustomCard(
              padding: EdgeInsets.zero,
              child: DataTableWidget(
                columns: [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text(l10n.name)),
                  DataColumn(label: Text(l10n.status)),
                  DataColumn(label: Text(l10n.createdOn)),
                  DataColumn(label: Text(l10n.actions)),
                ],
                rows: _filteredCategories
                    .map(
                      (e) => DataRow(
                        cells: [
                          DataCell(Text(e.id)),
                          DataCell(Text(e.name)),
                          DataCell(
                            StatusBadge(
                              text: e.active ? l10n.active : l10n.inactive,
                              variant: e.active
                                  ? BadgeVariant.success
                                  : BadgeVariant.neutral,
                            ),
                          ),
                          DataCell(
                            Text(
                              e.createdOn.toIso8601String().substring(0, 10),
                            ),
                          ),
                          DataCell(_rowActions(e)),
                        ],
                      ),
                    )
                    .toList(),
                mobileItemBuilder: (context, index) {
                  final item = _filteredCategories[index];
                  return CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            StatusBadge(
                              text: item.active ? l10n.active : l10n.inactive,
                              variant: item.active
                                  ? BadgeVariant.success
                                  : BadgeVariant.neutral,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'ID: ${item.id} • Created: ${item.createdOn.toIso8601String().substring(0, 10)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.grey600),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [_rowActions(item)],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowActions(Category item) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.edit,
          icon: const Icon(Icons.edit, size: 18),
          onPressed: () => _createOrEdit(item: item),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            foregroundColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          tooltip: l10n.delete,
          icon: const Icon(Icons.delete, size: 18),
          onPressed: () => _delete(item),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.error.withOpacity(0.1),
            foregroundColor: AppColors.error,
          ),
        ),
      ],
    );
  }
}

class _CategoryFormResult {
  _CategoryFormResult({required this.name, required this.active});
  final String name;
  final bool active;
}
