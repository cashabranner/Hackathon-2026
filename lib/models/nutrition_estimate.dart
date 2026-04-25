class MicroNutrients {
  final double magnesiumMg;
  final double potassiumMg;
  final double sodiumMg;
  final double ironMg;
  final double zincMg;
  final double b12Mcg;
  final double vitaminDIu;

  const MicroNutrients({
    this.magnesiumMg = 0,
    this.potassiumMg = 0,
    this.sodiumMg = 0,
    this.ironMg = 0,
    this.zincMg = 0,
    this.b12Mcg = 0,
    this.vitaminDIu = 0,
  });

  MicroNutrients operator +(MicroNutrients other) => MicroNutrients(
        magnesiumMg: magnesiumMg + other.magnesiumMg,
        potassiumMg: potassiumMg + other.potassiumMg,
        sodiumMg: sodiumMg + other.sodiumMg,
        ironMg: ironMg + other.ironMg,
        zincMg: zincMg + other.zincMg,
        b12Mcg: b12Mcg + other.b12Mcg,
        vitaminDIu: vitaminDIu + other.vitaminDIu,
      );

  Map<String, dynamic> toJson() => {
        'magnesium_mg': magnesiumMg,
        'potassium_mg': potassiumMg,
        'sodium_mg': sodiumMg,
        'iron_mg': ironMg,
        'zinc_mg': zincMg,
        'b12_mcg': b12Mcg,
        'vitamin_d_iu': vitaminDIu,
      };

  factory MicroNutrients.fromJson(Map<String, dynamic> j) => MicroNutrients(
        magnesiumMg: (j['magnesium_mg'] as num?)?.toDouble() ?? 0,
        potassiumMg: (j['potassium_mg'] as num?)?.toDouble() ?? 0,
        sodiumMg: (j['sodium_mg'] as num?)?.toDouble() ?? 0,
        ironMg: (j['iron_mg'] as num?)?.toDouble() ?? 0,
        zincMg: (j['zinc_mg'] as num?)?.toDouble() ?? 0,
        b12Mcg: (j['b12_mcg'] as num?)?.toDouble() ?? 0,
        vitaminDIu: (j['vitamin_d_iu'] as num?)?.toDouble() ?? 0,
      );
}

class NutritionEstimate {
  final String foodName;
  final double grams;
  // Macros
  final double carbsG;
  final double glucoseG;    // portion of carbs as glucose/starch
  final double fructoseG;   // portion of carbs as fructose
  final double fiberG;
  final double proteinG;
  final double fatG;
  final double calories;
  // Micros
  final MicroNutrients micros;
  // Absorption metadata
  final bool isHighFat;     // slows gastric emptying
  final bool isHighFiber;   // slows absorption

  const NutritionEstimate({
    required this.foodName,
    required this.grams,
    required this.carbsG,
    required this.glucoseG,
    required this.fructoseG,
    required this.fiberG,
    required this.proteinG,
    required this.fatG,
    required this.calories,
    this.micros = const MicroNutrients(),
    this.isHighFat = false,
    this.isHighFiber = false,
  });

  Map<String, dynamic> toJson() => {
        'food_name': foodName,
        'grams': grams,
        'carbs_g': carbsG,
        'glucose_g': glucoseG,
        'fructose_g': fructoseG,
        'fiber_g': fiberG,
        'protein_g': proteinG,
        'fat_g': fatG,
        'calories': calories,
        'micros': micros.toJson(),
        'is_high_fat': isHighFat,
        'is_high_fiber': isHighFiber,
      };

  factory NutritionEstimate.fromJson(Map<String, dynamic> j) =>
      NutritionEstimate(
        foodName: j['food_name'] as String,
        grams: (j['grams'] as num).toDouble(),
        carbsG: (j['carbs_g'] as num).toDouble(),
        glucoseG: (j['glucose_g'] as num).toDouble(),
        fructoseG: (j['fructose_g'] as num).toDouble(),
        fiberG: (j['fiber_g'] as num).toDouble(),
        proteinG: (j['protein_g'] as num).toDouble(),
        fatG: (j['fat_g'] as num).toDouble(),
        calories: (j['calories'] as num).toDouble(),
        micros: j['micros'] != null
            ? MicroNutrients.fromJson(j['micros'] as Map<String, dynamic>)
            : const MicroNutrients(),
        isHighFat: j['is_high_fat'] as bool? ?? false,
        isHighFiber: j['is_high_fiber'] as bool? ?? false,
      );
}
