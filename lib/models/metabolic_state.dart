enum BloodGlucosePhase {
  fasted,       // <4.0 mmol/L equivalent
  stable,       // 4.0–5.5 mmol/L
  postPrandial, // rising after a meal
  elevated,     // >7.0 mmol/L
}

enum Glp1Status { notActive, mildlySuppressed, moderatelySuppressed }

class GlycogenPoint {
  final DateTime time;
  final double liverGlycogenG;
  final double muscleGlycogenG;
  final double bloodGlucoseProxy; // 0–100 index (not mmol/L)

  const GlycogenPoint({
    required this.time,
    required this.liverGlycogenG,
    required this.muscleGlycogenG,
    required this.bloodGlucoseProxy,
  });
}

class MetabolicState {
  final String userId;
  final DateTime asOf;

  // Biometric-derived capacities
  final double leanBodyMassKg;
  final double bmrKcal;
  final double tdeeKcal;
  final double liverCapacityG;
  final double muscleCapacityG;

  // Current stores
  final double liverGlycogenG;
  final double muscleGlycogenG;

  // Phase indicators
  final BloodGlucosePhase bloodGlucosePhase;
  final Glp1Status glp1Status;

  // Daily macro totals so far
  final double totalCarbsG;
  final double totalProteinG;
  final double totalFatG;
  final double totalCalories;
  final double totalFiberG;

  // Intraday curve (for charting)
  final List<GlycogenPoint> curve;

  const MetabolicState({
    required this.userId,
    required this.asOf,
    required this.leanBodyMassKg,
    required this.bmrKcal,
    required this.tdeeKcal,
    required this.liverCapacityG,
    required this.muscleCapacityG,
    required this.liverGlycogenG,
    required this.muscleGlycogenG,
    required this.bloodGlucosePhase,
    this.glp1Status = Glp1Status.notActive,
    this.totalCarbsG = 0,
    this.totalProteinG = 0,
    this.totalFatG = 0,
    this.totalCalories = 0,
    this.totalFiberG = 0,
    this.curve = const [],
  });

  double get liverFillPct =>
      (liverGlycogenG / liverCapacityG).clamp(0.0, 1.0);
  double get muscleFillPct =>
      (muscleGlycogenG / muscleCapacityG).clamp(0.0, 1.0);
  bool get isLiverLow => liverGlycogenG < liverCapacityG * 0.3;
  bool get isMuscleLow => muscleGlycogenG < muscleCapacityG * 0.4;

  MetabolicState copyWith({
    String? userId,
    DateTime? asOf,
    double? leanBodyMassKg,
    double? bmrKcal,
    double? tdeeKcal,
    double? liverCapacityG,
    double? muscleCapacityG,
    double? liverGlycogenG,
    double? muscleGlycogenG,
    BloodGlucosePhase? bloodGlucosePhase,
    Glp1Status? glp1Status,
    double? totalCarbsG,
    double? totalProteinG,
    double? totalFatG,
    double? totalCalories,
    double? totalFiberG,
    List<GlycogenPoint>? curve,
  }) {
    return MetabolicState(
      userId: userId ?? this.userId,
      asOf: asOf ?? this.asOf,
      leanBodyMassKg: leanBodyMassKg ?? this.leanBodyMassKg,
      bmrKcal: bmrKcal ?? this.bmrKcal,
      tdeeKcal: tdeeKcal ?? this.tdeeKcal,
      liverCapacityG: liverCapacityG ?? this.liverCapacityG,
      muscleCapacityG: muscleCapacityG ?? this.muscleCapacityG,
      liverGlycogenG: liverGlycogenG ?? this.liverGlycogenG,
      muscleGlycogenG: muscleGlycogenG ?? this.muscleGlycogenG,
      bloodGlucosePhase: bloodGlucosePhase ?? this.bloodGlucosePhase,
      glp1Status: glp1Status ?? this.glp1Status,
      totalCarbsG: totalCarbsG ?? this.totalCarbsG,
      totalProteinG: totalProteinG ?? this.totalProteinG,
      totalFatG: totalFatG ?? this.totalFatG,
      totalCalories: totalCalories ?? this.totalCalories,
      totalFiberG: totalFiberG ?? this.totalFiberG,
      curve: curve ?? this.curve,
    );
  }
}
