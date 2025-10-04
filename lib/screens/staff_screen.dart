// staff_screen.dart - UPDATED VERSION WITH FORM VALIDATION
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pos/components/ui/custom_input.dart';
import 'package:pos/components/ui/shimmer_effect.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/data_table_widget.dart';
import '../models/staff.dart';
import '../providers/staff_provider.dart';
import '../utils/app_spacing.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _initialLoadComplete = false;
  bool _isProcessing = false;

  // Tutorial coach mark controller and targets
  TutorialCoachMark? tutorialCoachMark;
  final GlobalKey _addButtonKey = GlobalKey();
  final GlobalKey _searchBarKey = GlobalKey();
  final GlobalKey _staffTableKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _checkAndShowTutorial();

    // Load initial data after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfHasData();
    });
  }

  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('staff_tutorial_seen') ?? false;

    if (!hasSeenTutorial) {
      // Wait for the UI to build before showing the tutorial
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _showTutorial(context);
          prefs.setBool('staff_tutorial_seen', true);
        });
      });
    }
  }

  void _showTutorial(BuildContext context) {
    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black38,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        print("Staff tutorial completed");
      },
      onClickTarget: (target) {
        print(target);
      },
      onSkip: () {
        print("Staff tutorial skipped");
        return true;
      },
    );

    tutorialCoachMark!.show(context: context);
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(
        identify: "add_button",
        keyTarget: _addButtonKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Add Employee",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tap here to add new employees to your team.",
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 8,
      ),
      TargetFocus(
        identify: "search_bar",
        keyTarget: _searchBarKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Search Employees",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Search for employees by name, role, or other details.",
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 8,
      ),
      TargetFocus(
        identify: "staff_table",
        keyTarget: _staffTableKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Employee List",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "View all your employees here. Use the action buttons to edit or delete employee records.",
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 8,
      ),
    ];
  }

  Future<void> _checkIfHasData() async {
    final provider = Provider.of<StaffProvider>(context, listen: false);
    await provider.loadStaff();
    setState(() {
      _initialLoadComplete = true;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    tutorialCoachMark?.finish();
    super.dispose();
  }

  void _onSearchChanged() {
    final provider = Provider.of<StaffProvider>(context, listen: false);
    provider.filterStaff(_searchController.text);
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final provider = Provider.of<StaffProvider>(context, listen: false);
      await provider.loadMoreStaff();
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  void _createOrEdit({Staff? item}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final l10n = AppLocalizations.of(context)!;
    final provider = Provider.of<StaffProvider>(context, listen: false);

    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final roleCtrl = TextEditingController(text: item?.role ?? '');
    final phoneCtrl = TextEditingController(text: item?.phone ?? '');
    final addressCtrl = TextEditingController(text: item?.address ?? '');
    final wageCtrl = TextEditingController(
      text: item?.dailyWage.toString() ?? '',
    );
    DateTime createdOn = item?.joinDate ?? DateTime.now();

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final result = await showDialog<_StaffFormResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Validation functions
          String? validateRequired(String? value, String fieldName) {
            if (value == null || value.isEmpty) {
              return '$fieldName is required';
            }
            return null;
          }

          String? validateWage(String? value) {
            if (value == null || value.isEmpty) {
              return null; // Wage is optional
            }
            final wage = double.tryParse(value);
            if (wage == null) {
              return 'Please enter a valid number';
            }
            if (wage < 0) {
              return 'Wage cannot be negative';
            }
            return null;
          }

          return AlertDialog(
            backgroundColor: const Color(0xFFFDFDFE),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              item == null ? 'Add Employee' : 'Edit Employee',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// Employee Role
                      CustomInput(
                        label: 'Employee Role',
                        hint: 'e.g. Waiter',
                        controller: roleCtrl,
                        validator: (value) => validateRequired(value, 'Role'),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      /// Name
                      CustomInput(
                        label: 'Name',
                        controller: nameCtrl,
                        validator: (value) => validateRequired(value, 'Name'),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      /// Daily Wage
                      CustomInput(
                        label: 'Daily Wage',
                        controller: wageCtrl,
                        prefixIcon: const Icon(Icons.attach_money),
                        validator: validateWage,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      /// Phone Number
                      Theme(
                        data: Theme.of(context).copyWith(
                          inputDecorationTheme: InputDecorationTheme(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSm,
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.grey300,
                              ),
                            ),
                            filled: true,
                            fillColor: AppColors.grey50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.md,
                            ),
                          ),
                        ),
                        child: FormField<String>(
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Phone number is required';
                            }

                            // Extract just the digits for validation
                            final digitsOnly = value.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            );

                            // Check if we have a reasonable number of digits
                            // (country code + phone number, typically at least 8 digits)
                            if (digitsOnly.length < 8) {
                              return 'Please enter a valid phone number';
                            }

                            return null;
                          },
                          builder: (field) => IntlPhoneField(
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              errorText: field.errorText,
                              labelText: 'Phone Number',
                            ),
                            initialCountryCode: 'PK',
                            // disableLengthCheck: true,
                            keyboardType:
                                TextInputType.phone, // Numeric keyboard
                            inputFormatters: [
                              FilteringTextInputFormatter
                                  .digitsOnly, // Only allow digits
                            ],
                            onChanged: (phone) {
                              // Set full number for backend use
                              phoneCtrl.text = phone.completeNumber;

                              // Notify FormField about the change
                              field.didChange(phone.completeNumber);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      /// Address
                      CustomInput(
                        label: 'Address',
                        controller: addressCtrl,
                        maxLines: 1,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      /// Join Date
                      Row(
                        children: [
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Join Date',
                                border: OutlineInputBorder(),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.sm,
                                ),
                                child: Text(
                                  '${createdOn.toLocal()}'.split(' ').first,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          SizedBox(
                            height: 48,
                            child: CustomButton(
                              text: 'Pick Date',
                              variant: ButtonVariant.outlined,
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: createdOn,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setDialogState(() => createdOn = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            actionsAlignment: MainAxisAlignment.end,
            actions: [
              CustomButton(
                text: l10n.cancel,
                variant: ButtonVariant.text,
                onPressed: () => Navigator.pop(context),
              ),
              CustomButton(
                text: l10n.save,
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final wage = double.tryParse(wageCtrl.text.trim()) ?? 0;
                    Navigator.pop(
                      context,
                      _StaffFormResult(
                        role: roleCtrl.text.trim(),
                        name: nameCtrl.text.trim(),
                        dailyWage: wage,
                        phone: phoneCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        createdOn: createdOn,
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );

    if (result == null) {
      setState(() => _isProcessing = false);
      return;
    }

    try {
      if (item == null) {
        final newStaff = Staff(
          id: '', // Will be auto-generated by Firebase
          name: result.name,
          role: result.role,
          dailyWage: result.dailyWage,
          phone: result.phone,
          address: result.address,
          joinDate: result.createdOn,
        );
        await provider.addStaff(newStaff);
      } else {
        final updatedStaff = item.copyWith(
          name: result.name,
          role: result.role,
          dailyWage: result.dailyWage,
          phone: result.phone,
          address: result.address,
          joinDate: result.createdOn,
        );
        await provider.updateStaff(updatedStaff);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: Duration(seconds: 1),
            content: Text(
              item == null
                  ? 'Employee added successfully'
                  : 'Employee updated successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Check if this was the first staff added
        // if (item == null) {
        //   final prefs = await SharedPreferences.getInstance();
        //   final hasSeenSuppliers =
        //       prefs.getBool('onboarding_suppliers_seen') ?? false;

        //   if (!hasSeenSuppliers) {
        //     // ADD DELAY AND SAFETY CHECK
        //     await Future.delayed(const Duration(milliseconds: 1000));
        //     if (mounted && context.mounted) {
        //       // MARK AS SEEN BEFORE NAVIGATING
        //       await prefs.setBool('onboarding_suppliers_seen', true);
        //       context.go(AppRouter.suppliers);
        //     }
        //   }
        // }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: Duration(seconds: 1),
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _delete(Staff s) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    final provider = Provider.of<StaffProvider>(context, listen: false);

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFDFDFE),
        surfaceTintColor: Colors.transparent,
        title: const Text('Delete Employee'),
        content: Text('Are you sure you want to delete ${s.name}?'),
        actions: [
          CustomButton(
            text: 'Cancel',
            variant: ButtonVariant.text,
            onPressed: () => Navigator.pop(context, false),
          ),
          CustomButton(
            text: 'Delete',
            color: Colors.red,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await provider.deleteStaff(s.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 1),
              content: Text('Employee deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: Duration(seconds: 1),
              content: Text('Error deleting employee: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = Provider.of<StaffProvider>(context);

    if (!_initialLoadComplete) {
      if (provider.errorMessage != null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: ${provider.errorMessage}'),
              ElevatedButton(
                onPressed: () => _checkIfHasData(),
                child: Text('Retry'),
              ),
            ],
          ),
        );
      }
      return _buildShimmerTable();
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                      l10n.staff,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Manage your team members',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              CustomButton(
                key: _addButtonKey,
                text: 'Add Employee',
                icon: Icons.person_add,
                onPressed: (provider.isLoading || _isProcessing)
                    ? null
                    : () => _createOrEdit(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SearchBarWidget(
            key: _searchBarKey,

            controller: _searchController,
            hint: 'Search employees...',
            onChanged: (_) => _onSearchChanged(),
            onClear: () {
              _searchController.clear();
              _onSearchChanged();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            key: _staffTableKey,
            child: provider.isLoading && provider.staff.isEmpty
                ? _buildShimmerTable()
                : provider.errorMessage != null
                ? CustomCard(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Error loading staff data',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            provider.errorMessage!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          CustomButton(
                            text: 'Retry',
                            onPressed: () {
                              provider.clearError();
                              provider.loadStaff(refresh: true);
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (scrollNotification) {
                      if (scrollNotification is ScrollEndNotification &&
                          _scrollController.position.pixels ==
                              _scrollController.position.maxScrollExtent) {
                        _loadMore();
                      }
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: _buildStaffContent(provider),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffContent(StaffProvider provider) {
    final staffList = provider.filteredStaff;

    if (staffList.isEmpty && _searchController.text.isEmpty) {
      return CustomCard(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No staff members found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Add your first employee to get started',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              CustomButton(
                text: 'Add Employee',
                icon: Icons.person_add,
                onPressed: _isProcessing ? null : () => _createOrEdit(),
              ),
            ],
          ),
        ),
      );
    }

    if (staffList.isEmpty && _searchController.text.isNotEmpty) {
      return CustomCard(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No employees found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Try a different search term',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: DataTableWidget(
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('Employee Role')),
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Daily Wage')),
          DataColumn(label: Text('Contact Number')),
          DataColumn(label: Text('Join Date')),
          DataColumn(label: Text('Actions')),
        ],
        rows: staffList.asMap().entries.map((entry) {
          final index = entry.key;
          final e = entry.value;

          return DataRow(
            cells: [
              DataCell(Text('${index + 1}')),
              DataCell(Text(e.role)),
              DataCell(Text(e.name)),
              DataCell(Text(e.dailyWage.toStringAsFixed(0))),
              DataCell(Text(e.phone)),
              DataCell(Text('${e.joinDate.toLocal()}'.split(' ').first)),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: _isProcessing
                          ? null
                          : () => _createOrEdit(item: e),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18),
                      onPressed: _isProcessing ? null : () => _delete(e),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.error.withOpacity(0.1),
                        foregroundColor: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildShimmerTable() {
    return DataTableWidget(
      columns: List.generate(
        7,
        (index) => DataColumn(label: ShimmerEffect(width: 80, height: 20)),
      ),
      rows: List.generate(
        5,
        (index) => DataRow(
          cells: List.generate(
            7,
            (index) => DataCell(ShimmerEffect(width: 80, height: 20)),
          ),
        ),
      ),
      mobileItemBuilder: (context, index) {
        return CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerEffect(width: double.infinity, height: 20),
              SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 120, height: 16),
              SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 100, height: 16),
              SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ShimmerEffect(
                    width: 36,
                    height: 36,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  ShimmerEffect(
                    width: 36,
                    height: 36,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// Helper class to pass form results
class _StaffFormResult {
  final String role;
  final String name;
  final double dailyWage;
  final String phone;
  final String address;
  final DateTime createdOn;

  _StaffFormResult({
    required this.role,
    required this.name,
    required this.dailyWage,
    required this.phone,
    required this.address,
    required this.createdOn,
  });
}
