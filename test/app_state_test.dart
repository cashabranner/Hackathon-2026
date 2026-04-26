import 'package:flutter_test/flutter_test.dart';
import 'package:fuelwindow/demo/demo_accounts.dart';
import 'package:fuelwindow/repositories/app_state.dart';

void main() {
  test('Demo account workout times are rebased to the current clock', () {
    final state = AppState();
    try {
      final demo = DemoAccounts.all[1];

      state.loadDemoAccount(demo);

      final session = state.nextSession;
      expect(session, isNotNull);

      final demoOffset = demo.session.plannedAt.difference(demo.now);
      final actualOffset = session!.plannedAt.difference(state.now);
      expect(
        actualOffset.inMinutes,
        closeTo(demoOffset.inMinutes, 1),
      );

      final demoFoodOffset = demo.foodLogs.first.loggedAt.difference(demo.now);
      final actualFoodOffset =
          state.foodLogs.first.loggedAt.difference(state.now);
      expect(
        actualFoodOffset.inMinutes,
        closeTo(demoFoodOffset.inMinutes, 1),
      );
    } finally {
      state.dispose();
    }
  });
}
