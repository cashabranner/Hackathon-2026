import 'nutrition_estimate.dart';

class FoodCatalogEntry {
  final String id;
  final String displayName;
  final List<String> aliases;
  final String servingLabel;
  final double defaultServingQty;
  final NutritionEstimate nutritionPerServing;
  final int cookingTimeMinutes;

  const FoodCatalogEntry({
    required this.id,
    required this.displayName,
    required this.aliases,
    required this.servingLabel,
    this.defaultServingQty = 1,
    required this.nutritionPerServing,
    this.cookingTimeMinutes = 10,
  });
}

class ParsedFoodItem {
  final String catalogEntryId;
  final String displayName;
  final double servingQty;
  final String servingLabel;
  final NutritionEstimate nutritionPerServing;

  const ParsedFoodItem({
    required this.catalogEntryId,
    required this.displayName,
    required this.servingQty,
    required this.servingLabel,
    required this.nutritionPerServing,
  });

  NutritionEstimate get nutrition => NutritionEstimate(
        foodName: displayName,
        grams: nutritionPerServing.grams * servingQty,
        carbsG: nutritionPerServing.carbsG * servingQty,
        glucoseG: nutritionPerServing.glucoseG * servingQty,
        fructoseG: nutritionPerServing.fructoseG * servingQty,
        fiberG: nutritionPerServing.fiberG * servingQty,
        proteinG: nutritionPerServing.proteinG * servingQty,
        fatG: nutritionPerServing.fatG * servingQty,
        calories: nutritionPerServing.calories * servingQty,
        micros: nutritionPerServing.micros,
        isHighFat: nutritionPerServing.isHighFat,
        isHighFiber: nutritionPerServing.isHighFiber,
      );

  ParsedFoodItem copyWith({
    String? catalogEntryId,
    String? displayName,
    double? servingQty,
    String? servingLabel,
    NutritionEstimate? nutritionPerServing,
  }) {
    return ParsedFoodItem(
      catalogEntryId: catalogEntryId ?? this.catalogEntryId,
      displayName: displayName ?? this.displayName,
      servingQty: servingQty ?? this.servingQty,
      servingLabel: servingLabel ?? this.servingLabel,
      nutritionPerServing: nutritionPerServing ?? this.nutritionPerServing,
    );
  }
}

class SavedFood {
  final String id;
  final String name;
  final String servingLabel;
  final double defaultServingQty;
  final NutritionEstimate nutrition;

  const SavedFood({
    required this.id,
    required this.name,
    required this.servingLabel,
    this.defaultServingQty = 1,
    required this.nutrition,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'serving_label': servingLabel,
        'default_serving_qty': defaultServingQty,
        'nutrition': nutrition.toJson(),
      };

  factory SavedFood.fromJson(Map<String, dynamic> json) => SavedFood(
        id: json['id'] as String,
        name: json['name'] as String,
        servingLabel: json['serving_label'] as String,
        defaultServingQty:
            (json['default_serving_qty'] as num?)?.toDouble() ?? 1,
        nutrition: NutritionEstimate.fromJson(
          json['nutrition'] as Map<String, dynamic>,
        ),
      );
}

NutritionEstimate aggregateParsedFoodItems(
  List<ParsedFoodItem> items, {
  String? foodName,
}) {
  if (items.isEmpty) {
    return NutritionEstimate(
      foodName: foodName?.trim().isEmpty == false ? foodName!.trim() : 'Meal',
      grams: 0,
      carbsG: 0,
      glucoseG: 0,
      fructoseG: 0,
      fiberG: 0,
      proteinG: 0,
      fatG: 0,
      calories: 0,
    );
  }

  final label = foodName?.trim().isNotEmpty == true
      ? foodName!.trim()
      : items.map((item) => item.displayName).join(' + ');

  return items.fold<NutritionEstimate>(
    NutritionEstimate(
      foodName: label,
      grams: 0,
      carbsG: 0,
      glucoseG: 0,
      fructoseG: 0,
      fiberG: 0,
      proteinG: 0,
      fatG: 0,
      calories: 0,
    ),
    (sum, item) {
      final nutrition = item.nutrition;
      return NutritionEstimate(
        foodName: label,
        grams: sum.grams + nutrition.grams,
        carbsG: sum.carbsG + nutrition.carbsG,
        glucoseG: sum.glucoseG + nutrition.glucoseG,
        fructoseG: sum.fructoseG + nutrition.fructoseG,
        fiberG: sum.fiberG + nutrition.fiberG,
        proteinG: sum.proteinG + nutrition.proteinG,
        fatG: sum.fatG + nutrition.fatG,
        calories: sum.calories + nutrition.calories,
        isHighFat: sum.isHighFat || nutrition.isHighFat,
        isHighFiber: sum.isHighFiber || nutrition.isHighFiber,
      );
    },
  );
}
