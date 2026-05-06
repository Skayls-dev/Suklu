import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/booking_model.dart';
import 'booking_providers.dart';

// ── Providers for form data ───────────────────────────────────────────────────
final _tutorsListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final snap = await ref.watch(firestoreProvider)
      .collection('tutor_profiles')
      .where('isActive', isEqualTo: true)
      .get();
  return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
});

final _subjectsListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final snap = await ref.watch(firestoreProvider)
      .collection('subjects')
      .where('isActive', isEqualTo: true)
      .get();
  return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
});

class BookingScreen extends ConsumerWidget {
  const BookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(userBookingsProvider);
    final role = ref.watch(authStateNotifierProvider).value?.role.toFirestoreString();
    final canCreateBooking = role == 'student';

    return Scaffold(
      appBar: AppBar(title: const Text('Mes réservations')),
      floatingActionButton: canCreateBooking
          ? FloatingActionButton.extended(
              onPressed: () => _showNewBookingSheet(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nouveau cours'),
            )
          : null,
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

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authStateNotifierProvider).value?.role.toFirestoreString() ?? 'student';
    final basePath = '/$role/booking';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('$basePath/${booking.id}', extra: booking),
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.school_outlined)),
          title: Text(booking.subjectId),
          subtitle: Text(booking.statusLabel),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${booking.durationMinutes} min'),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewBookingForm extends ConsumerStatefulWidget {
  const _NewBookingForm();
  @override
  ConsumerState<_NewBookingForm> createState() => _NewBookingFormState();
}

class _NewBookingFormState extends ConsumerState<_NewBookingForm> {
  String?  _selectedSubjectId;
  String?  _selectedTutorId;
  DateTime _scheduledAt     = DateTime.now().add(const Duration(days: 1));
  int      _durationMinutes = 60;

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (_selectedSubjectId == null || _selectedTutorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une matière et un tuteur')),
      );
      return;
    }

    try {
      await ref.read(bookingCreationProvider.notifier).createBooking(
        tutorId:         _selectedTutorId!,
        subjectId:       _selectedSubjectId!,
        scheduledAt:     _scheduledAt,
        durationMinutes: _durationMinutes,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réservation créée avec succès!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(_subjectsListProvider);
    final tutorsAsync   = ref.watch(_tutorsListProvider);
    final isLoading     = ref.watch(bookingCreationProvider).isLoading;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.lg,
        AppSpacing.md, MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nouveau cours', style: Theme.of(context).textTheme.titleLarge),
            AppSpacing.gapMd,

            // Matière
            subjectsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error:   (e, _) => Text('Erreur matières: $e'),
              data:    (subjects) => DropdownButtonFormField<String>(
                value: _selectedSubjectId,
                decoration: const InputDecoration(labelText: 'Matière'),
                items: subjects.map((s) => DropdownMenuItem(
                  value: s['id'] as String,
                  child: Text('${s['icon'] ?? ''} ${s['name'] ?? s['id']}'),
                )).toList(),
                onChanged: (v) => setState(() => _selectedSubjectId = v),
              ),
            ),
            AppSpacing.gapMd,

            // Tuteur
            tutorsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error:   (e, _) => Text('Erreur tuteurs: $e'),
              data:    (tutors) => DropdownButtonFormField<String>(
                value: _selectedTutorId,
                decoration: const InputDecoration(labelText: 'Tuteur'),
                items: tutors.map((t) => DropdownMenuItem(
                  value: t['id'] as String,
                  child: Text(t['fullName'] as String? ?? t['id'] as String),
                )).toList(),
                onChanged: (v) => setState(() => _selectedTutorId = v),
              ),
            ),
            AppSpacing.gapMd,

            // Date et heure
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                '${_scheduledAt.day}/${_scheduledAt.month}/${_scheduledAt.year}'
                ' à ${_scheduledAt.hour.toString().padLeft(2, '0')}h${_scheduledAt.minute.toString().padLeft(2, '0')}',
              ),
              subtitle: const Text('Date et heure du cours'),
              trailing: TextButton(onPressed: _pickDateTime, child: const Text('Changer')),
            ),
            AppSpacing.gapSm,

            // Durée
            DropdownButtonFormField<int>(
              value: _durationMinutes,
              decoration: const InputDecoration(labelText: 'Durée'),
              items: const [
                DropdownMenuItem(value: 30,  child: Text('30 minutes')),
                DropdownMenuItem(value: 60,  child: Text('1 heure')),
                DropdownMenuItem(value: 90,  child: Text('1h30')),
              ],
              onChanged: (v) => setState(() => _durationMinutes = v ?? 60),
            ),
            AppSpacing.gapLg,

            ElevatedButton(
              onPressed: isLoading ? null : _submit,
              child: isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Confirmer la réservation'),
            ),
          ],
        ),
      ),
    );
  }
}
