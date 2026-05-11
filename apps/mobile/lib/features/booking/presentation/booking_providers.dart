import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/booking_repository.dart';
import '../domain/booking_model.dart';

final userBookingsProvider = StreamProvider.autoDispose<List<BookingModel>>((ref) {
  final user = ref.watch(authStateNotifierProvider).value;
  if (user == null) return const Stream.empty();

  final repo = ref.watch(bookingRepositoryProvider);
  final role = user.role.toFirestoreString();
  if (role != 'student' && role != 'tutor' && role != 'parent') {
    return const Stream.empty();
  }
  return repo.getMyBookings(user.uid, role);
});

// Booking creation state
final bookingCreationProvider =
    AsyncNotifierProvider.autoDispose<BookingCreationNotifier, void>(
  BookingCreationNotifier.new,
);

class BookingCreationNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> createBooking({
    required String   tutorId,
    required String   subjectId,
    required DateTime scheduledAt,
    required int      durationMinutes,
    String?           studentId,
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(bookingRepositoryProvider);
    try {
      final id = await repo.createBooking(
        tutorId:         tutorId,
        subjectId:       subjectId,
        scheduledAt:     scheduledAt,
        durationMinutes: durationMinutes,
        studentId:       studentId,
      );
      state = const AsyncData(null);
      return id;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
