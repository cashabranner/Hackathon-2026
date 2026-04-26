enum SessionType {
  legs,
  upperPush,
  upperPull,
  fullBody,
  hiit,
  steadyStateCardio,
  mobility,
}

enum SessionIntensity { low, moderate, high, maximal }

class TrainingSession {
  final String id;
  final String userId;
  final SessionType type;
  final DateTime plannedAt;
  final int durationMinutes;
  final SessionIntensity intensity;
  final String? notes;
  final String? customName;
  final String? customSplitId;

  const TrainingSession({
    required this.id,
    required this.userId,
    required this.type,
    required this.plannedAt,
    required this.durationMinutes,
    required this.intensity,
    this.notes,
    this.customName,
    this.customSplitId,
  });

  double get depletionRateGPerMin => switch (intensity) {
        SessionIntensity.low => 0.7,
        SessionIntensity.moderate => 1.0,
        SessionIntensity.high => 1.3,
        SessionIntensity.maximal => 1.5,
      };

  double get estimatedMuscleGlycogenCostG =>
      depletionRateGPerMin * durationMinutes;

  String get displayName =>
      customName ??
      switch (type) {
        SessionType.legs => 'Leg Day',
        SessionType.upperPush => 'Upper Push',
        SessionType.upperPull => 'Upper Pull',
        SessionType.fullBody => 'Full Body',
        SessionType.hiit => 'HIIT',
        SessionType.steadyStateCardio => 'Cardio',
        SessionType.mobility => 'Mobility',
      };

  TrainingSession copyWith({
    String? id,
    String? userId,
    SessionType? type,
    DateTime? plannedAt,
    int? durationMinutes,
    SessionIntensity? intensity,
    String? notes,
    String? customName,
    String? customSplitId,
  }) {
    return TrainingSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      plannedAt: plannedAt ?? this.plannedAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      intensity: intensity ?? this.intensity,
      notes: notes ?? this.notes,
      customName: customName ?? this.customName,
      customSplitId: customSplitId ?? this.customSplitId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type.name,
        'planned_at': plannedAt.toIso8601String(),
        'duration_minutes': durationMinutes,
        'intensity': intensity.name,
        'notes': notes,
        'custom_name': customName,
        'custom_split_id': customSplitId,
      };

  factory TrainingSession.fromJson(Map<String, dynamic> j) => TrainingSession(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        type: SessionType.values.byName(j['type'] as String),
        plannedAt: DateTime.parse(j['planned_at'] as String),
        durationMinutes: j['duration_minutes'] as int,
        intensity: SessionIntensity.values.byName(j['intensity'] as String),
        notes: j['notes'] as String?,
        customName: j['custom_name'] as String?,
        customSplitId: j['custom_split_id'] as String?,
      );
}
