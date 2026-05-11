import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';

class DiagnosticProgressBar extends StatelessWidget {
  const DiagnosticProgressBar({
    required this.current,
    required this.max,
    super.key,
  });

  final int current;
  final int max;

  @override
  Widget build(BuildContext context) {
    if (current <= 0) return const SizedBox.shrink();

    final safeCurrent = current > max ? max : current;
    final value = max == 0 ? 0.0 : safeCurrent / max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question $safeCurrent / $max',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        AppSpacing.gapXs,
        LinearProgressIndicator(
          value: value,
          color: AppColors.primary,
          backgroundColor: AppColors.grey200,
          minHeight: 6,
        ),
      ],
    );
  }
}
