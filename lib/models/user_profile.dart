enum BiologicalSex { male, female }

enum ActivityBaseline { sedentary, lightlyActive, moderatelyActive, veryActive, extraActive }

class UserProfile {
  final String id;
  final String name;
  final int ageYears;
  final BiologicalSex sex;
  final double heightCm;
  final double weightKg;
  final ActivityBaseline activityBaseline;
  final List<String> allergies;
  final bool usesGlp1;
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
    this.usesGlp1 = false,
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
    bool? usesGlp1,
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
      usesGlp1: usesGlp1 ?? this.usesGlp1,
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
        'uses_glp1': usesGlp1,
        'created_at': createdAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        ageYears: j['age_years'] as int,
        sex: BiologicalSex.values.byName(j['sex'] as String),
        heightCm: (j['height_cm'] as num).toDouble(),
        weightKg: (j['weight_kg'] as num).toDouble(),
        activityBaseline:
            ActivityBaseline.values.byName(j['activity_baseline'] as String),
        allergies: List<String>.from(j['allergies'] as List),
        usesGlp1: j['uses_glp1'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
