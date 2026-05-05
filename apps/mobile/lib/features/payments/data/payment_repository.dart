import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/payment_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PaymentRepository
//
// READ-ONLY from the client perspective.
// All payment initiation happens through the mobile SDK of the payment
// provider (Flutterwave InlineCheckout / Orange Money redirect / Wave link),
// and the webhook Cloud Functions update Firestore upon confirmation.
//
// The client initiates a payment intent via a Cloud Function (not yet wired)
// and polls/listens for the resulting payment document here.
// ─────────────────────────────────────────────────────────────────────────────
class PaymentRepository {
  PaymentRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Stream<List<PaymentModel>> watchPaymentsForUser(String userId) {
    return _firestore
        .collection('payments')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map(PaymentModel.fromFirestore).toList());
  }

  // Watches a single payment until it leaves "pending" state
  Stream<PaymentModel?> watchPaymentStatus(String paymentId) {
    return _firestore
        .collection('payments')
        .doc(paymentId)
        .snapshots()
        .map((snap) => snap.exists ? PaymentModel.fromFirestore(snap) : null);
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(firestore: ref.watch(firestoreProvider));
});
