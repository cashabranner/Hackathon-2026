enum BiologicalSex { male, female }

enum ActivityBaseline {
  sedentary,
  lightlyActive,
  moderatelyActive,
  veryActive,
  extraActive,
}

class FoodPreferences {
  final List<String> preferredFoods;
  final List<String> pantryFoods;
  final List<String> avoidedFoods;
  final String dietStyle;
  final int cookingTimePreferenceMinutes;

  const FoodPreferences({
    this.preferredFoods = const [],
    this.pantryFoods = const [],
    this.avoidedFoods = const [],
    this.dietStyle = 'Balanced',
    this.cookingTimePreferenceMinutes = 20,
  });

  Map<String, dynamic> toJson() => {
        'preferred_foods': preferredFoods,
        'pantry_foods': pantryFoods,
        'avoided_foods': avoidedFoods,
        'diet_style': dietStyle,
        'cooking_time_preference_minutes': cookingTimePreferenceMinutes,
      };

  factory FoodPreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FoodPreferences();
    return FoodPreferences(
      preferredFoods: List<String>.from(
        json['preferred_foods'] as List? ?? const [],
      ),
      pantryFoods: List<String>.from(json['pantry_foods'] as List? ?? const []),
      avoidedFoods: List<String>.from(
        json['avoided_foods'] as List? ?? const [],
      ),
      dietStyle: json['diet_style'] as String? ?? 'Balanced',
      cookingTimePreferenceMinutes:
          json['cooking_time_preference_minutes'] as int? ?? 20,
    );
  }
}

class WorkoutPreferences {
  final int gymDaysPerWeek;
  final int preferredDurationMinutes;
  final List<String> preferredWeekdays;
  final List<String> muscleEmphases;
  final List<String> preferredExercises;

  const WorkoutPreferences({
    this.gymDaysPerWeek = 4,
    this.preferredDurationMinutes = 60,
    this.preferredWeekdays = const [],
    this.muscleEmphases = const [],
    this.preferredExercises = const [],
  });

  Map<String, dynamic> toJson() => {
        'gym_days_per_week': gymDaysPerWeek,
        'preferred_duration_minutes': preferredDurationMinutes,
        'preferred_weekdays': preferredWeekdays,
        'muscle_emphases': muscleEmphases,
        'preferred_exercises': preferredExercises,
      };

  factory WorkoutPreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WorkoutPreferences();
    return WorkoutPreferences(
      gymDaysPerWeek: json['gym_days_per_week'] as int? ?? 4,
      preferredDurationMinutes:
          json['preferred_duration_minutes'] as int? ?? 60,
      preferredWeekdays: List<String>.from(
        json['preferred_weekdays'] as List? ?? const [],
      ),
      muscleEmphases: List<String>.from(
        json['muscle_emphases'] as List? ?? const [],
      ),
      preferredExercises: List<String>.from(
        json['preferred_exercises'] as List? ?? const [],
      ),
    );
  }
}

class UserProfile {
  final String id;
  final String name;
  final int ageYears;
  final BiologicalSex sex;
  final double heightCm;
  final double weightKg;
  final ActivityBaseline activityBaseline;
  final List<String> allergies;
  final FoodPreferences foodPreferences;
  final WorkoutPreferences workoutPreferences;
  final bool usesGlp1;
  final int? wakeMinuteOfDay;
  final int? sleepMinuteOfDay;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.ageYears,
    required this.sex,
    required this.heightCm,
    required this.weightKg,
    required this.activityBaseline,
    this.allergies = const [],
    this.foodPreferences = const FoodPreferences(),
    this.workoutPreferences = const WorkoutPreferences(),
    this.usesGlp1 = false,
    this.wakeMinuteOfDay,
    this.sleepMinuteOfDay,
    required this.createdAt,
  });

  double get activityMultiplier => switch (activityBaseline) {
        ActivityBaseline.sedentary => 1.2,
        ActivityBaseline.lightlyActive => 1.375,
        ActivityBaseline.moderatelyActive => 1.55,
        ActivityBaseline.veryActive => 1.725,
        ActivityBaseline.extraActive => 1.9,
      };

  UserProfile copyWith({
    String? id,
    String? name,
    int? ageYears,
    BiologicalSex? sex,
    double? heightCm,
    double? weightKg,
    ActivityBaseline? activityBaseline,
    List<String>? allergies,
    FoodPreferences? foodPreferences,
    WorkoutPreferences? workoutPreferences,
    bool? usesGlp1,
    int? wakeMinuteOfDay,
    int? sleepMinuteOfDay,
    bool clearWakeTime = false,
    bool clearSleepTime = false,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      ageYears: ageYears ?? this.ageYears,
      sex: sex ?? this.sex,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      activityBaseline: activityBaseline ?? this.activityBaseline,
      allergies: allergies ?? this.allergies,
      foodPreferences: foodPreferences ?? this.foodPreferences,
      workoutPreferences: workoutPreferences ?? this.workoutPreferences,
      usesGlp1: usesGlp1 ?? this.usesGlp1,
      wakeMinuteOfDay:
          clearWakeTime ? null : wakeMinuteOfDay ?? this.wakeMinuteOfDay,
      sleepMinuteOfDay:
          clearSleepTime ? null : sleepMinuteOfDay ?? this.sleepMinuteOfDay,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age_years': ageYears,
        'sex': sex.name,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'activity_baseline': activityBaseline.name,
        'allergies': allergies,
        'food_preferences': foodPreferences.toJson(),
        'workout_preferences': workoutPreferences.toJson(),
        'uses_glp1': usesGlp1,
        'wake_minute_of_day': wakeMinuteOfDay,
        'sleep_minute_of_day': sleepMinuteOfDay,
        'created_at': createdAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        ageYears: j['age_years'] as int,
        sex: BiologicalSex.values.byName(j['sex'] as String),
        heightCm: (j['height_cm'] as num).toDouble(),
        weightKg: (j['weight_kg'] as num).toDouble(),
        activityBaseline: ActivityBaseline.values.byName(
          j['activity_baseline'] as String,
        ),
        allergies: List<String>.from(j['allergies'] as List? ?? const []),
        foodPreferences: FoodPreferences.fromJson(
          j['food_preferences'] as Map<String, dynamic>?,
        ),
        workoutPreferences: WorkoutPreferences.fromJson(
          j['workout_preferences'] as Map<String, dynamic>?,
        ),
        usesGlp1: j['uses_glp1'] as bool? ?? false,
        wakeMinuteOfDay: (j['wake_minute_of_day'] as num?)?.toInt(),
        sleepMinuteOfDay: (j['sleep_minute_of_day'] as num?)?.toInt(),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
