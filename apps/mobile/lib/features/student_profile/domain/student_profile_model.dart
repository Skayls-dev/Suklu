import 'package:cloud_firestore/cloud_firestore.dart';

class StudentProfileModel {
  const StudentProfileModel({
    required this.uid,
    required this.fullName,
    required this.subjects,
    required this.gradeLevels,
    required this.goals,
    required this.learningPreferences,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String fullName;
  final List<String> subjects;
  final List<String> gradeLevels;
  final String goals;
  final String learningPreferences;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory StudentProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};

    return StudentProfileModel(
      uid: (data['uid'] ?? data['userId'] ?? doc.id) as String,
      fullName: (data['fullName'] ?? '') as String,
      subjects: ((data['subjects'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      gradeLevels: ((data['gradeLevels'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      goals: (data['goals'] ?? '') as String,
      learningPreferences: (data['learningPreferences'] ?? '') as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory StudentProfileModel.empty(String uid, String fullName) => StudentProfileModel(
    uid: uid,
    fullName: fullName,
    subjects: const [],
    gradeLevels: const [],
    goals: '',
    learningPreferences: '',
    createdAt: null,
    updatedAt: null,
  );
}
