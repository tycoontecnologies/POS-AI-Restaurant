import 'package:flutter/material.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_colors.dart';

class SearchBarWidget extends StatelessWidget {
  final String? hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final TextEditingController? controller;
  final Widget? leading;
  final List<Widget>? actions;

  const SearchBarWidget({
    super.key,
    this.hint,
    this.onChanged,
    this.onClear,
    this.controller,
    this.leading,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.search, color: AppColors.grey500),
        hintText: hint ?? 'Search...',
        border: InputBorder.none,
        hintStyle: TextStyle(color: AppColors.grey500),
      ),
    );
  }
}
