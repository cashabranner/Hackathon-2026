import 'workout_split.dart';

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
  final List<SplitExercise> plannedExercises;
  final List<SplitExercise> completedExercises;
  final String? postWorkoutFeeling;
  final int? postWorkoutIntensity;
  final DateTime? postWorkoutSummaryAt;

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
    this.plannedExercises = const [],
    this.completedExercises = const [],
    this.postWorkoutFeeling,
    this.postWorkoutIntensity,
    this.postWorkoutSummaryAt,
  });

  double get depletionRateGPerMin => switch (intensity) {
        SessionIntensity.low => 0.7,
        SessionIntensity.moderate => 1.0,
        SessionIntensity.high => 1.3,
        SessionIntensity.maximal => 1.5,
      };

  double get estimatedMuscleGlycogenCostG {
    final exercises =
        completedExercises.isNotEmpty ? completedExercises : plannedExercises;
    if (exercises.isEmpty) {
      return depletionRateGPerMin * durationMinutes;
    }

    final intensityMultiplier = switch (intensity) {
      SessionIntensity.low => 0.7,
      SessionIntensity.moderate => 1.0,
      SessionIntensity.high => 1.25,
      SessionIntensity.maximal => 1.45,
    };
    final exerciseCost = exercises.fold<double>(
      0,
      (sum, exercise) => sum + _exerciseGlycogenCost(exercise),
    );
    final durationCap = (durationMinutes * depletionRateGPerMin * 1.8)
        .clamp(25.0, 320.0)
        .toDouble();
    return (exerciseCost * intensityMultiplier).clamp(10.0, durationCap);
  }

  String? get customRoutineId => customSplitId;

  bool get hasPostWorkoutSummary =>
      postWorkoutFeeling?.trim().isNotEmpty == true &&
      postWorkoutIntensity != null;

  bool postWorkoutSummaryDue(DateTime now) {
    final reminderAt = plannedAt.add(const Duration(hours: 2));
    return !hasPostWorkoutSummary && !now.isBefore(reminderAt);
  }

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

  static double _exerciseGlycogenCost(SplitExercise exercise) {
    final reps = _averageReps(exercise.reps);
    final muscles = exercise.muscles.map((m) => m.toLowerCase()).toList();
    final lowerName = exercise.name.toLowerCase();
    final isLower = muscles.any((m) =>
            m.contains('quad') ||
            m.contains('glute') ||
            m.contains('hamstring')) ||
        lowerName.contains('squat') ||
        lowerName.contains('deadlift') ||
        lowerName.contains('lunge');
    final isLargeUpper = muscles.any((m) =>
            m.contains('back') || m.contains('chest') || m.contains('delt')) ||
        lowerName.contains('press') ||
        lowerName.contains('row') ||
        lowerName.contains('pull');
    final basePerSet = isLower
        ? 7.0
        : isLargeUpper
            ? 5.0
            : 3.0;
    final repMultiplier = (reps / 10).clamp(0.65, 1.45);
    return exercise.sets.clamp(1, 12) * basePerSet * repMultiplier;
  }

  static double _averageReps(String reps) {
    final matches = RegExp(r'\d+').allMatches(reps).toList();
    if (matches.isEmpty) return 10;
    final values = matches
        .map((match) => double.tryParse(match.group(0) ?? '') ?? 10)
        .toList();
    return values.reduce((a, b) => a + b) / values.length;
  }

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
    List<SplitExercise>? plannedExercises,
    List<SplitExercise>? completedExercises,
    String? postWorkoutFeeling,
    int? postWorkoutIntensity,
    DateTime? postWorkoutSummaryAt,
    bool clearPostWorkoutSummary = false,
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
      plannedExercises: plannedExercises ?? this.plannedExercises,
      completedExercises: completedExercises ?? this.completedExercises,
      postWorkoutFeeling: clearPostWorkoutSummary
          ? null
          : postWorkoutFeeling ?? this.postWorkoutFeeling,
      postWorkoutIntensity: clearPostWorkoutSummary
          ? null
          : postWorkoutIntensity ?? this.postWorkoutIntensity,
      postWorkoutSummaryAt: clearPostWorkoutSummary
          ? null
          : postWorkoutSummaryAt ?? this.postWorkoutSummaryAt,
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
        'planned_exercises':
            plannedExercises.map((exercise) => exercise.toJson()).toList(),
        'completed_exercises':
            completedExercises.map((exercise) => exercise.toJson()).toList(),
        'post_workout_feeling': postWorkoutFeeling,
        'post_workout_intensity': postWorkoutIntensity,
        'post_workout_summary_at': postWorkoutSummaryAt?.toIso8601String(),
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
        plannedExercises: (j['planned_exercises'] as List? ?? const [])
            .map((item) => SplitExercise.fromJson(item as Map<String, dynamic>))
            .toList(),
        completedExercises: (j['completed_exercises'] as List? ?? const [])
            .map((item) => SplitExercise.fromJson(item as Map<String, dynamic>))
            .toList(),
        postWorkoutFeeling: j['post_workout_feeling'] as String?,
        postWorkoutIntensity: (j['post_workout_intensity'] as num?)?.toInt(),
        postWorkoutSummaryAt: j['post_workout_summary_at'] == null
            ? null
            : DateTime.parse(j['post_workout_summary_at'] as String),
      );
}
