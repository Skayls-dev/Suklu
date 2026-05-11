import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class SubjectChip extends StatelessWidget {
  const SubjectChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: isSelected,
      onSelected: (_) => onTap(),
      label: Text(label),
      selectedColor: AppColors.primary.withAlpha(36),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryDark : AppColors.grey600,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.grey200,
      ),
    );
  }
}