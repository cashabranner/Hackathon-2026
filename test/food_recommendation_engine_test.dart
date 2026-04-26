import 'package:flutter_test/flutter_test.dart';
import 'package:fuelwindow/models/user_profile.dart';
import 'package:fuelwindow/services/food_recommendation_engine.dart';

UserProfile _profile({
  List<String> preferredFoods = const [],
  List<String> pantryFoods = const [],
  List<String> avoidedFoods = const [],
  List<String> allergies = const [],
  int cookingTimeMinutes = 20,
}) =>
    UserProfile(
      id: 'u',
      name: 'Athlete',
      ageYears: 28,
      sex: BiologicalSex.male,
      heightCm: 180,
      weightKg: 80,
      activityBaseline: ActivityBaseline.moderatelyActive,
      allergies: allergies,
      foodPreferences: FoodPreferences(
        preferredFoods: preferredFoods,
        pantryFoods: pantryFoods,
        avoidedFoods: avoidedFoods,
        cookingTimePreferenceMinutes: cookingTimeMinutes,
      ),
      createdAt: DateTime(2026),
    );

void main() {
  test('Prioritizes pantry and preferred foods', () {
    final items = FoodRecommendationEngine.buildPreLiftItems(
      targetCarbsG: 40,
      targetProteinG: 20,
      profile: _profile(
        preferredFoods: ['rice'],
        pantryFoods: ['rice', 'greek yogurt'],
      ),
      fastOnly: false,
    );

    expect(items.first.name.toLowerCase(), contains('rice'));
    expect(items.map((item) => item.name.toLowerCase()).join(' '),
        contains('yogurt'));
  });

  test('Filters allergies and avoided foods', () {
    final items = FoodRecommendationEngine.buildPreLiftItems(
      targetCarbsG: 40,
      targetProteinG: 20,
      profile: _profile(
        pantryFoods: ['rice', 'greek yogurt'],
        avoidedFoods: ['rice'],
        allergies: ['dairy'],
      ),
      fastOnly: false,
    );

    final names = items.map((item) => item.name.toLowerCase()).join(' ');
    expect(names, isNot(contains('rice')));
    expect(names, isNot(contains('yogurt')));
  });

  test('Cooking time preference filters slow foods', () {
    final items = FoodRecommendationEngine.buildPreLiftItems(
      targetCarbsG: 40,
      targetProteinG: 20,
      profile: _profile(
        pantryFoods: ['rice', 'banana', 'protein shake'],
        cookingTimeMinutes: 5,
      ),
      fastOnly: false,
    );

    final names = items.map((item) => item.name.toLowerCase()).join(' ');
    expect(names, isNot(contains('rice')));
    expect(names, anyOf(contains('banana'), contains('protein shake')));
  });
}
