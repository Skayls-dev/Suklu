import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/session_model.dart';

class SessionRepository {
  SessionRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Stream<SessionModel?> watchSession(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) => doc.exists ? SessionModel.fromFirestore(doc) : null);
  }

  Future<SessionModel?> fetchSessionByBookingId(String bookingId) async {
    final snap = await _firestore
        .collection('sessions')
        .where('bookingId', isEqualTo: bookingId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return SessionModel.fromFirestore(snap.docs.first);
  }

  Future<({String roomUrl, String sessionId})> createRoom(String bookingId) async {
    final callable = _functions.httpsCallable('createDailyRoom');
    final result = await callable.call({'bookingId': bookingId});

    final rawData = result.data;
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData as Map)
        : <String, dynamic>{};

    // Certaines réponses callable web encapsulent le payload dans "result".
    final payload = data['roomUrl'] != null
        ? data
        : (data['result'] is Map
            ? Map<String, dynamic>.from(data['result'] as Map)
            : data);

    final roomUrl = payload['roomUrl']?.toString();
    final sessionId = payload['sessionId']?.toString();

    if (roomUrl == null || roomUrl.isEmpty || sessionId == null || sessionId.isEmpty) {
      throw StateError('createDailyRoom returned an invalid payload: $payload');
    }

    return (
      roomUrl: roomUrl,
      sessionId: sessionId,
    );
  }

  Future<void> updateStatus(String sessionId, SessionStatus status) async {
    final statusStr = switch (status) {
      SessionStatus.scheduled => 'scheduled',
      SessionStatus.inProgress => 'in_progress',
      SessionStatus.completed => 'completed',
    };

    await _firestore.collection('sessions').doc(sessionId).update({
      'status': statusStr,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  );
});