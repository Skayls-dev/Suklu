class AvailableSlotModel {
  const AvailableSlotModel({
    required this.dayOfWeek,
    required this.startHour,
    required this.endHour,
  });

  final int dayOfWeek;
  final int startHour;
  final int endHour;

  String get dayLabel => switch (dayOfWeek) {
    1 => 'Lundi',
    2 => 'Mardi',
    3 => 'Mercredi',
    4 => 'Jeudi',
    5 => 'Vendredi',
    6 => 'Samedi',
    7 => 'Dimanche',
    _ => 'Jour inconnu',
  };

  factory AvailableSlotModel.fromMap(Map<String, dynamic> map) {
    return AvailableSlotModel(
      dayOfWeek: (map['dayOfWeek'] as num?)?.toInt() ?? 1,
      startHour: (map['startHour'] as num?)?.toInt() ?? 0,
      endHour: (map['endHour'] as num?)?.toInt() ?? 0,
    );
  }
}