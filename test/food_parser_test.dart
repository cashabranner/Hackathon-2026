import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuelwindow/services/food_parser.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

    test('Parses quantity for eggs instead of fixed two-egg serving', () {
      final result = FoodParser.parseText('3 eggs');
      expect(result.foodName, '3 eggs');
      expect(result.proteinG, closeTo(19.5, 0.1));
      expect(result.calories, closeTo(216, 0.1));
    });

    test('Aggregates multiple parsed foods', () {
      final result = FoodParser.parseText('2 eggs and 1 banana');
      expect(result.proteinG, greaterThan(13));
      expect(result.carbsG, greaterThan(25));
      expect(result.calories, greaterThan(240));
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

  group('FoodParser remote parsing', () {
    test('Sends text payload and parses remote nutrition response', () async {
      Map<String, dynamic>? sentPayload;
      final client = MockClient((request) async {
        sentPayload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(request.headers['apikey'], 'anon-key');
        expect(request.headers['Authorization'], 'Bearer anon-key');
        return http.Response(jsonEncode(_nutritionJson()), 200);
      });

      final result = await FoodParser.parseTextRemote(
        'turkey sandwich and apple',
        'https://example.test/functions/v1/food-parser',
        'anon-key',
        client: client,
      );

      expect(sentPayload, {'description': 'turkey sandwich and apple'});
      expect(result.foodName, 'Granola Bar');
      expect(result.carbsG, 24);
    });

    test('Builds image request payload with base64 bytes and MIME type', () {
      final payload = FoodParser.buildRemoteRequestBody(
        imageBytes: [1, 2, 3, 4],
        mimeType: 'IMAGE/JPEG',
      );

      expect(payload, {
        'image_base64': base64Encode([1, 2, 3, 4]),
        'mime_type': 'image/jpeg',
      });
    });

    test('Rejects oversized images before upload', () {
      expect(
        () => FoodParser.buildRemoteRequestBody(
          imageBytes:
              List.filled(FoodParser.maxNutritionLabelImageBytes + 1, 0),
          mimeType: 'image/jpeg',
        ),
        throwsA(isA<FoodParserException>()),
      );
    });

    test('Accepts HEIC images for Gemini nutrition label scanning', () {
      final payload = FoodParser.buildRemoteRequestBody(
        imageBytes: [1, 2, 3],
        mimeType: 'image/heic',
      );

      expect(payload['mime_type'], 'image/heic');
    });

    test('Rejects unsupported nutrition label image MIME types', () {
      expect(
        () => FoodParser.buildRemoteRequestBody(
          imageBytes: [1, 2, 3],
          mimeType: 'image/gif',
        ),
        throwsA(isA<FoodParserException>()),
      );
    });

    test('Sends image payload and parses remote nutrition response', () async {
      Map<String, dynamic>? sentPayload;
      final client = MockClient((request) async {
        sentPayload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(request.headers['apikey'], 'anon-key');
        expect(request.headers['Authorization'], 'Bearer anon-key');
        return http.Response(jsonEncode(_nutritionJson()), 200);
      });

      final result = await FoodParser.parseNutritionLabelImageRemote(
        bytes: [10, 20, 30],
        mimeType: 'image/png',
        edgeFunctionUrl: 'https://example.test/functions/v1/food-parser',
        anonKey: 'anon-key',
        client: client,
      );

      expect(sentPayload?['image_base64'], base64Encode([10, 20, 30]));
      expect(sentPayload?['mime_type'], 'image/png');
      expect(sentPayload?.containsKey('description'), isFalse);
      expect(result.foodName, 'Granola Bar');
      expect(result.carbsG, 24);
    });
  });
}

Map<String, dynamic> _nutritionJson() => {
      'food_name': 'Granola Bar',
      'grams': 48,
      'carbs_g': 24,
      'glucose_g': 18,
      'fructose_g': 3,
      'fiber_g': 3,
      'protein_g': 5,
      'fat_g': 7,
      'calories': 180,
      'micros': {
        'magnesium_mg': 0,
        'potassium_mg': 0,
        'sodium_mg': 95,
        'iron_mg': 0,
        'zinc_mg': 0,
        'b12_mcg': 0,
        'vitamin_d_iu': 0,
      },
      'is_high_fat': false,
      'is_high_fiber': false,
    };
