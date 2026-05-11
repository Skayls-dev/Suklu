import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/booking_model.dart';

class BookingRepository {
  BookingRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore  _firestore;
  final FirebaseFunctions  _functions;

  // ── Create (delegates to Cloud Function for server-side validation) ─────────
  Future<String> createBooking({
    required String   tutorId,
    required String   subjectId,
    required DateTime scheduledAt,
    required int      durationMinutes,
    String?           studentId, // set when parent is booking
  }) async {
    final callable = _functions.httpsCallable('createBooking');
    final result   = await callable.call<Map<String, dynamic>>({
      'tutorId':         tutorId,
      'subjectId':       subjectId,
      'scheduledAt':     Timestamp.fromDate(scheduledAt).millisecondsSinceEpoch,
      'durationMinutes': durationMinutes,
      'sessionType':     'one_on_one',
      if (studentId != null) 'studentId': studentId,
    });
    return result.data['bookingId'] as String;
  }

  // ── Streams ────────────────────────────────────────────────────────────────
  Stream<List<BookingModel>> watchBookingsForStudent(String studentId) {
    return getMyBookings(studentId, 'student');
  }

  Stream<List<BookingModel>> watchBookingsForTutor(String tutorId) {
    return getMyBookings(tutorId, 'tutor');
  }

  Stream<List<BookingModel>> watchBookingsForParent(String parentId) {
    return getMyBookings(parentId, 'parent');
  }

  Stream<List<BookingModel>> getMyBookings(String uid, String role) async* {
    Query<Map<String, dynamic>> query = _firestore.collection('bookings');

    if (role == 'student') {
      query = query.where('studentId', isEqualTo: uid);
    } else if (role == 'tutor') {
      query = query.where('tutorId', isEqualTo: uid);
    } else if (role == 'parent') {
      query = query.where('parentId', isEqualTo: uid);
    } else {
      yield const <BookingModel>[];
      return;
    }

    try {
      await for (final snapshot in query.snapshots(includeMetadataChanges: true)) {
        final mapped = snapshot.docs
            .map((doc) => BookingModel.fromFirestore(
                  doc,
                  isFromCache: snapshot.metadata.isFromCache,
                ))
            .toList()
          ..sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));
        yield mapped;
      }
    } on FirebaseException catch (e) {
      if (e.code != 'unavailable') {
        rethrow;
      }

      final cached = await query.get(const GetOptions(source: Source.cache));
      final mapped = cached.docs
          .map((doc) => BookingModel.fromFirestore(doc, isFromCache: true))
          .toList()
        ..sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));
      yield mapped;
    }
  }
}

// ── Providers ──────────────────────────────────────────────────────────────────
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  );
});
