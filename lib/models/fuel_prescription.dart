import 'training_session.dart';

enum PrescriptionTiming {
  preLift, // 1–3 hours before
  immediatelyPre, // 30–60 min before
  duringLift,
  postLift,
  restDay,
}

class FuelItem {
  final String name;
  final double carbsG;
  final double proteinG;
  final double fatG;
  final String rationale;

  const FuelItem({
    required this.name,
    required this.carbsG,
    this.proteinG = 0,
    this.fatG = 0,
    required this.rationale,
  });
}

class FuelPrescription {
  final String userId;
  final DateTime generatedAt;
  final TrainingSession session;
  final PrescriptionTiming timing;
  final String headline;
  final String summary;
  final List<FuelItem> preLiftMeals;
  final List<FuelItem> duringLiftFuels;
  final List<FuelItem> postLiftMeals;
  final String whyExplanation;
  final double targetCarbsG;
  final double targetProteinG;
  final bool urgentRefuel;

  const FuelPrescription({
    required this.userId,
    required this.generatedAt,
    required this.session,
    required this.timing,
    required this.headline,
    required this.summary,
    required this.preLiftMeals,
    required this.duringLiftFuels,
    required this.postLiftMeals,
    required this.whyExplanation,
    required this.targetCarbsG,
    required this.targetProteinG,
    this.urgentRefuel = false,
  });
}
