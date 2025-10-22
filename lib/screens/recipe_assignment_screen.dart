import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos/components/ui/custom_button.dart';
import 'package:pos/components/ui/custom_card.dart';
import 'package:pos/components/ui/custom_dropdown.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:pos/models/ingredient.dart';
import 'package:pos/models/recipe.dart';
import 'package:pos/models/product.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/ingredient_provider.dart';
import 'package:pos/providers/product_provider.dart';
import 'package:pos/providers/recipe_provider.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:pos/utils/app_spacing.dart';

class RecipeAssignmentScreen extends StatefulWidget {
  const RecipeAssignmentScreen({super.key});

  @override
  State<RecipeAssignmentScreen> createState() => _RecipeAssignmentScreenState();
}

class _RecipeAssignmentScreenState extends State<RecipeAssignmentScreen> {
  String? _selectedProductId;
  Product? _selectedProduct;
  List<_RowItem> _rows = [];
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Ensure products & ingredients are loaded/bound
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null) {
        final pp = context.read<ProductProvider>();
        if (pp.products.isEmpty) {
          await pp.loadProducts(auth.currentUser!.id);
        }
        context.read<IngredientProvider>().bindStream(auth.currentUser!.id);
      }
    });
  }

  void _onProductChanged(String? id) async {
    setState(() {
      _selectedProductId = id;
      _selectedProduct = context
          .read<ProductProvider>()
          .products
          .firstWhere((p) => p.id == id);
      _rows = [];
    });

    // Load existing recipe if any
    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null || id == null) return;
    final existing =
        await context.read<RecipeProvider>().loadRecipe(auth.currentUser!.id, id);
    if (existing != null) {
      setState(() {
        _rows = existing.items
            .map((it) => _RowItem(
                  ingredientId: it.ingredientId,
                  quantity: it.quantityPerUnit,
                ))
            .toList();
      });
    }
  }

  void _addRow() {
    setState(() {
      _rows.add(_RowItem());
    });
  }

  void _removeRow(int index) {
    setState(() {
      _rows.removeAt(index);
    });
  }

  Future<void> _saveRecipe() async {
    if (_selectedProductId == null || _selectedProduct == null) return;
    if (!formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) return;

    final ingredients = context.read<IngredientProvider>().ingredients;
    final items = <RecipeItem>[];
    for (final row in _rows) {
      final ing =
          ingredients.firstWhere((i) => i.id == row.ingredientId, orElse: () => Ingredient(id: '', name: '', unit: 'g', quantityInStock: 0));
      if (ing.id.isEmpty) continue;
      items.add(RecipeItem(
        ingredientId: ing.id,
        ingredientName: ing.name,
        unit: ing.unit,
        quantityPerUnit: row.quantity ?? 0,
      ));
    }

    final recipe = ProductRecipe(
      productId: _selectedProductId!,
      productName: _selectedProduct!.name,
      items: items,
    );

    await context.read<RecipeProvider>().saveRecipe(
          auth.currentUser!.id,
          recipe,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 1),
          content: Text('Recipe saved'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final products = context.watch<ProductProvider>().products;
    final ingredients = context.watch<IngredientProvider>().ingredients;
    final recipeProvider = context.watch<RecipeProvider>();

    final currentRecipe =
        (_selectedProductId != null)
            ? recipeProvider.getRecipeCached(_selectedProductId!)
            : null;

    final producible = (_selectedProductId != null && currentRecipe != null)
        ? recipeProvider.computeUnitsProducible(ingredients, currentRecipe)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Product Recipe Assignment',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.grey800,
                          )),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Link ingredients to a product and manage stock usage automatically',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.grey600),
                  ),
                ],
              ),
            ),
            CustomButton(
              text: 'Add Ingredient',
              icon: Icons.add,
              onPressed: _addRow,
            ),
            const SizedBox(width: AppSpacing.sm),
            CustomButton(
              text: 'Save Recipe',
              onPressed: _saveRecipe,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomDropdown<String>(
                label: l10n.products,
                value: _selectedProductId,
                items: products
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name),
                        ))
                    .toList(),
                onChanged: _onProductChanged,
                hint: 'Select a product',
              ),
              const SizedBox(height: AppSpacing.md),
              Form(
                key: formKey,
                child: Column(
                  children: [
                    for (int i = 0; i < _rows.length; i++)
                      _RecipeRow(
                        key: ValueKey('row_$i'),
                        index: i,
                        row: _rows[i],
                        ingredients: ingredients,
                        onRemove: () => _removeRow(i),
                      ),
                    if (_rows.isEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Text(
                          'No ingredients added yet. Click "Add Ingredient" to start.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                  ],
                ),
              ),
              if (producible != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.06),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.factory, color: AppColors.secondary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Based on current stock, you can make $producible unit(s) of "${_selectedProduct?.name ?? ''}".',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.grey800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

class _RowItem {
  String? ingredientId;
  double? quantity;
  _RowItem({this.ingredientId, this.quantity});
}

class _RecipeRow extends StatelessWidget {
  const _RecipeRow({
    super.key,
    required this.index,
    required this.row,
    required this.ingredients,
    required this.onRemove,
  });
  final int index;
  final _RowItem row;
  final List<Ingredient> ingredients;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final selected =
        ingredients.where((i) => i.id == row.ingredientId).toList();
    final unit = selected.isNotEmpty ? selected.first.unit : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: DropdownButtonFormField<String>(
              value: row.ingredientId,
              decoration: InputDecoration(
                labelText: 'Ingredient',
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
              items: ingredients
                  .map((i) => DropdownMenuItem(
                        value: i.id,
                        child: Row(
                          children: [
                            if (i.isLowStock) ...[
                              const Icon(Icons.warning,
                                  size: 16, color: AppColors.warning),
                              const SizedBox(width: AppSpacing.xs),
                            ],
                            Text(i.name),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                row.ingredientId = v;
              },
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Select ingredient'
                  : null,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 3,
            child: TextFormField(
              initialValue:
                  row.quantity != null ? '${row.quantity}' : '',
              decoration: InputDecoration(
                labelText: 'Qty per Product',
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => row.quantity = double.tryParse(v),
              validator: (v) {
                final x = double.tryParse(v ?? '');
                if (x == null || x <= 0) return 'Enter valid qty';
                return null;
              },
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: TextFormField(
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Unit',
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusSm),
                ),
                hintText: unit.isEmpty ? '-' : unit,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          IconButton(
            tooltip: 'Remove',
            onPressed: onRemove,
            icon: const Icon(Icons.remove_circle, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}
