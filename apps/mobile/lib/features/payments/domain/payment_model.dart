import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus   { pending, success, failed, refunded }
enum PaymentProvider { flutterwave, orangeMoney, wave }

class PaymentModel {
  const PaymentModel({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.amount,
    required this.currency,
    required this.provider,
    required this.status,
    required this.createdAt,
    this.processedAt,
  });

  final String          id;
  final String          bookingId;
  final String          userId;
  final double          amount;
  final String          currency;
  final PaymentProvider provider;
  final PaymentStatus   status;
  final DateTime        createdAt;
  final DateTime?       processedAt;

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      id:           doc.id,
      bookingId:    data['bookingId']  as String,
      userId:       data['userId']     as String,
      amount:       (data['amount'] as num).toDouble(),
      currency:     data['currency']   as String,
      provider:     _parseProvider(data['provider'] as String),
      status:       _parseStatus(data['status']     as String),
      createdAt:    (data['createdAt'] as Timestamp).toDate(),
      processedAt:  data['processedAt'] != null
          ? (data['processedAt'] as Timestamp).toDate()
          : null,
    );
  }

  static PaymentProvider _parseProvider(String s) => switch (s) {
    'orange_money' => PaymentProvider.orangeMoney,
    'wave'         => PaymentProvider.wave,
    _              => PaymentProvider.flutterwave,
  };

  static PaymentStatus _parseStatus(String s) => switch (s) {
    'success'  => PaymentStatus.success,
    'failed'   => PaymentStatus.failed,
    'refunded' => PaymentStatus.refunded,
    _          => PaymentStatus.pending,
  };

  String get formattedAmount =>
      '${amount.toStringAsFixed(0)} $currency';

  String get providerLabel => switch (provider) {
    PaymentProvider.flutterwave => 'Flutterwave',
    PaymentProvider.orangeMoney => 'Orange Money',
    PaymentProvider.wave        => 'Wave',
  };

  String get statusLabel => switch (status) {
    PaymentStatus.pending  => 'En attente',
    PaymentStatus.success  => 'Réussi',
    PaymentStatus.failed   => 'Échoué',
    PaymentStatus.refunded => 'Remboursé',
  };
}
