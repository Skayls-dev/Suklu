class ParentAnalyticsData {
  const ParentAnalyticsData({
    required this.studentId,
    required this.totalSessions,
    required this.totalMinutes,
    required this.quizzesCompleted,
    required this.averageRating,
    required this.subjectBreakdown,
    required this.weeklySessionCounts,
    required this.topicsCompleted,
    required this.topicsInProgress,
  });

  final String studentId;
  final int totalSessions;
  final int totalMinutes;
  final int quizzesCompleted;
  final double averageRating;
  final Map<String, SubjectStats> subjectBreakdown;
  final List<WeeklyDataPoint> weeklySessionCounts;
  final List<String> topicsCompleted;
  final List<String> topicsInProgress;

  static ParentAnalyticsData empty({required String studentId}) {
    return ParentAnalyticsData(
      studentId: studentId,
      totalSessions: 0,
      totalMinutes: 0,
      quizzesCompleted: 0,
      averageRating: 0,
      subjectBreakdown: const {},
      weeklySessionCounts: const [],
      topicsCompleted: const [],
      topicsInProgress: const [],
    );
  }
}

class SubjectStats {
  const SubjectStats({
    required this.subjectId,
    required this.sessionCount,
    required this.totalMinutes,
    required this.averageRating,
    required this.topicsCompleted,
    required this.topicsInProgress,
    required this.lastSessionAt,
  });

  final String subjectId;
  final int sessionCount;
  final int totalMinutes;
  final double averageRating;
  final List<String> topicsCompleted;
  final List<String> topicsInProgress;
  final DateTime? lastSessionAt;
}

class WeeklyDataPoint {
  const WeeklyDataPoint({
    required this.weekStart,
    required this.sessionCount,
    required this.minutesTotal,
  });

  final DateTime weekStart;
  final int sessionCount;
  final int minutesTotal;
}
