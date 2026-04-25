import '../models/fuel_prescription.dart';
import '../models/metabolic_state.dart';
import '../models/training_session.dart';

/// Returns physiology explanations for prescription cards.
/// Cached demo explanations ship with the app; future Supabase integration
/// can replace with AI-generated, user-personalized text.
class ExplanationService {
  static String explainPrescription(
    FuelPrescription prescription,
    MetabolicState state,
    TrainingSession session,
  ) {
    // Check for a cached demo explanation first
    final cached = _cachedExplanations[session.type]?[prescription.timing];
    if (cached != null) return cached;

    // Fall through to the inline explanation on the prescription itself
    return prescription.whyExplanation;
  }

  static String explainGlycogen() =>
      'Glycogen is the storage form of glucose in your body. Your liver holds '
      '~100g and releases it to maintain blood glucose between meals and '
      'during exercise. Your muscles hold far more (proportional to your '
      'lean mass) and use it directly as fuel during high-intensity training. '
      'Unlike fat, glycogen is rapidly accessible — but the tank is small.';

  static String explainFructose() =>
      'Fructose is metabolized almost exclusively in the liver and '
      'preferentially replenishes liver glycogen. Fruits, honey, and table '
      'sugar contain significant fructose. For liver top-up, fruit is useful; '
      'for muscle loading, glucose-rich starches (oats, rice, bread) are more '
      'effective since fructose has limited muscle uptake.';

  static String explainGlp1() =>
      'GLP-1 (glucagon-like peptide-1) is a gut hormone that slows gastric '
      'emptying, reduces appetite, and blunts post-meal glucose spikes. '
      'GLP-1 agonist medications amplify this effect. If you use one, you '
      'may need smaller pre-workout meals since food sits in the stomach '
      'longer — helpful for blood sugar stability but requires planning.';

  // ─── Cached demo explanations by session type × timing ─────────────────

  static const _cachedExplanations = <SessionType, Map<PrescriptionTiming, String>>{
    SessionType.legs: {
      PrescriptionTiming.preLift:
          'Leg day is the highest glycogen-demand session in most training '
          'programs. Quads, hamstrings, and glutes are the largest muscle '
          'groups in your body — and they preferentially burn muscle glycogen '
          'at high intensities. A depleted muscle tank before squats or '
          'deadlifts doesn\'t just limit reps; it shifts your body toward '
          'cortisol-driven protein catabolism as a fuel fallback.\n\n'
          'Eating 1–3 h out gives glucose time to clear the gut, enter '
          'circulation, and be shuttled into muscle via insulin-mediated '
          'GLUT-4 uptake. Fructose in the same meal preferentially loads '
          'liver reserves, which sustain blood glucose throughout the session '
          'as muscle glycogen depletes.',
      PrescriptionTiming.postLift:
          'After an intense leg session your muscle GLUT-4 transporter '
          'activity is elevated for 30–120 minutes, meaning glucose enters '
          'muscle cells without needing insulin — the fastest possible '
          'glycogen resynthesis rate. Miss this window and resynthesis slows '
          'dramatically. Pair fast-digesting carbs (white rice, banana, '
          'sports drink) with 25–40g protein to drive mTOR activation and '
          'begin muscle repair before soreness peaks.',
    },
    SessionType.hiit: {
      PrescriptionTiming.preLift:
          'HIIT sessions burn glycogen faster than almost any other modality '
          '— up to 1.5g per minute during peak intervals. Starting with '
          'depleted stores means earlier fatigue, reduced power output, and '
          'impaired EPOC (excess post-exercise oxygen consumption). Pre-HIIT '
          'carbs are not optional; they directly determine whether your '
          'high-intensity intervals actually reach target intensity.',
    },
    SessionType.steadyStateCardio: {
      PrescriptionTiming.preLift:
          'Moderate steady-state cardio (60–70% max HR) primarily uses fat '
          'for fuel. Glycogen demand is much lower than HIIT or lifting. '
          'If you\'re training fasted for fat oxidation, that\'s metabolically '
          'sound for sessions under 60 minutes. Longer sessions or those '
          'combined with strength work still benefit from carb availability.',
    },
  };
}
