import '../models/fuel_prescription.dart';
import '../models/metabolic_state.dart';
import '../models/training_session.dart';

/// Generates a FuelPrescription from the current metabolic state and a
/// planned training session.
class PrescriptionEngine {
  static FuelPrescription planFuel(
    MetabolicState state,
    TrainingSession session,
  ) {
    final hoursUntil =
        session.plannedAt.difference(state.asOf).inMinutes / 60.0;
    final timing = _classifyTiming(hoursUntil);

    final isLiverLow = state.isLiverLow;
    final isMuscleLow = state.isMuscleLow;
    final sessionCost = session.estimatedMuscleGlycogenCostG;
    final muscleAfterSession = state.muscleGlycogenG - sessionCost;
    final urgentRefuel = muscleAfterSession < state.muscleCapacityG * 0.2;

    return switch (timing) {
      PrescriptionTiming.preLift =>
        _buildPreLift(state, session, hoursUntil, isLiverLow, isMuscleLow, urgentRefuel),
      PrescriptionTiming.immediatelyPre =>
        _buildImmediatelyPre(state, session, isLiverLow, urgentRefuel),
      PrescriptionTiming.postLift =>
        _buildPostLift(state, session, urgentRefuel),
      _ => _buildRestDay(state, session),
    };
  }

  // ─── Timing classifier ───────────────────────────────────────────────────

  static PrescriptionTiming _classifyTiming(double hoursUntil) {
    if (hoursUntil < 0) return PrescriptionTiming.postLift;
    if (hoursUntil < 0.75) return PrescriptionTiming.immediatelyPre;
    if (hoursUntil <= 3) return PrescriptionTiming.preLift;
    return PrescriptionTiming.restDay;
  }

  // ─── Pre-lift (1–3 h out) ────────────────────────────────────────────────

  static FuelPrescription _buildPreLift(
    MetabolicState state,
    TrainingSession session,
    double hoursUntil,
    bool isLiverLow,
    bool isMuscleLow,
    bool urgentRefuel,
  ) {
    final targetCarbs = isMuscleLow ? 60.0 : (isLiverLow ? 40.0 : 30.0);
    final targetProtein = 20.0;

    final pre = <FuelItem>[
      FuelItem(
        name: 'Oatmeal with banana (${targetCarbs.round()}g carbs)',
        carbsG: targetCarbs,
        proteinG: 6,
        rationale: 'Slow-release starch tops up liver glycogen; fructose from '
            'banana preferentially loads liver reserves.',
      ),
      FuelItem(
        name: 'Greek yogurt or cottage cheese',
        carbsG: 9,
        proteinG: targetProtein,
        rationale: 'Leucine-rich protein primes muscle protein synthesis; '
            'digests before training begins.',
      ),
    ];

    final why = _buildWhyPre(state, session, isLiverLow, isMuscleLow);

    return FuelPrescription(
      userId: state.userId,
      generatedAt: state.asOf,
      session: session,
      timing: PrescriptionTiming.preLift,
      headline:
          '${hoursUntil.toStringAsFixed(1)}h to lift — load carbs now',
      summary: isMuscleLow
          ? 'Your muscle glycogen is low (${state.muscleFillPct * 100 ~/ 1}% full). '
              'Eat ${targetCarbs.round()}g carbs now to give digestion time.'
          : 'Your stores are in decent shape. A moderate carb meal now sets '
              'you up well for ${session.displayName}.',
      preLiftMeals: pre,
      duringLiftFuels: _duringFuels(session),
      postLiftMeals: _postLiftItems(state, urgentRefuel),
      whyExplanation: why,
      targetCarbsG: targetCarbs,
      targetProteinG: targetProtein,
      urgentRefuel: urgentRefuel,
    );
  }

  // ─── Immediately pre (< 45 min) ─────────────────────────────────────────

  static FuelPrescription _buildImmediatelyPre(
    MetabolicState state,
    TrainingSession session,
    bool isLiverLow,
    bool urgentRefuel,
  ) {
    const targetCarbs = 20.0;
    const targetProtein = 0.0;

    final pre = <FuelItem>[
      FuelItem(
        name: 'Banana or energy gel (20g fast carbs)',
        carbsG: targetCarbs,
        rationale: 'Fast glucose raises blood glucose quickly and becomes '
            'available within 15–20 min. No fat or fiber — they would delay '
            'gastric emptying.',
      ),
    ];

    if (isLiverLow) {
      pre.add(FuelItem(
        name: 'Sports drink (16 oz)',
        carbsG: 28,
        rationale:
            'Your liver is running low; exogenous glucose spares liver '
            'output and maintains blood glucose during training.',
      ));
    }

    return FuelPrescription(
      userId: state.userId,
      generatedAt: state.asOf,
      session: session,
      timing: PrescriptionTiming.immediatelyPre,
      headline: 'Under 45 min to lift — quick carbs only',
      summary:
          'Skip heavy food; a banana or gel now means readily available '
          'glucose without GI discomfort.',
      preLiftMeals: pre,
      duringLiftFuels: _duringFuels(session),
      postLiftMeals: _postLiftItems(state, urgentRefuel),
      whyExplanation:
          'Within 45 minutes of training, only rapidly digesting carbs are '
          'useful. Fat and protein slow gastric emptying and could cause '
          'cramping. The goal is to top up blood glucose, not liver/muscle '
          'glycogen (those can\'t be meaningfully changed this close to '
          'the session).',
      targetCarbsG: targetCarbs,
      targetProteinG: targetProtein,
      urgentRefuel: urgentRefuel,
    );
  }

  // ─── Post-lift ───────────────────────────────────────────────────────────

  static FuelPrescription _buildPostLift(
    MetabolicState state,
    TrainingSession session,
    bool urgentRefuel,
  ) {
    const targetCarbs = 60.0;
    const targetProtein = 30.0;

    return FuelPrescription(
      userId: state.userId,
      generatedAt: state.asOf,
      session: session,
      timing: PrescriptionTiming.postLift,
      headline: urgentRefuel
          ? 'Urgent refuel — glycogen critically low'
          : 'Post-lift window — replenish now',
      summary: urgentRefuel
          ? 'Your projected muscle glycogen is critically depleted. '
              'Get ${targetCarbs.round()}g carbs + ${targetProtein.round()}g protein '
              'within 30 min.'
          : 'Great work. Prioritize carbs and protein within the next 1–2 hours '
              'to maximize recovery and glycogen resynthesis.',
      preLiftMeals: const [],
      duringLiftFuels: const [],
      postLiftMeals: _postLiftItems(state, urgentRefuel),
      whyExplanation:
          'After resistance training, GLUT-4 transporters are elevated for '
          '30–120 min, making muscle cells insulin-independent glucose '
          'vacuums. Consuming ${targetCarbs.round()}g carbs now drives ~3× '
          'faster glycogen resynthesis than waiting. Adding ~${targetProtein.round()}g '
          'protein triggers mTOR and starts muscle protein synthesis before '
          'the anabolic window narrows.',
      targetCarbsG: targetCarbs,
      targetProteinG: targetProtein,
      urgentRefuel: urgentRefuel,
    );
  }

  // ─── Rest day fallback ───────────────────────────────────────────────────

  static FuelPrescription _buildRestDay(
    MetabolicState state,
    TrainingSession session,
  ) {
    return FuelPrescription(
      userId: state.userId,
      generatedAt: state.asOf,
      session: session,
      timing: PrescriptionTiming.restDay,
      headline: 'Session is far out — focus on daily nutrition',
      summary:
          'Your lift is more than 3 hours away. Eat balanced meals now and '
          'revisit the prescription closer to training time.',
      preLiftMeals: const [],
      duringLiftFuels: const [],
      postLiftMeals: const [],
      whyExplanation:
          'Glycogen stores are replenished primarily through consistent '
          'carbohydrate intake throughout the day, not just around training. '
          'Focus on hitting your daily carb target (roughly ${(state.tdeeKcal * 0.45 / 4).round()}g '
          'based on your TDEE) through whole-food sources.',
      targetCarbsG: state.tdeeKcal * 0.45 / 4,
      targetProteinG: state.leanBodyMassKg * 2.0,
      urgentRefuel: false,
    );
  }

  // ─── Reusable item builders ──────────────────────────────────────────────

  static List<FuelItem> _duringFuels(TrainingSession session) {
    if (session.durationMinutes < 60) return const [];
    return [
      FuelItem(
        name: 'Sports drink or gel every 30–45 min',
        carbsG: 30,
        rationale:
            'Sessions over 60 min benefit from exogenous carbs to maintain '
            'blood glucose and delay fatigue.',
      ),
    ];
  }

  static List<FuelItem> _postLiftItems(
      MetabolicState state, bool urgent) {
    final carbsG = urgent ? 80.0 : 60.0;
    final proteinG = 30.0;

    return [
      FuelItem(
        name: 'White rice + chicken or tuna (${carbsG.round()}g carbs)',
        carbsG: carbsG,
        proteinG: proteinG,
        rationale:
            'Fast-digesting starch maximises glycogen resynthesis. Lean '
            'protein delivers all essential amino acids for muscle repair.',
      ),
      FuelItem(
        name: 'Chocolate milk (optional)',
        carbsG: 26,
        proteinG: 8,
        fatG: 5,
        rationale:
            'A convenient 3:1 carb:protein ratio with electrolytes; '
            'well-studied for recovery in endurance and resistance athletes.',
      ),
    ];
  }

  // ─── Why explanation builder ─────────────────────────────────────────────

  static String _buildWhyPre(
    MetabolicState state,
    TrainingSession session,
    bool isLiverLow,
    bool isMuscleLow,
  ) {
    final liverPct = (state.liverFillPct * 100).round();
    final musclePct = (state.muscleFillPct * 100).round();
    final cost = session.estimatedMuscleGlycogenCostG.round();

    return 'Right now your liver glycogen is at ~$liverPct% '
        '(${state.liverGlycogenG.round()}g / ${state.liverCapacityG.round()}g) '
        'and muscle glycogen is at ~$musclePct% '
        '(${state.muscleGlycogenG.round()}g / ${state.muscleCapacityG.round()}g). '
        '\n\n'
        '${session.displayName} at ${session.intensity.name} intensity '
        'is estimated to cost ~${cost}g of muscle glycogen over '
        '${session.durationMinutes} min. '
        '\n\n'
        '${isMuscleLow ? 'Your muscle stores are below 40% — you need to eat carbs '
            'now to give digestion time before the session. ' : ''}'
        '${isLiverLow ? 'Your liver is below 30% — it will struggle to maintain blood '
            'glucose during training, increasing perceived effort and reducing output. ' : ''}'
        'Eating 1–3 h out lets carbs digest and enter circulation before '
        'you start lifting, unlike last-minute fueling which stays in your gut.';
  }
}
