import '../models/food_catalog.dart';
import '../models/fuel_prescription.dart';
import '../models/user_profile.dart';
import 'food_parser.dart';

class FoodRecommendationEngine {
  static List<FuelItem> buildPreLiftItems({
    required double targetCarbsG,
    required double targetProteinG,
    required UserProfile? profile,
    required bool fastOnly,
  }) {
    final foods = _rankedFoods(profile, fastOnly: fastOnly);
    final carb = _firstMacroFit(
      foods,
      targetCarbsG: targetCarbsG,
      maxFatG: fastOnly ? 5 : null,
    );
    final protein = targetProteinG <= 0
        ? null
        : _firstMacroFit(foods, targetProteinG: targetProteinG);

    final items = <FuelItem>[];
    if (carb != null) {
      items.add(_fuelItemFor(carb, targetCarbsG, targetProteinG: 0));
    } else {
      items.add(
        FuelItem(
          name: 'Banana + sports drink (${targetCarbsG.round()}g carbs)',
          carbsG: targetCarbsG,
          rationale: 'Simple fast carbs meet the target without much cooking.',
        ),
      );
    }

    if (protein != null) {
      items.add(_fuelItemFor(protein, 0, targetProteinG: targetProteinG));
    } else if (targetProteinG > 0) {
      items.add(
        FuelItem(
          name: 'Greek yogurt or protein shake',
          carbsG: 8,
          proteinG: targetProteinG,
          fatG: 2,
          rationale: 'A quick protein add-on rounds out the meal.',
        ),
      );
    }

    return items;
  }

  static List<FuelItem> buildPostLiftItems({
    required double targetCarbsG,
    required double targetProteinG,
    required UserProfile? profile,
  }) {
    final foods = _rankedFoods(profile);
    final carb = _firstMacroFit(foods, targetCarbsG: targetCarbsG);
    final protein = _firstMacroFit(foods, targetProteinG: targetProteinG);

    return [
      if (carb != null)
        _fuelItemFor(carb, targetCarbsG, targetProteinG: 0)
      else
        FuelItem(
          name: 'White rice or bread (${targetCarbsG.round()}g carbs)',
          carbsG: targetCarbsG,
          rationale: 'A starch-heavy base replenishes glycogen efficiently.',
        ),
      if (protein != null)
        _fuelItemFor(protein, 0, targetProteinG: targetProteinG)
      else
        FuelItem(
          name: 'Chicken breast or protein shake',
          carbsG: 0,
          proteinG: targetProteinG,
          fatG: 3,
          rationale: 'Lean protein supports repair after training.',
        ),
    ];
  }

  static List<FoodCatalogEntry> _rankedFoods(
    UserProfile? profile, {
    bool fastOnly = false,
  }) {
    final prefs = profile?.foodPreferences;
    final preferred = _normalizedSet(prefs?.preferredFoods ?? const []);
    final pantry = _normalizedSet(prefs?.pantryFoods ?? const []);
    final avoided = _normalizedSet([
      ...profile?.allergies ?? const [],
      ...prefs?.avoidedFoods ?? const [],
    ]);
    final maxCookTime =
        fastOnly ? 5 : (prefs?.cookingTimePreferenceMinutes ?? 20);

    final foods = foodCatalog.where((entry) {
      final text = _entryText(entry);
      final isAvoided = avoided.any(text.contains);
      return !isAvoided && entry.cookingTimeMinutes <= maxCookTime;
    }).toList();

    foods.sort((a, b) {
      final aScore = _preferenceScore(a, preferred, pantry);
      final bScore = _preferenceScore(b, preferred, pantry);
      return bScore.compareTo(aScore);
    });
    return foods;
  }

  static Set<String> _normalizedSet(List<String> values) => values
      .map((value) => value.toLowerCase().trim())
      .where((v) => v.isNotEmpty)
      .toSet();

  static int _preferenceScore(
    FoodCatalogEntry entry,
    Set<String> preferred,
    Set<String> pantry,
  ) {
    final text = _entryText(entry);
    var score = 0;
    if (pantry.any(text.contains)) score += 20;
    if (preferred.any(text.contains)) score += 10;
    if (entry.cookingTimeMinutes <= 5) score += 2;
    return score;
  }

  static String _entryText(FoodCatalogEntry entry) =>
      '${entry.displayName} ${entry.aliases.join(' ')}'.toLowerCase();

  static FoodCatalogEntry? _firstMacroFit(
    List<FoodCatalogEntry> foods, {
    double targetCarbsG = 0,
    double targetProteinG = 0,
    double? maxFatG,
  }) {
    for (final food in foods) {
      final nutrition = food.nutritionPerServing;
      if (maxFatG != null && nutrition.fatG > maxFatG) continue;
      if (targetCarbsG > 0 && nutrition.carbsG >= 15) return food;
      if (targetProteinG > 0 && nutrition.proteinG >= 10) return food;
    }
    return null;
  }

  static FuelItem _fuelItemFor(
    FoodCatalogEntry food,
    double targetCarbsG, {
    required double targetProteinG,
  }) {
    final nutrition = food.nutritionPerServing;
    final carbServings =
        targetCarbsG <= 0 ? 0 : targetCarbsG / nutrition.carbsG.clamp(1, 999);
    final proteinServings = targetProteinG <= 0
        ? 0
        : targetProteinG / nutrition.proteinG.clamp(1, 999);
    final servings = [carbServings, proteinServings, 1.0]
        .where((value) => value > 0)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, 4)
        .toDouble();

    return FuelItem(
      name:
          '${_formatServings(servings)} ${food.servingLabel} ${food.displayName}',
      carbsG: nutrition.carbsG * servings,
      proteinG: nutrition.proteinG * servings,
      fatG: nutrition.fatG * servings,
      rationale: 'Prioritized from your available or preferred foods.',
    );
  }

  static String _formatServings(double servings) {
    final rounded = (servings * 2).round() / 2;
    if (rounded == rounded.roundToDouble()) return rounded.round().toString();
    return rounded.toStringAsFixed(1);
  }
}
