import 'package:cloud_firestore/cloud_firestore.dart';

class ProgressRecord {
  const ProgressRecord({
    required this.id,
    required this.studentId,
    required this.tutorId,
    required this.subjectId,
    required this.sessionCount,
    required this.totalMinutes,
    required this.averageRating,
    required this.lastSessionAt,
    required this.topicsCompleted,
    required this.topicsInProgress,
  });

  final String id;
  final String studentId;
  final String tutorId;
  final String subjectId;
  final int sessionCount;
  final int totalMinutes;
  final double averageRating;
  final DateTime? lastSessionAt;
  final List<String> topicsCompleted;
  final List<String> topicsInProgress;

  factory ProgressRecord.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final lastSessionRaw = data['lastSessionAt'];

    return ProgressRecord(
      id: doc.id,
      studentId: (data['studentId'] ?? '').toString(),
      tutorId: (data['tutorId'] ?? '').toString(),
      subjectId: (data['subjectId'] ?? '').toString(),
      sessionCount: (data['sessionCount'] as num?)?.toInt() ?? 0,
      totalMinutes: (data['totalMinutes'] as num?)?.toInt() ?? 0,
      averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0,
      lastSessionAt: lastSessionRaw is Timestamp ? lastSessionRaw.toDate() : null,
      topicsCompleted: ((data['topicsCompleted'] as List<dynamic>?) ?? const <dynamic>[])
          .map((entry) => entry.toString())
          .toList(),
      topicsInProgress: ((data['topicsInProgress'] as List<dynamic>?) ?? const <dynamic>[])
          .map((entry) => entry.toString())
          .toList(),
    );
  }
}
