import 'package:flutter_test/flutter_test.dart';

import 'package:fuelwindow/app.dart';

void main() {
  testWidgets('FuelWindow app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const FuelWindowApp());
    await tester.pump();

    expect(find.text('FuelWindow'), findsWidgets);
  });
}
