import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/firebase_providers.dart';
import '../domain/booking_model.dart';
import 'booking_providers.dart';

// ── Provider: confirm or cancel a booking ─────────────────────────────────────
final _updateStatusProvider =
    AsyncNotifierProvider.autoDispose<_UpdateStatusNotifier, void>(
  _UpdateStatusNotifier.new,
);

class _UpdateStatusNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> changeStatus(String bookingId, String status) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final fn = ref.read(firebaseFunctionsProvider);
      await fn.httpsCallable('updateBookingStatus').call({
        'bookingId': bookingId,
        'status':    status,
      });
    });
  }
}

// ── Main screen ───────────────────────────────────────────────────────────────
class TutorAgendaScreen extends ConsumerStatefulWidget {
  const TutorAgendaScreen({super.key});

  @override
  ConsumerState<TutorAgendaScreen> createState() => _TutorAgendaScreenState();
}

class _TutorAgendaScreenState extends ConsumerState<TutorAgendaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.tutorAccent,
        title: const Text('Mon agenda'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'À confirmer'),
            Tab(text: 'Confirmées'),
            Tab(text: 'Historique'),
          ],
        ),
      ),
      body: ref.watch(userBookingsProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Erreur: $e')),
        data:    (all) {
          final pending   = all.where((b) => b.status == BookingStatus.pending).toList();
          final confirmed = all.where((b) => b.status == BookingStatus.confirmed).toList();
          final history   = all.where((b) =>
              b.status == BookingStatus.completed ||
              b.status == BookingStatus.cancelled).toList();

          return TabBarView(
            controller: _tabs,
            children: [
              _BookingList(
                bookings: pending,
                emptyMessage: 'Aucune demande en attente',
                emptyIcon: Icons.hourglass_empty,
                itemBuilder: (b) => _PendingCard(booking: b),
              ),
              _BookingList(
                bookings: confirmed,
                emptyMessage: 'Aucune session confirmée',
                emptyIcon: Icons.event_available_outlined,
                itemBuilder: (b) => _ConfirmedCard(booking: b),
              ),
              _BookingList(
                bookings: history,
                emptyMessage: 'Aucun historique',
                emptyIcon: Icons.history,
                itemBuilder: (b) => _HistoryCard(booking: b),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Reusable list wrapper ─────────────────────────────────────────────────────
class _BookingList extends StatelessWidget {
  const _BookingList({
    required this.bookings,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.itemBuilder,
  });

  final List<BookingModel>            bookings;
  final String                        emptyMessage;
  final IconData                      emptyIcon;
  final Widget Function(BookingModel) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(emptyIcon, size: 56, color: AppColors.grey400),
          const SizedBox(height: 12),
          Text(emptyMessage,
              style: const TextStyle(color: AppColors.grey600, fontSize: 15)),
        ]),
      );
    }
    return ListView.builder(
      padding: AppSpacing.pagePadding,
      itemCount: bookings.length,
      itemBuilder: (_, i) => itemBuilder(bookings[i]),
    );
  }
}

// ── Pending card: confirm / decline ──────────────────────────────────────────
class _PendingCard extends ConsumerWidget {
  const _PendingCard({required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(_updateStatusProvider).isLoading;
    final fmt = DateFormat('EEE d MMM – HH:mm', 'fr');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.orange, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.school_outlined, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(booking.subjectId,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange),
              ),
              child: const Text('En attente',
                  style: TextStyle(color: Colors.orange, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.calendar_today_outlined,
              text: fmt.format(booking.scheduledAt)),
          _InfoRow(icon: Icons.timer_outlined,
              text: '${booking.durationMinutes} min'),
          _InfoRow(icon: Icons.attach_money,
              text: '${booking.totalAmount.toStringAsFixed(0)} ${booking.currency.toUpperCase()}'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Refuser'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: isLoading
                    ? null
                    : () => _confirm(context, ref, 'cancelled',
                        'Refuser cette réservation ?'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Confirmer'),
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.green),
                onPressed: isLoading
                    ? null
                    : () => _confirm(context, ref, 'confirmed',
                        'Confirmer cette réservation ?'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _confirm(
      BuildContext context, WidgetRef ref, String status, String question) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(question),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmer')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    await ref.read(_updateStatusProvider.notifier).changeStatus(booking.id, status);

    if (!context.mounted) return;
    final err = ref.read(_updateStatusProvider).error;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $err'), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'confirmed'
            ? 'Réservation confirmée ✓'
            : 'Réservation refusée'),
        backgroundColor: status == 'confirmed' ? Colors.green : Colors.red,
      ));
    }
  }
}

// ── Confirmed card: start session ─────────────────────────────────────────────
class _ConfirmedCard extends StatelessWidget {
  const _ConfirmedCard({required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE d MMM – HH:mm', 'fr');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.green, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.school_outlined, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(booking.subjectId,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green),
              ),
              child: const Text('Confirmée',
                  style: TextStyle(color: Colors.green, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.calendar_today_outlined,
              text: fmt.format(booking.scheduledAt)),
          _InfoRow(icon: Icons.timer_outlined,
              text: '${booking.durationMinutes} min'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Démarrer la session'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.tutorAccent),
              onPressed: () => context.push('/tutor/session/${booking.id}'),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── History card: read-only ───────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final fmt   = DateFormat('d MMM yyyy', 'fr');
    final color = booking.status == BookingStatus.completed
        ? Colors.blueGrey
        : Colors.red.shade300;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/tutor/booking/${booking.id}', extra: booking),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(
                booking.status == BookingStatus.completed
                    ? Icons.done_all
                    : Icons.cancel_outlined,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.subjectId,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(fmt.format(booking.scheduledAt),
                    style: const TextStyle(
                        color: AppColors.grey600, fontSize: 13)),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${booking.durationMinutes} min',
                  style: const TextStyle(fontSize: 13)),
              Text(booking.statusLabel,
                  style: TextStyle(color: color, fontSize: 12)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Small helper row ──────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String   text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Icon(icon, size: 15, color: AppColors.grey600),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: AppColors.grey600, fontSize: 13)),
    ]),
  );
}
