import 'package:flutter_test/flutter_test.dart';
import 'package:fuelwindow/services/food_parser.dart';

void main() {
  group('FoodParser.parseText', () {
    test('Returns estimate for known food (oatmeal)', () {
      final result = FoodParser.parseText('oatmeal with blueberries');
      expect(result.carbsG, greaterThan(0));
      expect(result.foodName, isNotEmpty);
    });

    test('Returns fallback for unknown input', () {
      final result = FoodParser.parseText('zzznooozzzfood');
      expect(result.foodName, isNotEmpty);
      expect(result.carbsG, greaterThan(0));
    });

    test('Returns fallback for empty input', () {
      final result = FoodParser.parseText('');
      expect(result.foodName, isNotEmpty);
    });

    test('Identifies eggs as high-fat', () {
      final result = FoodParser.parseText('two scrambled eggs');
      expect(result.isHighFat, isTrue);
    });

    test('Identifies oatmeal as high-fiber', () {
      final result = FoodParser.parseText('bowl of oats');
      expect(result.isHighFiber, isTrue);
    });

    test('Rice has mostly glucose, not fructose', () {
      final result = FoodParser.parseText('white rice');
      expect(result.glucoseG, greaterThan(result.fructoseG));
    });

    test('Banana has significant fructose', () {
      final result = FoodParser.parseText('banana');
      expect(result.fructoseG, greaterThan(0));
    });

    test('Protein shake has high protein', () {
      final result = FoodParser.parseText('whey protein shake');
      expect(result.proteinG, greaterThan(15));
    });

    test('Calories are non-zero for real foods', () {
      final foods = ['chicken', 'salmon', 'rice', 'pasta', 'yogurt'];
      for (final f in foods) {
        final r = FoodParser.parseText(f);
        expect(r.calories, greaterThan(0), reason: 'Failed for $f');
      }
    });

    test('Glucose + fructose <= carbs (within float tolerance)', () {
      final foods = ['oatmeal', 'banana', 'apple', 'rice', 'pasta'];
      for (final f in foods) {
        final r = FoodParser.parseText(f);
        expect(r.glucoseG + r.fructoseG, lessThanOrEqualTo(r.carbsG + 0.1),
            reason: 'G+F > carbs for $f');
      }
    });
  });
}
