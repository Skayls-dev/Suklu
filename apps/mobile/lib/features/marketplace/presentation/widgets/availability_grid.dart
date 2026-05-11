import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/available_slot_model.dart';

class AvailabilityGrid extends StatelessWidget {
  const AvailabilityGrid({required this.availableSlots, super.key});

  final List<AvailableSlotModel> availableSlots;

  @override
  Widget build(BuildContext context) {
    if (availableSlots.isEmpty) {
      return Text(
        'Aucune disponibilité renseignée',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.grey600,
            ),
      );
    }

    final grouped = <int, List<AvailableSlotModel>>{};
    for (final slot in availableSlots) {
      grouped.putIfAbsent(slot.dayOfWeek, () => <AvailableSlotModel>[]).add(slot);
    }

    final sortedDays = grouped.keys.toList()..sort();

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: sortedDays.length,
      separatorBuilder: (_, __) => AppSpacing.gapSm,
      itemBuilder: (context, index) {
        final day = sortedDays[index];
        final slots = grouped[day]!;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  slots.first.dayLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
            Expanded(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: slots
                    .map(
                      (slot) => Chip(
                        label: Text('${slot.startHour}h-${slot.endHour}h'),
                        backgroundColor: AppColors.grey100,
                        side: BorderSide.none,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}