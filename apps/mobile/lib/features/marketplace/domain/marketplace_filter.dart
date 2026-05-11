class MarketplaceFilter {
  const MarketplaceFilter({
    this.subjectId,
    this.gradeLevel,
    this.country,
    this.maxHourlyRate,
    this.verifiedOnly = false,
  });

  final String? subjectId;
  final String? gradeLevel;
  final String? country;
  final double? maxHourlyRate;
  final bool verifiedOnly;

  static MarketplaceFilter get empty => const MarketplaceFilter();

  bool get isActive {
    return subjectId != null ||
        gradeLevel != null ||
        country != null ||
        maxHourlyRate != null ||
        verifiedOnly;
  }

  MarketplaceFilter copyWith({
    String? subjectId,
    String? gradeLevel,
    String? country,
    double? maxHourlyRate,
    bool? verifiedOnly,
    bool clearSubjectId = false,
    bool clearGradeLevel = false,
    bool clearCountry = false,
    bool clearMaxHourlyRate = false,
  }) {
    return MarketplaceFilter(
      subjectId: clearSubjectId ? null : (subjectId ?? this.subjectId),
      gradeLevel: clearGradeLevel ? null : (gradeLevel ?? this.gradeLevel),
      country: clearCountry ? null : (country ?? this.country),
      maxHourlyRate: clearMaxHourlyRate ? null : (maxHourlyRate ?? this.maxHourlyRate),
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
    );
  }
}