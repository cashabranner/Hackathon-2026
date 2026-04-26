import 'package:flutter_test/flutter_test.dart';

import 'package:fuelwindow/app.dart';

void main() {
  testWidgets('Fuel app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const FuelApp());
    await tester.pump();

    expect(find.text('Fuel'), findsWidgets);
  });
}
