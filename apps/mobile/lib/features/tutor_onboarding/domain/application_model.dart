import 'package:cloud_firestore/cloud_firestore.dart';

enum ApplicationStatus {
  pendingDocumentReview,
  backgroundCheckPending,
  approved,
  rejected;

  static ApplicationStatus fromString(String s) => switch (s) {
    'background_check_pending' => ApplicationStatus.backgroundCheckPending,
    'approved'                 => ApplicationStatus.approved,
    'rejected'                 => ApplicationStatus.rejected,
    _                          => ApplicationStatus.pendingDocumentReview,
  };

  String get label => switch (this) {
    ApplicationStatus.pendingDocumentReview => 'En attente de révision documentaire',
    ApplicationStatus.backgroundCheckPending => 'Vérification de fond en cours',
    ApplicationStatus.approved               => 'Approuvé',
    ApplicationStatus.rejected               => 'Refusé',
  };
}

class TutorApplicationModel {
  const TutorApplicationModel({
    required this.id,
    required this.userId,
    required this.status,
    required this.subjects,
    required this.gradeLevels,
    required this.createdAt,
    this.rejectionReason,
  });

  final String             id;
  final String             userId;
  final ApplicationStatus  status;
  final List<String>       subjects;
  final List<String>       gradeLevels;
  final DateTime           createdAt;
  final String?            rejectionReason;

  factory TutorApplicationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TutorApplicationModel(
      id:              doc.id,
      userId:          data['userId']  as String,
      status:          ApplicationStatus.fromString(data['status'] as String),
      subjects:        List<String>.from(data['subjects']    ?? []),
      gradeLevels:     List<String>.from(data['gradeLevels'] ?? []),
      createdAt:       (data['createdAt'] as Timestamp).toDate(),
      rejectionReason: data['rejectionReason'] as String?,
    );
  }
}
