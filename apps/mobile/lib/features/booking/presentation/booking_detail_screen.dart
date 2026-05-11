import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/mixins/offline_guard_mixin.dart';
import '../../../core/providers/firebase_providers.dart';
import '../domain/booking_model.dart';

// ── Provider: load a single booking by ID ────────────────────────────────────
final bookingByIdProvider = FutureProvider.autoDispose.family<BookingModel?, String>((ref, id) async {
  final snap = await ref.watch(firestoreProvider).collection('bookings').doc(id).get();
  if (!snap.exists) return null;
  return BookingModel.fromFirestore(snap);
});

final tutorDisplayNameProvider = FutureProvider.autoDispose.family<String, String>((ref, tutorId) async {
  final firestore = ref.watch(firestoreProvider);

  final tutorProfileById = await firestore.collection('tutor_profiles').doc(tutorId).get();
  if (tutorProfileById.exists) {
    final data = tutorProfileById.data() ?? <String, dynamic>{};
    final fullName = (data['fullName'] ?? '').toString().trim();
    if (fullName.isNotEmpty) return fullName;
  }

  final tutorProfileByUid = await firestore
      .collection('tutor_profiles')
      .where('uid', isEqualTo: tutorId)
      .limit(1)
      .get();
  if (tutorProfileByUid.docs.isNotEmpty) {
    final data = tutorProfileByUid.docs.first.data();
    final fullName = (data['fullName'] ?? '').toString().trim();
    if (fullName.isNotEmpty) return fullName;
  }

  final userDoc = await firestore.collection('users').doc(tutorId).get();
  if (userDoc.exists) {
    final data = userDoc.data() ?? <String, dynamic>{};
    final displayName = (data['displayName'] ?? '').toString().trim();
    if (displayName.isNotEmpty) return displayName;
  }

  return tutorId;
});

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({super.key, required this.bookingId, this.booking});

  final String        bookingId;
  final BookingModel? booking; // may be passed directly to avoid extra fetch

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (booking != null) {
      return _DetailView(booking: booking!);
    }
    final async = ref.watch(bookingByIdProvider(bookingId));
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Réservation')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Réservation')),
        body: Center(child: Text('Erreur: $e')),
      ),
      data: (b) => b == null
          ? Scaffold(
              appBar: AppBar(title: const Text('Réservation')),
              body: const Center(child: Text('Réservation introuvable')),
            )
          : _DetailView(booking: b),
    );
  }
}

class _DetailView extends ConsumerStatefulWidget {
  const _DetailView({required this.booking});
  final BookingModel booking;

  @override
  ConsumerState<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends ConsumerState<_DetailView>
  with OfflineGuardMixin<_DetailView> {
  BookingModel get booking => widget.booking;

  Color _statusColor() => switch (booking.status) {
    BookingStatus.confirmed => Colors.green,
    BookingStatus.cancelled => Colors.red,
    BookingStatus.completed => Colors.blueGrey,
    BookingStatus.pending   => Colors.orange,
  };

  IconData _statusIcon() => switch (booking.status) {
    BookingStatus.confirmed => Icons.check_circle_outline,
    BookingStatus.cancelled => Icons.cancel_outlined,
    BookingStatus.completed => Icons.done_all,
    BookingStatus.pending   => Icons.hourglass_empty,
  };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEEE d MMMM yyyy – HH:mm', 'fr');
    final color = _statusColor();
    final role = ref.watch(authStateNotifierProvider).value?.role.toFirestoreString();
    final canOpenMarketplace = role == 'student';
    final tutorNameAsync = ref.watch(tutorDisplayNameProvider(booking.tutorId));
    final tutorName = tutorNameAsync.valueOrNull ?? 'Chargement...';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de la réservation'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            Center(
              child: Chip(
                avatar: Icon(_statusIcon(), color: Colors.white, size: 18),
                label: Text(
                  booking.statusLabel,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Subject card
            _InfoCard(
              icon: Icons.school_outlined,
              title: 'Matière',
              value: booking.subjectId,
              onTap: canOpenMarketplace
                  ? () => context.push('/student/marketplace?subjectId=${booking.subjectId}')
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),

            _InfoCard(
              icon: Icons.person_outline,
              title: 'Tuteur',
              value: tutorName,
              onTap: canOpenMarketplace
                  ? () => context.push('/student/marketplace/${booking.tutorId}')
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),

            _InfoCard(
              icon: Icons.calendar_today_outlined,
              title: 'Date & heure',
              value: fmt.format(booking.scheduledAt),
            ),
            const SizedBox(height: AppSpacing.md),

            _InfoCard(
              icon: Icons.timer_outlined,
              title: 'Durée',
              value: '${booking.durationMinutes} minutes',
            ),
            const SizedBox(height: AppSpacing.md),

            _InfoCard(
              icon: Icons.category_outlined,
              title: 'Type',
              value: booking.sessionType == SessionType.oneOnOne ? 'Individuel' : 'Groupe',
            ),
            const SizedBox(height: AppSpacing.md),

            _InfoCard(
              icon: Icons.attach_money,
              title: 'Montant',
              value: '${booking.totalAmount.toStringAsFixed(2)} ${booking.currency.toUpperCase()}',
            ),
            const SizedBox(height: AppSpacing.xl),

            // Action buttons
            if (booking.status == BookingStatus.pending)
              _ActionButton(
                icon: Icons.payment_outlined,
                label: 'Payer maintenant',
                color: Colors.green.shade700,
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Paiement — disponible prochainement')),
                ),
              ),

            if (booking.status == BookingStatus.confirmed)
              _ActionButton(
                icon: Icons.videocam_outlined,
                label: 'Rejoindre la session',
                color: AppColors.primary,
                onPressed: () {
                  final role = ref.read(authStateNotifierProvider).value?.role.toFirestoreString();
                  if (role == 'student') {
                    context.push('/student/session/${booking.id}');
                    return;
                  }
                  if (role == 'tutor') {
                    context.push('/tutor/session/${booking.id}');
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Accès session indisponible pour ce rôle')),
                  );
                },
              ),

            if (booking.status == BookingStatus.pending ||
                booking.status == BookingStatus.confirmed) ...[
              const SizedBox(height: AppSpacing.md),
              _ActionButton(
                icon: Icons.cancel_outlined,
                label: 'Annuler la réservation',
                color: Colors.red,
                outlined: true,
                onPressed: () => _confirmCancel(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    guardOnline(context, () async {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Annuler la réservation ?'),
          content: const Text('Cette action est irréversible.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Retour'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Annulation — disponible prochainement')),
                );
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );
    });
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });
  final IconData icon;
  final String   title;
  final String   value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.grey[600])),
                  const SizedBox(height: 2),
                  Text(value, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: AppColors.grey400),
          ],
        ),
      ),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.outlined = false,
  });

  final IconData   icon;
  final String     label;
  final Color      color;
  final VoidCallback? onPressed;
  final bool       outlined;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: outlined
        ? OutlinedButton.icon(
            icon: Icon(icon, color: color),
            label: Text(label, style: TextStyle(color: color)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: color),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: onPressed,
          )
        : FilledButton.icon(
            icon: Icon(icon),
            label: Text(label),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: onPressed,
          ),
  );
}
