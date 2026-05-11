import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/marketplace_repository.dart';
import '../domain/marketplace_filter.dart';
import '../domain/tutor_profile_model.dart';

class MarketplaceFilterNotifier extends StateNotifier<MarketplaceFilter> {
  MarketplaceFilterNotifier() : super(MarketplaceFilter.empty);

  void setSubject(String? subjectId) {
    state = state.copyWith(
      subjectId: subjectId,
      clearSubjectId: subjectId == null || subjectId.isEmpty,
    );
  }

  void setGradeLevel(String? gradeLevel) {
    state = state.copyWith(
      gradeLevel: gradeLevel,
      clearGradeLevel: gradeLevel == null || gradeLevel.isEmpty,
    );
  }

  void setVerifiedOnly(bool value) {
    state = state.copyWith(verifiedOnly: value);
  }

  void setMaxRate(double? maxRate) {
    state = state.copyWith(
      maxHourlyRate: maxRate,
      clearMaxHourlyRate: maxRate == null,
    );
  }

  void resetAll() {
    state = MarketplaceFilter.empty;
  }
}

final marketplaceFilterProvider =
    StateNotifierProvider<MarketplaceFilterNotifier, MarketplaceFilter>((ref) {
  return MarketplaceFilterNotifier();
});

final marketplaceSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final activeSubjectsProvider = FutureProvider.autoDispose<List<Map<String, String>>>((ref) async {
  final snap = await ref
      .watch(firestoreProvider)
      .collection('subjects')
      .where('isActive', isEqualTo: true)
      .get();

  return snap.docs
      .map((doc) => {
            'id': doc.id,
            'name': (doc.data()['name'] ?? doc.id).toString(),
          })
      .toList();
});

final filteredTutorsProvider =
    StreamProvider.autoDispose<List<TutorProfileModel>>((ref) {
  final filter = ref.watch(marketplaceFilterProvider);
  return ref.watch(marketplaceRepositoryProvider).watchTutors(filter);
});

final tutorProfileProvider =
    FutureProvider.autoDispose.family<TutorProfileModel?, String>((ref, tutorId) {
  return ref.watch(marketplaceRepositoryProvider).fetchTutorProfile(tutorId);
});