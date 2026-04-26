import 'package:go_router/go_router.dart';

import 'repositories/app_state.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/food_log/food_log_screen.dart';
import 'screens/lift_planner/lift_planner_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/prescription/prescription_screen.dart';

GoRouter buildRouter(AppState appState) {
  return GoRouter(
    initialLocation: '/onboarding',
    redirect: (context, state) {
      final hasProfile = appState.hasProfile;
      final isOnboarding = state.matchedLocation.startsWith('/onboarding');
      final isEditingProfile = state.uri.queryParameters['edit'] == 'true';
      if (!hasProfile && !isOnboarding) return '/onboarding';
      if (hasProfile && isOnboarding && !isEditingProfile) return '/dashboard';
      return null;
    },
    refreshListenable: appState,
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (ctx, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (ctx, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/food-log',
        builder: (ctx, state) => const FoodLogScreen(),
      ),
      GoRoute(
        path: '/lift-planner',
        builder: (ctx, state) => const LiftPlannerScreen(),
      ),
      GoRoute(
        path: '/prescription',
        builder: (ctx, state) => const PrescriptionScreen(),
      ),
    ],
  );
}
