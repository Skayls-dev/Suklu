import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus { pending, confirmed, cancelled, completed }
enum SessionType   { oneOnOne, group }

class BookingModel {
  const BookingModel({
    required this.id,
    required this.studentId,
    required this.tutorId,
    required this.subjectId,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.sessionType,
    required this.status,
    required this.totalAmount,
    required this.currency,
    this.parentId,
    this.sessionId,
    this.isFromCache = false,
  });

  final String       id;
  final String       studentId;
  final String       tutorId;
  final String       subjectId;
  final DateTime     scheduledAt;
  final int          durationMinutes;
  final SessionType  sessionType;
  final BookingStatus status;
  final double       totalAmount;
  final String       currency;
  final String?      parentId;
  final String?      sessionId;
  final bool         isFromCache;

  factory BookingModel.fromFirestore(
    DocumentSnapshot doc, {
    bool isFromCache = false,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingModel(
      id:              doc.id,
      studentId:       data['studentId']       as String,
      tutorId:         data['tutorId']         as String,
      subjectId:       data['subjectId']       as String,
      scheduledAt:     (data['scheduledAt'] as Timestamp).toDate(),
      durationMinutes: data['durationMinutes'] as int,
      sessionType:     data['sessionType'] == 'one_on_one'
          ? SessionType.oneOnOne
          : SessionType.group,
      status:          _parseStatus(data['status'] as String),
      totalAmount:     (data['totalAmount'] as num).toDouble(),
      currency:        data['currency']        as String,
      parentId:        data['parentId']        as String?,
      sessionId:       data['sessionId']       as String?,
      isFromCache:     isFromCache,
    );
  }

  static BookingStatus _parseStatus(String s) => switch (s) {
    'confirmed'  => BookingStatus.confirmed,
    'cancelled'  => BookingStatus.cancelled,
    'completed'  => BookingStatus.completed,
    _            => BookingStatus.pending,
  };

  String get statusLabel => switch (status) {
    BookingStatus.pending   => 'En attente',
    BookingStatus.confirmed => 'Confirmé',
    BookingStatus.cancelled => 'Annulé',
    BookingStatus.completed => 'Terminé',
  };
}
