import 'package:cloud_firestore/cloud_firestore.dart';

class ParentProfileModel {
  const ParentProfileModel({
    required this.uid,
    required this.fullName,
    required this.numberOfChildren,
    required this.communicationPreference,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String fullName;
  final int numberOfChildren;
  final String communicationPreference;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ParentProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};

    return ParentProfileModel(
      uid: (data['uid'] ?? data['userId'] ?? doc.id) as String,
      fullName: (data['fullName'] ?? '') as String,
      numberOfChildren: (data['numberOfChildren'] ?? 1) as int,
      communicationPreference: (data['communicationPreference'] ?? 'Email') as String,
      notes: (data['notes'] ?? '') as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory ParentProfileModel.empty(String uid, String fullName) => ParentProfileModel(
    uid: uid,
    fullName: fullName,
    numberOfChildren: 1,
    communicationPreference: 'Email',
    notes: '',
    createdAt: null,
    updatedAt: null,
  );
}
