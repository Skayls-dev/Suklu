import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import 'booking_providers.dart';

class BookingScreen extends ConsumerWidget {
  const BookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(studentBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes réservations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewBookingSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau cours'),
      ),
      body: bookingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Erreur: $e')),
        data:    (bookings) => bookings.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: AppSpacing.pagePadding,
                itemCount: bookings.length,
                itemBuilder: (context, i) => _BookingCard(booking: bookings[i]),
              ),
      ),
    );
  }

  void _showNewBookingSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => const _NewBookingForm(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.calendar_today_outlined, size: 64, color: AppColors.grey400),
      AppSpacing.gapMd,
      Text('Aucune réservation', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.grey600)),
    ]),
  );
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});
  final dynamic booking; // BookingModel

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.school_outlined)),
      title: Text(booking.subjectId),
      subtitle: Text(booking.statusLabel),
      trailing: Text('${booking.durationMinutes} min'),
    ),
  );
}

class _NewBookingForm extends ConsumerStatefulWidget {
  const _NewBookingForm();
  @override
  ConsumerState<_NewBookingForm> createState() => _NewBookingFormState();
}

class _NewBookingFormState extends ConsumerState<_NewBookingForm> {
  final _subjectCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.lg,
        AppSpacing.md, MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nouveau cours', style: Theme.of(context).textTheme.titleLarge),
          AppSpacing.gapMd,
          TextFormField(
            controller: _subjectCtrl,
            decoration: const InputDecoration(labelText: 'Matière'),
          ),
          AppSpacing.gapMd,
          // TODO: tutor selection, date/time picker
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }
}
