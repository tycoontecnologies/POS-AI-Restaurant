import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos/components/ui/custom_button.dart';
import 'package:pos/components/ui/custom_input.dart';
import 'package:pos/components/ui/data_table_widget.dart';
import 'package:pos/components/ui/custom_card.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:pos/models/ingredient.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/ingredient_provider.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:pos/utils/app_spacing.dart';

class IngredientsScreen extends StatefulWidget {
  const IngredientsScreen({super.key});
  @override
  State<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends State<IngredientsScreen> {
  final _units = const ['g', 'kg', 'litre', 'piece', 'pack'];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.currentUser != null) {
      context.read<IngredientProvider>().bindStream(auth.currentUser!.id);
    }
  }

  Future<void> _createOrEdit({Ingredient? item}) async {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final qtyCtrl = TextEditingController(
      text: (item?.quantityInStock ?? 0).toString(),
    );
    final lowCtrl = TextEditingController(
      text: (item?.lowStockThreshold ?? 20).toString(),
    );
    String unit = item?.unit ?? 'g';
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Ingredient>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFDFDFE),
        surfaceTintColor: Colors.transparent,
        title: Text(item == null ? 'Add Ingredient' : 'Edit Ingredient'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomInput(
                    label: l10n.name,
                    controller: nameCtrl,
                    hint: 'e.g., Tomato Sauce',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: CustomInput(
                          label: 'Quantity in Stock',
                          controller: qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            final x = double.tryParse(v ?? '');
                            if (x == null) return 'Enter valid number';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: unit,
                          decoration: InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSm,
                              ),
                            ),
                          ),
                          items: _units
                              .map(
                                (u) =>
                                    DropdownMenuItem(value: u, child: Text(u)),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => unit = v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  CustomInput(
                    label: 'Low Stock Threshold',
                    controller: lowCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final x = double.tryParse(v ?? '');
                      if (x == null) return 'Enter valid number';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          CustomButton(
            text: l10n.cancel,
            variant: ButtonVariant.text,
            onPressed: () => Navigator.pop(context),
          ),
          if (item == null)
            CustomButton(
              text: 'Add & Continue',
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final auth = context.read<AuthProvider>();
                  if (auth.currentUser == null) return;
                  final provider = context.read<IngredientProvider>();

                  final newIngredient = Ingredient(
                    id: '', // Let backend handle ID or assign temporarily
                    name: nameCtrl.text.trim(),
                    unit: unit,
                    quantityInStock: double.tryParse(qtyCtrl.text.trim()) ?? 0,
                    lowStockThreshold:
                        double.tryParse(lowCtrl.text.trim()) ?? 20,
                  );

                  await provider.add(auth.currentUser!.id, newIngredient);

                  // Reset form for next entry
                  nameCtrl.clear();
                  qtyCtrl.text = '0';
                  lowCtrl.text = '20';
                  unit = 'g';
                  setState(() {}); // Refresh the dropdown unit if needed
                }
              },
            ),
          CustomButton(
            text: l10n.save,
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(
                  context,
                  Ingredient(
                    id: item?.id ?? '',
                    name: nameCtrl.text.trim(),
                    unit: unit,
                    quantityInStock: double.tryParse(qtyCtrl.text.trim()) ?? 0,
                    lowStockThreshold:
                        double.tryParse(lowCtrl.text.trim()) ?? 20,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );

    if (result == null) return;
    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) return;
    final provider = context.read<IngredientProvider>();
    if (item == null) {
      await provider.add(auth.currentUser!.id, result);
    } else {
      await provider.update(auth.currentUser!.id, result.copyWith(id: item.id));
    }
  }

  Future<void> _delete(Ingredient item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete Ingredient'),
        content: Text('Delete "${item.name}"?'),
        actions: [
          CustomButton(
            text: 'Cancel',
            variant: ButtonVariant.text,
            onPressed: () => Navigator.pop(c, false),
          ),
          CustomButton(
            text: 'Delete',
            color: AppColors.error,
            onPressed: () => Navigator.pop(c, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) return;
    await context.read<IngredientProvider>().remove(
      auth.currentUser!.id,
      item.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<IngredientProvider>();
    final ingredients = provider.ingredients;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                      'Ingredients',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.grey800,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Manage your recipe ingredients and stock',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              CustomButton(
                text: 'Add New Ingredient',
                icon: Icons.add,
                onPressed: _createOrEdit,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ingredients.isEmpty
                ? Center(
                    child: CustomCard(
                      child: Text('No ingredients yet. Add your first one!'),
                    ),
                  )
                : SingleChildScrollView(
                    child: DataTableWidget(
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Unit')),
                        DataColumn(label: Text('In Stock')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: ingredients
                          .map(
                            (ing) => DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      if (ing.isLowStock) ...[
                                        const Icon(
                                          Icons.warning,
                                          color: AppColors.warning,
                                          size: 16,
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                      ],
                                      Text(ing.name),
                                    ],
                                  ),
                                ),
                                DataCell(Text(ing.unit)),
                                DataCell(
                                  Text(ing.quantityInStock.toStringAsFixed(2)),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: l10n.edit,
                                        icon: const Icon(Icons.edit, size: 18),
                                        onPressed: () =>
                                            _createOrEdit(item: ing),
                                        style: IconButton.styleFrom(
                                          backgroundColor: AppColors.primary
                                              .withOpacity(0.1),
                                          foregroundColor: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      IconButton(
                                        tooltip: l10n.delete,
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 18,
                                        ),
                                        onPressed: () => _delete(ing),
                                        style: IconButton.styleFrom(
                                          backgroundColor: AppColors.error
                                              .withOpacity(0.1),
                                          foregroundColor: AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
