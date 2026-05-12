import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/parent_analytics_model.dart';

class ParentAnalyticsRepository {
  ParentAnalyticsRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Future<ParentAnalyticsData> getChildAnalytics(String studentId) async {
    final bookingsFuture = _firestore
        .collection('bookings')
        .where('studentId', isEqualTo: studentId)
        .where('status', isEqualTo: 'completed')
        .get();

    final progressFuture = _firestore
        .collection('progress')
        .where('studentId', isEqualTo: studentId)
        .get();

    final reviewsFuture = _firestore
        .collection('reviews')
        .where('studentId', isEqualTo: studentId)
        .get();

    final quizLogsFuture = _firestore
        .collection('ai_logs')
        .where('userId', isEqualTo: studentId)
        .where('endpoint', isEqualTo: 'quiz')
        .get();

    final results = await Future.wait([
      bookingsFuture,
      progressFuture,
      reviewsFuture,
      quizLogsFuture,
    ]);

    final bookings = results[0].docs;
    final progressDocs = results[1].docs;
    final reviews = results[2].docs;
    final quizLogs = results[3].docs;

    final totalSessions = bookings.length;
    final totalMinutes = bookings.fold<int>(
      0,
      (total, doc) => total + ((doc.data()['durationMinutes'] as num?)?.toInt() ?? 0),
    );

    final reviewRatings = reviews
        .map((doc) => (doc.data()['rating'] as num?)?.toDouble() ?? 0)
        .where((rating) => rating > 0)
        .toList();
    final averageRating = reviewRatings.isEmpty
        ? 0.0
        : reviewRatings.reduce((a, b) => a + b) / reviewRatings.length;

    final topicsCompleted = <String>{};
    final topicsInProgress = <String>{};
    final progressBySubject = <String, _SubjectAccumulator>{};

    for (final doc in progressDocs) {
      final data = doc.data();
      final subjectId = (data['subjectId'] ?? 'unknown').toString();
      final acc = progressBySubject.putIfAbsent(subjectId, () => _SubjectAccumulator(subjectId));

      for (final topic in _extractTopicList(data, ['topicsCompleted', 'completedTopics'])) {
        topicsCompleted.add(topic);
        acc.topicsCompleted.add(topic);
      }
      for (final topic in _extractTopicList(data, ['topicsInProgress', 'inProgressTopics'])) {
        topicsInProgress.add(topic);
        acc.topicsInProgress.add(topic);
      }
    }

    final weekly = _buildWeeklyData(bookings);

    final ratingsBySubject = <String, List<double>>{};
    for (final reviewDoc in reviews) {
      final data = reviewDoc.data();
      final subjectId = data['subjectId']?.toString();
      final rating = (data['rating'] as num?)?.toDouble();
      if (subjectId == null || rating == null || rating <= 0) continue;
      ratingsBySubject.putIfAbsent(subjectId, () => <double>[]).add(rating);
    }

    for (final bookingDoc in bookings) {
      final data = bookingDoc.data();
      final subjectId = (data['subjectId'] ?? 'unknown').toString();
      final acc = progressBySubject.putIfAbsent(subjectId, () => _SubjectAccumulator(subjectId));
      acc.sessionCount += 1;
      acc.totalMinutes += (data['durationMinutes'] as num?)?.toInt() ?? 0;

      final rawScheduledAt = data['scheduledAt'];
      final scheduledAt = rawScheduledAt is Timestamp ? rawScheduledAt.toDate() : null;
      if (scheduledAt != null && (acc.lastSessionAt == null || scheduledAt.isAfter(acc.lastSessionAt!))) {
        acc.lastSessionAt = scheduledAt;
      }
    }

    final subjectBreakdown = <String, SubjectStats>{};
    for (final entry in progressBySubject.entries) {
      final ratings = ratingsBySubject[entry.key] ?? const <double>[];
      final average = ratings.isEmpty ? 0.0 : ratings.reduce((a, b) => a + b) / ratings.length;
      subjectBreakdown[entry.key] = SubjectStats(
        subjectId: entry.key,
        sessionCount: entry.value.sessionCount,
        totalMinutes: entry.value.totalMinutes,
        averageRating: average,
        topicsCompleted: entry.value.topicsCompleted.toList()..sort(),
        topicsInProgress: entry.value.topicsInProgress.toList()..sort(),
        lastSessionAt: entry.value.lastSessionAt,
      );
    }

    return ParentAnalyticsData(
      studentId: studentId,
      totalSessions: totalSessions,
      totalMinutes: totalMinutes,
      quizzesCompleted: quizLogs.length,
      averageRating: averageRating,
      subjectBreakdown: subjectBreakdown,
      weeklySessionCounts: weekly,
      topicsCompleted: topicsCompleted.toList()..sort(),
      topicsInProgress: topicsInProgress.toList()..sort(),
    );
  }

  List<WeeklyDataPoint> _buildWeeklyData(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings,
  ) {
    final now = DateTime.now();
    final currentWeekStart = _weekStart(now);
    final starts = List<DateTime>.generate(
      8,
      (i) => currentWeekStart.subtract(Duration(days: 7 * (7 - i))),
    );

    final counts = <DateTime, int>{
      for (final weekStart in starts) weekStart: 0,
    };
    final minutes = <DateTime, int>{
      for (final weekStart in starts) weekStart: 0,
    };

    for (final doc in bookings) {
      final data = doc.data();
      final raw = data['scheduledAt'];
      if (raw is! Timestamp) continue;
      final sessionDate = raw.toDate();
      final weekStart = _weekStart(sessionDate);
      if (!counts.containsKey(weekStart)) continue;
      counts[weekStart] = (counts[weekStart] ?? 0) + 1;
      minutes[weekStart] = (minutes[weekStart] ?? 0) + ((data['durationMinutes'] as num?)?.toInt() ?? 0);
    }

    return starts
        .map((weekStart) => WeeklyDataPoint(
              weekStart: weekStart,
              sessionCount: counts[weekStart] ?? 0,
              minutesTotal: minutes[weekStart] ?? 0,
            ))
        .toList();
  }

  DateTime _weekStart(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final offset = normalized.weekday - DateTime.monday;
    return normalized.subtract(Duration(days: offset));
  }

  List<String> _extractTopicList(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final raw = data[key];
      if (raw is List) {
        return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
      }
    }
    return const [];
  }
}

class _SubjectAccumulator {
  _SubjectAccumulator(this.subjectId);

  final String subjectId;
  int sessionCount = 0;
  int totalMinutes = 0;
  DateTime? lastSessionAt;
  final Set<String> topicsCompleted = <String>{};
  final Set<String> topicsInProgress = <String>{};
}

final parentAnalyticsRepositoryProvider = Provider<ParentAnalyticsRepository>((ref) {
  return ParentAnalyticsRepository(firestore: ref.watch(firestoreProvider));
});
