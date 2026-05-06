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
    return _firestore
        .collection('bookings')
        .where('studentId', isEqualTo: studentId)
        .orderBy('scheduledAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map(BookingModel.fromFirestore).toList());
  }

  Stream<List<BookingModel>> watchBookingsForTutor(String tutorId) {
    return _firestore
        .collection('bookings')
        .where('tutorId', isEqualTo: tutorId)
        .orderBy('scheduledAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map(BookingModel.fromFirestore).toList());
  }

  Stream<List<BookingModel>> watchBookingsForParent(String parentId) {
    return _firestore
        .collection('bookings')
        .where('parentId', isEqualTo: parentId)
        .orderBy('scheduledAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map(BookingModel.fromFirestore).toList());
  }
}

// ── Providers ──────────────────────────────────────────────────────────────────
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  );
});
