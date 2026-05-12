import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionStatus { scheduled, inProgress, completed }

class SessionModel {
  const SessionModel({
    required this.id,
    required this.bookingId,
    required this.studentId,
    required this.tutorId,
    required this.roomUrl,
    required this.roomMode,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.status,
    this.aiSummary,
    this.aiSummaryGeneratedAt,
  });

  final String id;
  final String bookingId;
  final String studentId;
  final String tutorId;
  final String? roomUrl;
  final String roomMode;
  final DateTime scheduledAt;
  final int durationMinutes;
  final SessionStatus status;
  final Map<String, dynamic>? aiSummary;
  final DateTime? aiSummaryGeneratedAt;

  factory SessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    final rawStatus = (data['status'] ?? 'scheduled').toString();

    return SessionModel(
      id: doc.id,
      bookingId: (data['bookingId'] ?? '').toString(),
      studentId: (data['studentId'] ?? '').toString(),
      tutorId: (data['tutorId'] ?? '').toString(),
      roomUrl: (data['roomUrl'] as String?)?.trim().isEmpty ?? true
          ? null
          : (data['roomUrl'] as String?),
      roomMode: (data['roomMode'] ?? 'ephemeral').toString(),
      scheduledAt: (data['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 60,
      status: switch (rawStatus) {
        'in_progress' => SessionStatus.inProgress,
        'completed' => SessionStatus.completed,
        _ => SessionStatus.scheduled,
      },
      aiSummary: data['aiSummary'] is Map<String, dynamic>
          ? (data['aiSummary'] as Map<String, dynamic>)
          : null,
      aiSummaryGeneratedAt: (data['aiSummaryGeneratedAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isAccessible {
    final now = DateTime.now();
    final start = scheduledAt.subtract(const Duration(minutes: 5));
    final end = scheduledAt.add(Duration(minutes: durationMinutes + 30));
    return now.isAfter(start) && now.isBefore(end);
  }

  Duration get remainingDuration {
    final end = scheduledAt.add(Duration(minutes: durationMinutes));
    final remaining = end.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}