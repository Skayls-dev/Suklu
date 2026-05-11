import 'package:cloud_firestore/cloud_firestore.dart';

import 'available_slot_model.dart';

class TutorProfileModel {
  const TutorProfileModel({
    required this.uid,
    required this.fullName,
    required this.bio,
    required this.subjects,
    required this.gradeLevels,
    required this.country,
    required this.currency,
    required this.hourlyRate,
    required this.rating,
    required this.reviewCount,
    required this.isVerified,
    required this.isActive,
    required this.yearsExperience,
    required this.diplomas,
    required this.availableSlots,
  });

  final String uid;
  final String fullName;
  final String bio;
  final List<String> subjects;
  final List<String> gradeLevels;
  final String country;
  final String currency;
  final double hourlyRate;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final bool isActive;
  final int yearsExperience;
  final List<String> diplomas;
  final List<AvailableSlotModel> availableSlots;

  factory TutorProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};

    return TutorProfileModel(
      uid: (data['uid'] ?? data['userId'] ?? doc.id) as String,
      fullName: (data['fullName'] ?? '') as String,
      bio: (data['bio'] ?? '') as String,
      subjects: ((data['subjects'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      gradeLevels: ((data['gradeLevels'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      country: (data['country'] ?? 'SN') as String,
      currency: (data['currency'] ?? 'XOF') as String,
      hourlyRate: (data['hourlyRate'] as num?)?.toDouble() ?? 0,
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      isVerified: (data['isVerified'] as bool?) ?? false,
      isActive: (data['isActive'] as bool?) ?? false,
      yearsExperience: (data['yearsExperience'] as num?)?.toInt() ?? 0,
      diplomas: ((data['diplomas'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      availableSlots: ((data['availableSlots'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AvailableSlotModel.fromMap)
          .toList(),
    );
  }

  String get formattedRate {
    final whole = hourlyRate.round().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < whole.length; index++) {
      final reverseIndex = whole.length - index;
      buffer.write(whole[index]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(' ');
      }
    }
    return '${buffer.toString()} $currency / heure';
  }

  String get ratingLabel => '${rating.toStringAsFixed(1)} ★ ($reviewCount avis)';
}