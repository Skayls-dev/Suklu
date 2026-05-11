import 'package:cloud_firestore/cloud_firestore.dart';

class AssessmentModel {
  const AssessmentModel({
    required this.id,
    required this.studentId,
    required this.subject,
    required this.gradeLevel,
    required this.sessionId,
    required this.estimatedLevel,
    required this.strengths,
    required this.gaps,
    required this.recommendedTopics,
    required this.questionCount,
    required this.completedAt,
  });

  final String id;
  final String studentId;
  final String subject;
  final String gradeLevel;
  final String sessionId;
  final String estimatedLevel;
  final List<String> strengths;
  final List<String> gaps;
  final List<String> recommendedTopics;
  final int questionCount;
  final DateTime completedAt;

  AssessmentModel copyWith({
    String? id,
    String? studentId,
    String? subject,
    String? gradeLevel,
    String? sessionId,
    String? estimatedLevel,
    List<String>? strengths,
    List<String>? gaps,
    List<String>? recommendedTopics,
    int? questionCount,
    DateTime? completedAt,
  }) {
    return AssessmentModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      subject: subject ?? this.subject,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      sessionId: sessionId ?? this.sessionId,
      estimatedLevel: estimatedLevel ?? this.estimatedLevel,
      strengths: strengths ?? this.strengths,
      gaps: gaps ?? this.gaps,
      recommendedTopics: recommendedTopics ?? this.recommendedTopics,
      questionCount: questionCount ?? this.questionCount,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory AssessmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};

    List<String> parseList(dynamic value) {
      if (value is! List) return const [];
      return value.map((item) => item.toString()).toList();
    }

    return AssessmentModel(
      id: doc.id,
      studentId: (data['studentId'] ?? '').toString(),
      subject: (data['subject'] ?? '').toString(),
      gradeLevel: (data['gradeLevel'] ?? '').toString(),
      sessionId: (data['sessionId'] ?? '').toString(),
      estimatedLevel: (data['estimatedLevel'] ?? '').toString(),
      strengths: parseList(data['strengths']),
      gaps: parseList(data['gaps']),
      recommendedTopics: parseList(data['recommendedTopics']),
      questionCount: (data['questionCount'] as num?)?.toInt() ?? 0,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'studentId': studentId,
        'subject': subject,
        'gradeLevel': gradeLevel,
        'sessionId': sessionId,
        'estimatedLevel': estimatedLevel,
        'strengths': strengths,
        'gaps': gaps,
        'recommendedTopics': recommendedTopics,
        'questionCount': questionCount,
        'completedAt': Timestamp.fromDate(completedAt),
        'createdAt': FieldValue.serverTimestamp(),
      };
}
