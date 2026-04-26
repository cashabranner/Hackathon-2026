import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../config/app_config.dart';
import '../../models/food_log.dart';
import '../../models/metabolic_state.dart';
import '../../models/nutrition_estimate.dart';
import '../../models/training_session.dart';
import '../../models/user_profile.dart';
import '../../models/workout_split.dart';
import '../../repositories/app_state.dart';
import '../../services/food_parser.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/glycogen_chart.dart';
import '../../widgets/macro_totals_card.dart';

enum _MainTab { home, food, workout, calendar, settings }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  _MainTab _tab = _MainTab.home;
  DateTime _selectedDate = DateTime.now();
  bool _dateInitialized = false;

  final _mealNameCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _mealFocus = FocusNode();
  bool _aiAutofill = true;
  bool _isAutofilling = false;

  final _workoutNameCtrl = TextEditingController();
  final _workoutDurationCtrl = TextEditingController(text: '60');
  final List<_LoggedWorkout> _loggedWorkouts = [];

  @override
  void initState() {
    super.initState();
    _mealFocus.addListener(() {
      if (!_mealFocus.hasFocus) _autofillMacros();
    });
  }

  @override
  void dispose() {
    _mealNameCtrl.dispose();
    _carbsCtrl.dispose();
    _proteinCtrl.dispose();
    _fatCtrl.dispose();
    _mealFocus.dispose();
    _workoutNameCtrl.dispose();
    _workoutDurationCtrl.dispose();
    super.dispose();
  }

  Future<void> _autofillMacros() async {
    final mealName = _mealNameCtrl.text.trim();
    if (!_aiAutofill || mealName.isEmpty || _isAutofilling) return;

    setState(() => _isAutofilling = true);
    final allergies = context.read<AppState>().profile?.allergies ?? const [];

    late NutritionEstimate estimate;
    var usedRemoteParser = false;
    try {
      if (AppConfig.hasRemoteFoodParser) {
        estimate = await FoodParser.parseTextRemote(
          mealName,
          AppConfig.foodParserUrl,
          AppConfig.supabaseAnonKey,
        );
        usedRemoteParser = true;
      } else {
        estimate = FoodParser.parseText(
          mealName,
          allergies: allergies,
        );
      }
    } catch (_) {
      estimate = FoodParser.parseText(
        mealName,
        allergies: allergies,
      );
      if (mounted && AppConfig.hasRemoteFoodParser) {
        _showSnack('AI parser unavailable, using local estimate.');
      }
    }

    if (!mounted) return;
    setState(() {
      _carbsCtrl.text = estimate.carbsG.round().toString();
      _proteinCtrl.text = estimate.proteinG.round().toString();
      _fatCtrl.text = estimate.fatG.round().toString();
      _isAutofilling = false;
    });

    if (usedRemoteParser) {
      _showSnack('AI macros filled.');
    }
  }

  Future<void> _addMeal() async {
    final name = _mealNameCtrl.text.trim();
    final carbs = double.tryParse(_carbsCtrl.text.trim()) ?? 0;
    final protein = double.tryParse(_proteinCtrl.text.trim()) ?? 0;
    final fat = double.tryParse(_fatCtrl.text.trim()) ?? 0;
    if (name.isEmpty || (carbs + protein + fat) <= 0) {
      _showSnack('Add a meal name and at least one macro.');
      return;
    }

    final estimate = NutritionEstimate(
      foodName: name,
      grams: 0,
      carbsG: carbs,
      glucoseG: carbs * 0.75,
      fructoseG: carbs * 0.25,
      fiberG: 0,
      proteinG: protein,
      fatG: fat,
      calories: carbs * 4 + protein * 4 + fat * 9,
      isHighFat: fat >= 15,
      isHighFiber: false,
    );

    await context.read<AppState>().logFood(
          name,
          nutrition: estimate,
          source: 'manual',
        );

    if (!mounted) return;
    _mealNameCtrl.clear();
    _carbsCtrl.clear();
    _proteinCtrl.clear();
    _fatCtrl.clear();
    _showSnack('Meal added.');
  }

  void _logWorkout() {
    final name = _workoutNameCtrl.text.trim().isEmpty
        ? 'Workout'
        : _workoutNameCtrl.text.trim();
    final duration = int.tryParse(_workoutDurationCtrl.text.trim()) ?? 60;
    setState(() {
      _loggedWorkouts.insert(
        0,
        _LoggedWorkout(
          name: name,
          durationMinutes: duration,
          dateLabel: DateFormat('MMM d').format(DateTime.now()),
        ),
      );
      _workoutNameCtrl.clear();
      _workoutDurationCtrl.text = '60';
    });
    _showSnack('Workout logged.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile;
    final metabolicState = state.metabolicState;

    if (profile == null || metabolicState == null) {
      return const Scaffold(
        body: GradientShell(child: Center(child: CircularProgressIndicator())),
      );
    }

    if (!_dateInitialized) {
      _selectedDate = state.now;
      _dateInitialized = true;
    }

    return Scaffold(
      body: GradientShell(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  _Header(
                    profileName: profile.name,
                    isDemoMode: state.isDemoMode,
                    onDemoTap: () {
                      context.read<AppState>().clearDemo();
                      context.go('/onboarding');
                    },
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        if (_tab == _MainTab.home)
                          _HomePage(
                            state: state,
                            metabolicState: metabolicState,
                            onPlanLift: () => context.push('/lift-planner'),
                            onLogFood: () =>
                                setState(() => _tab = _MainTab.food),
                            onDetails: () => context.push('/prescription'),
                          ),
                        if (_tab == _MainTab.food)
                          _FoodPage(
                            appState: state,
                            mealNameCtrl: _mealNameCtrl,
                            carbsCtrl: _carbsCtrl,
                            proteinCtrl: _proteinCtrl,
                            fatCtrl: _fatCtrl,
                            mealFocus: _mealFocus,
                            aiAutofill: _aiAutofill,
                            isAutofilling: _isAutofilling,
                            onAiChanged: (value) =>
                                setState(() => _aiAutofill = value),
                            onAddMeal: _addMeal,
                            onAutofill: _autofillMacros,
                            onMealChanged: (_) => setState(() {}),
                            onScanLabel: () => _showSnack(
                              'Camera label scanning is ready for a device build.',
                            ),
                          ),
                        if (_tab == _MainTab.workout)
                          _WorkoutPage(
                            splits: state.workoutSplits,
                            loggedWorkouts: _loggedWorkouts,
                            workoutNameCtrl: _workoutNameCtrl,
                            workoutDurationCtrl: _workoutDurationCtrl,
                            onPlan: () => context.push('/lift-planner'),
                            onLog: _logWorkout,
                            onSplits: _showSplitsSheet,
                          ),
                        if (_tab == _MainTab.calendar)
                          _CalendarPage(
                            appState: state,
                            selectedDate: _selectedDate,
                            onPrevious: () => setState(
                              () => _selectedDate = _selectedDate
                                  .subtract(const Duration(days: 1)),
                            ),
                            onNext: () => setState(
                              () => _selectedDate =
                                  _selectedDate.add(const Duration(days: 1)),
                            ),
                            onToday: () =>
                                setState(() => _selectedDate = state.now),
                            onPickDate: (date) =>
                                setState(() => _selectedDate = date),
                            onAddEvent: _showAddEventSheet,
                          ),
                        if (_tab == _MainTab.settings)
                          _SettingsPage(
                            appState: state,
                            onEditProfile: () =>
                                context.go('/onboarding?edit=true'),
                            onReset: () {
                              context.read<AppState>().clearDemo();
                              context.go('/onboarding');
                            },
                          ),
                      ],
                    ),
                  ),
                  _BottomNav(
                    current: _tab,
                    onSelected: (tab) => setState(() => _tab = tab),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddEventSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add Event', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _GradientActionTile(
                      label: 'Workout',
                      subtitle: 'Schedule training',
                      icon: Icons.fitness_center,
                      gradient: AppTheme.indigoGradient,
                      onTap: () {
                        Navigator.pop(context);
                        this.context.push('/lift-planner');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GradientActionTile(
                      label: 'Meal',
                      subtitle: 'Log nutrition',
                      icon: Icons.restaurant,
                      gradient: AppTheme.brandGradient,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _tab = _MainTab.food);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSplitsSheet() {
    final appState = context.read<AppState>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _WorkoutSplitsSheet(
        splits: appState.workoutSplits,
        onSave: appState.saveWorkoutSplit,
        onDelete: appState.deleteWorkoutSplit,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String profileName;
  final bool isDemoMode;
  final VoidCallback onDemoTap;

  const _Header({
    required this.profileName,
    required this.isDemoMode,
    required this.onDemoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FuelWindow',
                  style: TextStyle(
                    color: Color(0xFF312E81),
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  profileName,
                  style: const TextStyle(
                    color: AppTheme.indigo,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isDemoMode)
            OutlinedButton(
              onPressed: onDemoTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.amber,
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppTheme.amber, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('DEMO'),
            ),
        ],
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  final AppState state;
  final MetabolicState metabolicState;
  final VoidCallback onPlanLift;
  final VoidCallback onLogFood;
  final VoidCallback onDetails;

  const _HomePage({
    required this.state,
    required this.metabolicState,
    required this.onPlanLift,
    required this.onLogFood,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MetabolicStateCard(state: metabolicState),
        const SizedBox(height: 12),
        MacroTotalsCard(state: metabolicState),
        const SizedBox(height: 12),
        _WorkoutCard(appState: state, onTap: onPlanLift),
        const SizedBox(height: 12),
        _FuelPrescriptionCard(
          appState: state,
          onLogFood: onLogFood,
          onDetails: onDetails,
        ),
      ],
    );
  }
}

class _MetabolicStateCard extends StatelessWidget {
  final MetabolicState state;

  const _MetabolicStateCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Metabolic State',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontSize: 20)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.bolt,
                  color: _phaseColor(state.bloodGlucosePhase.name)),
              const SizedBox(width: 8),
              Text(
                _phaseLabel(state.bloodGlucosePhase.name),
                style: TextStyle(
                  color: _phaseColor(state.bloodGlucosePhase.name),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _GlycogenBar(
                  label: 'Liver',
                  pct: state.liverFillPct,
                  grams: state.liverGlycogenG,
                  capacity: state.liverCapacityG,
                  color: AppTheme.teal,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _GlycogenBar(
                  label: 'Muscle',
                  pct: state.muscleFillPct,
                  grams: state.muscleGlycogenG,
                  capacity: state.muscleCapacityG,
                  color: AppTheme.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GlycogenChart(
            curve: state.curve,
            liverCapacity: state.liverCapacityG,
            muscleCapacity: state.muscleCapacityG,
          ),
          const GlycogenLegend(),
        ],
      ),
    );
  }

  String _phaseLabel(String name) => switch (name) {
        'fasted' => 'Fasted',
        'stable' => 'Stable',
        'postPrandial' => 'Post-meal',
        'elevated' => 'Elevated',
        _ => name,
      };

  Color _phaseColor(String name) => switch (name) {
        'fasted' => AppTheme.coral,
        'stable' => AppTheme.teal,
        'postPrandial' => AppTheme.amber,
        'elevated' => AppTheme.coral,
        _ => AppTheme.gray500,
      };
}

class _GlycogenBar extends StatelessWidget {
  final String label;
  final double pct;
  final double grams;
  final double capacity;
  final Color color;

  const _GlycogenBar({
    required this.label,
    required this.pct,
    required this.grams,
    required this.capacity,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppTheme.gray600, fontSize: 13)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            backgroundColor: AppTheme.gray200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${grams.round()}g / ${capacity.round()}g',
          style: const TextStyle(color: AppTheme.gray500, fontSize: 12),
        ),
      ],
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final AppState appState;
  final VoidCallback onTap;

  const _WorkoutCard({required this.appState, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final session = appState.nextSession;
    final title = session?.displayName ?? 'Plan a Lift';
    final subtitle = session == null
        ? 'Schedule a workout'
        : '${session.durationMinutes} min - ${session.intensity.name} intensity';
    final timeLabel =
        session == null ? '+' : _hoursUntil(session, appState.now);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AppCard(
        gradient: AppTheme.indigoGradient,
        borderColor: Colors.transparent,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(35),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.fitness_center,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFFC7D2FE), fontSize: 13)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (session != null)
                  const Text('away',
                      style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _hoursUntil(TrainingSession session, DateTime now) {
    final minutes = session.plannedAt.difference(now).inMinutes;
    if (minutes <= 0) return 'Now';
    if (minutes < 60) return '${minutes}m';
    return '${(minutes / 60).toStringAsFixed(1)}h';
  }
}

class _FuelPrescriptionCard extends StatelessWidget {
  final AppState appState;
  final VoidCallback onLogFood;
  final VoidCallback onDetails;

  const _FuelPrescriptionCard({
    required this.appState,
    required this.onLogFood,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final rx = appState.prescription;
    if (rx == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fuel Prescription',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Plan a lift to get a timed carbohydrate and protein target.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt, color: AppTheme.teal),
                        const SizedBox(width: 8),
                        Text('Fuel Prescription',
                            style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      rx.headline,
                      style: const TextStyle(
                        color: Color(0xFF312E81),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(rx.summary,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24),
                  borderRadius: BorderRadius.circular(16),
                ),
                child:
                    const Icon(Icons.fitness_center, color: Color(0xFF78350F)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AppPill(
                label: '${rx.targetCarbsG.round()}g carbs',
                color: AppTheme.teal,
              ),
              AppPill(
                label: '${rx.targetProteinG.round()}g protein',
                color: AppTheme.amber,
              ),
            ],
          ),
          const SizedBox(height: 16),
          GradientButton(
            onPressed: onLogFood,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Log Food'),
              ],
            ),
          ),
          TextButton(
            onPressed: onDetails,
            child: const Text('View details'),
          ),
        ],
      ),
    );
  }
}

class _FoodPage extends StatelessWidget {
  final AppState appState;
  final TextEditingController mealNameCtrl;
  final TextEditingController carbsCtrl;
  final TextEditingController proteinCtrl;
  final TextEditingController fatCtrl;
  final FocusNode mealFocus;
  final bool aiAutofill;
  final bool isAutofilling;
  final ValueChanged<bool> onAiChanged;
  final VoidCallback onAddMeal;
  final VoidCallback onAutofill;
  final ValueChanged<String> onMealChanged;
  final VoidCallback onScanLabel;

  const _FoodPage({
    required this.appState,
    required this.mealNameCtrl,
    required this.carbsCtrl,
    required this.proteinCtrl,
    required this.fatCtrl,
    required this.mealFocus,
    required this.aiAutofill,
    required this.isAutofilling,
    required this.onAiChanged,
    required this.onAddMeal,
    required this.onAutofill,
    required this.onMealChanged,
    required this.onScanLabel,
  });

  @override
  Widget build(BuildContext context) {
    final logs = appState.foodLogs.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Log Food', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        AppCard(
          gradient: const LinearGradient(
            colors: [Color(0xFFFAF5FF), Color(0xFFEEF2FF)],
          ),
          borderColor: const Color(0xFFE9D5FF),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.purple),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Autofill',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text('Automatically estimate macros',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              Switch(
                value: aiAutofill,
                activeTrackColor: AppTheme.purple,
                activeThumbColor: Colors.white,
                onChanged: onAiChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quick Add', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: mealNameCtrl,
                focusNode: mealFocus,
                decoration: const InputDecoration(
                  labelText: 'What did you eat?',
                  hintText: 'Chicken and rice, protein shake, oatmeal',
                ),
                onChanged: onMealChanged,
                onSubmitted: (_) => onAutofill(),
              ),
              if (aiAutofill && mealNameCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: AppTheme.purple, size: 14),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        AppConfig.hasRemoteFoodParser
                            ? 'AI estimates macros when you finish typing'
                            : 'Local estimate fills macros when you finish typing',
                        style: const TextStyle(
                            color: AppTheme.purple, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
              if (isAutofilling) ...[
                const SizedBox(height: 14),
                const Center(
                  child: Text('AI analyzing...',
                      style: TextStyle(color: AppTheme.purple)),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MacroInput(
                      label: 'Carbs (g)',
                      controller: carbsCtrl,
                      color: AppTheme.teal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MacroInput(
                      label: 'Protein (g)',
                      controller: proteinCtrl,
                      color: AppTheme.amber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MacroInput(
                      label: 'Fat (g)',
                      controller: fatCtrl,
                      color: AppTheme.coral,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onScanLabel,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Scan Label'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: AppTheme.indigo,
                        side: const BorderSide(color: AppTheme.indigoBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GradientButton(
                      onPressed: onAddMeal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      radius: 14,
                      child: const Text('Add Meal'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Today's Meals",
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              if (logs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No meals logged yet',
                        style: TextStyle(color: AppTheme.gray500)),
                  ),
                )
              else
                ...logs.map((log) => _MealTile(log: log)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MacroInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color color;

  const _MacroInput({
    required this.label,
    required this.controller,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelStyle: TextStyle(color: color),
      ),
    );
  }
}

class _MealTile extends StatelessWidget {
  final FoodLog log;

  const _MealTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final nutrition = log.nutrition;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.inputFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nutrition.foodName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                DateFormat('h:mm a').format(log.loggedAt),
                style: const TextStyle(color: AppTheme.gray500, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppPill(
                  label: '${nutrition.carbsG.round()}g C',
                  color: AppTheme.teal),
              AppPill(
                  label: '${nutrition.proteinG.round()}g P',
                  color: AppTheme.amber),
              AppPill(
                  label: '${nutrition.fatG.round()}g F', color: AppTheme.coral),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkoutPage extends StatelessWidget {
  final List<WorkoutSplit> splits;
  final List<_LoggedWorkout> loggedWorkouts;
  final TextEditingController workoutNameCtrl;
  final TextEditingController workoutDurationCtrl;
  final VoidCallback onPlan;
  final VoidCallback onLog;
  final VoidCallback onSplits;

  const _WorkoutPage({
    required this.splits,
    required this.loggedWorkouts,
    required this.workoutNameCtrl,
    required this.workoutDurationCtrl,
    required this.onPlan,
    required this.onLog,
    required this.onSplits,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Workouts', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _GradientActionTile(
                label: 'My Splits',
                subtitle: '${splits.length} custom splits',
                icon: Icons.fitness_center,
                gradient: AppTheme.indigoGradient,
                onTap: onSplits,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GradientActionTile(
                label: 'Plan Session',
                subtitle: 'Schedule a workout',
                icon: Icons.add,
                gradient: AppTheme.brandGradient,
                onTap: onPlan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quick Log', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              TextField(
                controller: workoutNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Workout Name',
                  hintText: 'Leg Day',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: workoutDurationCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (minutes)',
                  hintText: '60',
                ),
              ),
              const SizedBox(height: 16),
              GradientButton(
                onPressed: onLog,
                child: const Text('Log Workout'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recent Workouts',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              if (loggedWorkouts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No workouts logged yet',
                        style: TextStyle(color: AppTheme.gray500)),
                  ),
                )
              else
                ...loggedWorkouts.map(
                  (workout) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEEF2FF), Color(0xFFFAF5FF)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.indigoBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(workout.name,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(
                                '${workout.durationMinutes} min - ${workout.dateLabel}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle, color: AppTheme.teal),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkoutSplitsSheet extends StatefulWidget {
  final List<WorkoutSplit> splits;
  final ValueChanged<WorkoutSplit> onSave;
  final ValueChanged<String> onDelete;

  const _WorkoutSplitsSheet({
    required this.splits,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_WorkoutSplitsSheet> createState() => _WorkoutSplitsSheetState();
}

class _WorkoutSplitsSheetState extends State<_WorkoutSplitsSheet> {
  late List<WorkoutSplit> _splits;
  final _nameCtrl = TextEditingController();
  final _customExerciseCtrl = TextEditingController();
  final _customMusclesCtrl = TextEditingController();
  List<SplitExercise> _draftExercises = [];
  int? _editingIndex;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _splits = List.of(widget.splits);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _customExerciseCtrl.dispose();
    _customMusclesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.86,
          child: _isEditing ? _buildEditor(context) : _buildList(context),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Workout Splits',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _splits.isEmpty
                ? _EmptySplitsState(onCreate: _startNewSplit)
                : ListView(
                    children: [
                      ..._splits.asMap().entries.map(
                            (entry) => _SplitSummaryCard(
                              split: entry.value,
                              onEdit: () => _editSplit(entry.key),
                              onDelete: () => _deleteSplit(entry.key),
                            ),
                          ),
                      const SizedBox(height: 12),
                    ],
                  ),
          ),
          GradientButton(
            onPressed: _startNewSplit,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Create Custom Split'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _backToList,
                icon: const Icon(Icons.arrow_back, color: AppTheme.indigo),
              ),
              Expanded(
                child: Text(
                  _editingIndex == null ? 'Create Split' : 'Edit Split',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Split name',
                    hintText: 'Push Strength, Leg Hypertrophy, Upper Pull',
                  ),
                ),
                const SizedBox(height: 18),
                Text('Exercises',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                if (_draftExercises.isEmpty)
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Add exercises below to build your split.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  ..._draftExercises.asMap().entries.map(
                        (entry) => _EditableExerciseCard(
                          exercise: entry.value,
                          onChanged: (exercise) =>
                              _updateExercise(entry.key, exercise),
                          onDelete: () => _removeExercise(entry.key),
                        ),
                      ),
                const SizedBox(height: 18),
                Text('Add Exercise',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                ...exerciseTemplates.map(
                  (template) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: () => _addTemplateExercise(template),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.all(14),
                        foregroundColor: AppTheme.slate,
                        side: const BorderSide(color: AppTheme.indigoBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  template.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: template.muscles
                                      .map(
                                        (muscle) => AppPill(
                                          label: muscle,
                                          color: _muscleColor(muscle),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.add, color: AppTheme.teal),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Custom Exercise',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customExerciseCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Exercise name',
                          hintText: 'Bulgarian split squat',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _customMusclesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Muscles',
                          hintText: 'Quads, Glutes, Hamstrings',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _addCustomExercise,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Custom Exercise'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 90),
              ],
            ),
          ),
          GradientButton(
            onPressed: _saveSplit,
            child: const Text('Save Workout Split'),
          ),
        ],
      ),
    );
  }

  void _startNewSplit() {
    setState(() {
      _editingIndex = null;
      _nameCtrl.text = 'New Workout Split';
      _draftExercises = [];
      _customExerciseCtrl.clear();
      _customMusclesCtrl.clear();
      _isEditing = true;
    });
  }

  void _editSplit(int index) {
    final split = _splits[index];
    setState(() {
      _editingIndex = index;
      _nameCtrl.text = split.name;
      _draftExercises = List.of(split.exercises);
      _customExerciseCtrl.clear();
      _customMusclesCtrl.clear();
      _isEditing = true;
    });
  }

  void _backToList() {
    setState(() => _isEditing = false);
  }

  void _addTemplateExercise(ExerciseTemplate template) {
    setState(() {
      _draftExercises.add(
        SplitExercise(
          name: template.name,
          muscles: template.muscles,
          sets: template.defaultSets,
          reps: template.defaultReps,
        ),
      );
    });
  }

  void _addCustomExercise() {
    final name = _customExerciseCtrl.text.trim();
    if (name.isEmpty) return;

    final muscles = _customMusclesCtrl.text
        .split(',')
        .map((muscle) => muscle.trim())
        .where((muscle) => muscle.isNotEmpty)
        .toList();

    setState(() {
      _draftExercises.add(
        SplitExercise(
          name: name,
          muscles: muscles.isEmpty ? const ['Custom'] : muscles,
          sets: 3,
          reps: '8-12',
        ),
      );
      _customExerciseCtrl.clear();
      _customMusclesCtrl.clear();
    });
  }

  void _updateExercise(int index, SplitExercise exercise) {
    setState(() {
      _draftExercises[index] = exercise;
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _draftExercises.removeAt(index);
    });
  }

  void _deleteSplit(int index) {
    final id = _splits[index].id;
    setState(() {
      _splits.removeAt(index);
    });
    widget.onDelete(id);
  }

  void _saveSplit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _draftExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a split name and at least one exercise.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final split = WorkoutSplit(
      id: _editingIndex == null
          ? const Uuid().v4()
          : _splits[_editingIndex!].id,
      name: name,
      exercises: List.of(_draftExercises),
    );
    setState(() {
      final index = _editingIndex;
      if (index == null) {
        _splits.add(split);
      } else {
        _splits[index] = split;
      }
      _isEditing = false;
    });
    widget.onSave(split);
  }
}

class _EmptySplitsState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptySplitsState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE0E7FF), Color(0xFFF3E8FF)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.fitness_center,
                  color: AppTheme.indigo, size: 30),
            ),
            const SizedBox(height: 14),
            Text('No splits yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Create your own split with the exercises, sets, and reps you actually use.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create Custom Split'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitSummaryCard extends StatelessWidget {
  final WorkoutSplit split;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SplitSummaryCard({
    required this.split,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(split.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.teal),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: AppTheme.coral),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${split.exercises.length} exercises',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: split.muscles
                  .map(
                    (muscle) => AppPill(
                      label: muscle,
                      color: _muscleColor(muscle),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            ...split.exercises.take(4).map(
                  (exercise) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            exercise.name,
                            style: const TextStyle(color: AppTheme.gray700),
                          ),
                        ),
                        Text(
                          '${exercise.sets} x ${exercise.reps}',
                          style: const TextStyle(
                            color: AppTheme.gray500,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (split.exercises.length > 4)
              Text(
                '+${split.exercises.length - 4} more',
                style: const TextStyle(color: AppTheme.gray500, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditableExerciseCard extends StatelessWidget {
  final SplitExercise exercise;
  final ValueChanged<SplitExercise> onChanged;
  final VoidCallback onDelete;

  const _EditableExerciseCard({
    required this.exercise,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: exercise.muscles
                          .map(
                            (muscle) => AppPill(
                              label: muscle,
                              color: _muscleColor(muscle),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.close, color: AppTheme.coral),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text('Sets',
                        style: TextStyle(
                            color: AppTheme.gray600,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                      onPressed: exercise.sets <= 1
                          ? null
                          : () => onChanged(
                              exercise.copyWith(sets: exercise.sets - 1)),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '${exercise.sets}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      onPressed: () =>
                          onChanged(exercise.copyWith(sets: exercise.sets + 1)),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 110,
                child: TextFormField(
                  key: ValueKey(exercise.name),
                  initialValue: exercise.reps,
                  decoration: const InputDecoration(labelText: 'Reps'),
                  onChanged: (value) =>
                      onChanged(exercise.copyWith(reps: value)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarPage extends StatelessWidget {
  final AppState appState;
  final DateTime selectedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onPickDate;
  final VoidCallback onAddEvent;

  const _CalendarPage({
    required this.appState,
    required this.selectedDate,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onPickDate,
    required this.onAddEvent,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = _sameDay(selectedDate, appState.now);
    final events = _eventsFor(appState, selectedDate);

    return Column(
      children: [
        Row(
          children: [
            _IconBox(icon: Icons.chevron_left, onTap: onPrevious),
            Expanded(
              child: Column(
                children: [
                  Text(
                    DateFormat('EEEE').format(selectedDate),
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    DateFormat('MMMM d, y').format(selectedDate),
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (isToday)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: AppPill(label: 'Today', color: AppTheme.teal),
                    ),
                ],
              ),
            ),
            _IconBox(icon: Icons.chevron_right, onTap: onNext),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (!isToday)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: onToday,
                  child: const Text('Jump to Today'),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => _showMonthDialog(context),
              icon: const Icon(Icons.calendar_month, size: 18),
              label: const Text('Month View'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (events.isEmpty)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 44),
            child: Column(
              children: [
                const Text('No events scheduled for this day',
                    style: TextStyle(color: AppTheme.gray500)),
                const SizedBox(height: 18),
                GradientButton(
                  onPressed: onAddEvent,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Add Event'),
                    ],
                  ),
                ),
              ],
            ),
          )
        else ...[
          ...events.map(
            (event) => _CalendarEventCard(
              event: event,
              onEdit: () => _showEditEventSheet(context, event),
              onDelete: () => _deleteEvent(context, event),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onAddEvent,
            icon: const Icon(Icons.add),
            label: const Text('Add Event'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: AppTheme.indigoBorder, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _deleteEvent(BuildContext context, _CalendarEvent event) {
    if (event.foodLog != null) {
      appState.deleteFoodLog(event.foodLog!.id);
    } else if (event.session != null) {
      appState.deleteSession(event.session!.id);
    }
  }

  void _showEditEventSheet(BuildContext context, _CalendarEvent event) {
    if (event.foodLog != null) {
      _showEditMealSheet(context, event.foodLog!);
      return;
    }
    if (event.session != null) {
      _showEditWorkoutSheet(context, event.session!);
    }
  }

  void _showEditMealSheet(BuildContext context, FoodLog log) {
    final nameCtrl = TextEditingController(text: log.nutrition.foodName);
    final carbsCtrl =
        TextEditingController(text: log.nutrition.carbsG.round().toString());
    final proteinCtrl =
        TextEditingController(text: log.nutrition.proteinG.round().toString());
    final fatCtrl =
        TextEditingController(text: log.nutrition.fatG.round().toString());
    var time = TimeOfDay.fromDateTime(log.loggedAt);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Edit Meal',
                              style: Theme.of(context).textTheme.titleLarge),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Meal name'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MacroInput(
                            label: 'Carbs (g)',
                            controller: carbsCtrl,
                            color: AppTheme.teal,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MacroInput(
                            label: 'Protein (g)',
                            controller: proteinCtrl,
                            color: AppTheme.amber,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MacroInput(
                            label: 'Fat (g)',
                            controller: fatCtrl,
                            color: AppTheme.coral,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: sheetContext,
                          initialTime: time,
                        );
                        if (picked != null) {
                          setSheetState(() => time = picked);
                        }
                      },
                      icon: const Icon(Icons.access_time),
                      label: Text(time.format(sheetContext)),
                    ),
                    const SizedBox(height: 18),
                    GradientButton(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        final carbs =
                            double.tryParse(carbsCtrl.text.trim()) ?? 0;
                        final protein =
                            double.tryParse(proteinCtrl.text.trim()) ?? 0;
                        final fat = double.tryParse(fatCtrl.text.trim()) ?? 0;
                        if (name.isEmpty) return;

                        final loggedAt = DateTime(
                          log.loggedAt.year,
                          log.loggedAt.month,
                          log.loggedAt.day,
                          time.hour,
                          time.minute,
                        );
                        final nutrition = NutritionEstimate(
                          foodName: name,
                          grams: log.nutrition.grams,
                          carbsG: carbs,
                          glucoseG: carbs * 0.75,
                          fructoseG: carbs * 0.25,
                          fiberG: log.nutrition.fiberG,
                          proteinG: protein,
                          fatG: fat,
                          calories: carbs * 4 + protein * 4 + fat * 9,
                          micros: log.nutrition.micros,
                          isHighFat: fat >= 15,
                          isHighFiber: log.nutrition.isHighFiber,
                        );
                        appState.updateFoodLog(
                          log.copyWith(
                            rawInput: name,
                            loggedAt: loggedAt,
                            nutrition: nutrition,
                            source: 'manual',
                          ),
                        );
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('Save Meal'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      nameCtrl.dispose();
      carbsCtrl.dispose();
      proteinCtrl.dispose();
      fatCtrl.dispose();
    });
  }

  void _showEditWorkoutSheet(BuildContext context, TrainingSession session) {
    var isCustom = session.customSplitId != null;
    var selectedType = session.type;
    var selectedIntensity = session.intensity;
    var selectedSplit = isCustom
        ? _findWorkoutSplit(appState.workoutSplits, session.customSplitId)
        : null;
    var time = TimeOfDay.fromDateTime(session.plannedAt);
    final durationCtrl =
        TextEditingController(text: session.durationMinutes.toString());

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Edit Workout',
                                style: Theme.of(context).textTheme.titleLarge),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _CalendarModeButton(
                                    label: 'Quick Session',
                                    selected: !isCustom,
                                    onTap: () =>
                                        setSheetState(() => isCustom = false),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _CalendarModeButton(
                                    label: 'Custom Split',
                                    selected: isCustom,
                                    onTap: () {
                                      setSheetState(() {
                                        isCustom = true;
                                        selectedSplit ??=
                                            appState.workoutSplits.isEmpty
                                                ? null
                                                : appState.workoutSplits.first;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (isCustom)
                              _CalendarSplitPicker(
                                splits: appState.workoutSplits,
                                selected: selectedSplit,
                                onSelected: (split) =>
                                    setSheetState(() => selectedSplit = split),
                              )
                            else
                              _CalendarSessionTypePicker(
                                selected: selectedType,
                                onSelected: (type) =>
                                    setSheetState(() => selectedType = type),
                              ),
                            const SizedBox(height: 16),
                            _CalendarIntensityPicker(
                              selected: selectedIntensity,
                              onSelected: (intensity) => setSheetState(
                                () => selectedIntensity = intensity,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: durationCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duration (minutes)',
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: sheetContext,
                                  initialTime: time,
                                );
                                if (picked != null) {
                                  setSheetState(() => time = picked);
                                }
                              },
                              icon: const Icon(Icons.access_time),
                              label: Text(time.format(sheetContext)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      GradientButton(
                        onPressed: () {
                          if (isCustom && selectedSplit == null) return;
                          final plannedAt = DateTime(
                            session.plannedAt.year,
                            session.plannedAt.month,
                            session.plannedAt.day,
                            time.hour,
                            time.minute,
                          );
                          final duration =
                              int.tryParse(durationCtrl.text.trim()) ??
                                  session.durationMinutes;
                          appState.updateSession(
                            TrainingSession(
                              id: session.id,
                              userId: session.userId,
                              type: isCustom
                                  ? SessionType.fullBody
                                  : selectedType,
                              plannedAt: plannedAt,
                              durationMinutes: duration,
                              intensity: selectedIntensity,
                              notes: isCustom
                                  ? '${selectedSplit!.exercises.length} custom exercises'
                                  : session.notes,
                              customName: isCustom ? selectedSplit!.name : null,
                              customSplitId:
                                  isCustom ? selectedSplit!.id : null,
                            ),
                          );
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('Save Workout'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(durationCtrl.dispose);
  }

  void _showMonthDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final days = _monthDays(selectedDate);
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('MMMM y').format(selectedDate),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 7,
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [
                    _WeekdayLabel('Sun'),
                    _WeekdayLabel('Mon'),
                    _WeekdayLabel('Tue'),
                    _WeekdayLabel('Wed'),
                    _WeekdayLabel('Thu'),
                    _WeekdayLabel('Fri'),
                    _WeekdayLabel('Sat'),
                  ],
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final currentMonth = day.month == selectedDate.month;
                    final selected = _sameDay(day, selectedDate);
                    final today = _sameDay(day, appState.now);
                    final hasEvents = _eventsFor(appState, day).isNotEmpty;
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        onPickDate(day);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: selected ? AppTheme.indigoGradient : null,
                          color: selected
                              ? null
                              : today
                                  ? const Color(0xFFD1FAE5)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : currentMonth
                                        ? AppTheme.slate
                                        : AppTheme.gray500.withAlpha(120),
                                fontSize: 13,
                                fontWeight: today || selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            if (hasEvents)
                              Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(
                                  color:
                                      selected ? Colors.white : AppTheme.indigo,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<DateTime> _monthDays(DateTime date) {
    final first = DateTime(date.year, date.month);
    final start = first.subtract(Duration(days: first.weekday % 7));
    return List.generate(42, (index) => start.add(Duration(days: index)));
  }
}

class _SettingsPage extends StatelessWidget {
  final AppState appState;
  final VoidCallback onEditProfile;
  final VoidCallback onReset;

  const _SettingsPage({
    required this.appState,
    required this.onEditProfile,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final profile = appState.profile!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              _SettingsTile(
                title: 'Edit Biometrics',
                subtitle:
                    '${profile.ageYears} years, ${profile.heightCm.round()} cm, ${profile.weightKg.round()} kg',
                onTap: onEditProfile,
              ),
              _SettingsTile(
                title: 'Activity & Preferences',
                subtitle: _activityLabel(profile.activityBaseline),
                onTap: onEditProfile,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('About', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('FuelWindow v1.0',
                  style: TextStyle(color: AppTheme.gray600)),
              const SizedBox(height: 4),
              const Text(
                'Fuel your lifts with informed physiology estimates.',
                style: TextStyle(color: AppTheme.gray500, fontSize: 12),
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: onReset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.coral,
                  side: BorderSide(color: AppTheme.coral.withAlpha(120)),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Switch Profile'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _activityLabel(ActivityBaseline activity) => switch (activity) {
        ActivityBaseline.sedentary => 'Sedentary activity level',
        ActivityBaseline.lightlyActive => 'Lightly active',
        ActivityBaseline.moderatelyActive => 'Moderately active',
        ActivityBaseline.veryActive => 'Very active',
        ActivityBaseline.extraActive => 'Extra active',
      };
}

class _BottomNav extends StatelessWidget {
  final _MainTab current;
  final ValueChanged<_MainTab> onSelected;

  const _BottomNav({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.indigoBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            tab: _MainTab.home,
            current: current,
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Home',
            onSelected: onSelected,
          ),
          _NavItem(
            tab: _MainTab.food,
            current: current,
            icon: Icons.restaurant_outlined,
            activeIcon: Icons.restaurant,
            label: 'Food',
            onSelected: onSelected,
          ),
          _NavItem(
            tab: _MainTab.workout,
            current: current,
            icon: Icons.monitor_heart_outlined,
            activeIcon: Icons.monitor_heart,
            label: 'Workout',
            onSelected: onSelected,
          ),
          _NavItem(
            tab: _MainTab.calendar,
            current: current,
            icon: Icons.calendar_month_outlined,
            activeIcon: Icons.calendar_month,
            label: 'Calendar',
            onSelected: onSelected,
          ),
          _NavItem(
            tab: _MainTab.settings,
            current: current,
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: 'Settings',
            onSelected: onSelected,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _MainTab tab;
  final _MainTab current;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<_MainTab> onSelected;

  const _NavItem({
    required this.tab,
    required this.current,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selected = tab == current;
    final color = selected ? AppTheme.teal : AppTheme.gray500;
    return Expanded(
      child: InkWell(
        onTap: () => onSelected(tab),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? activeIcon : icon, color: color),
              const SizedBox(height: 2),
              FittedBox(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientActionTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _GradientActionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarEventCard extends StatelessWidget {
  final _CalendarEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CalendarEventCard({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        borderColor: event.color.withAlpha(80),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: event.gradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(event.icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.name,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(event.time,
                      style: Theme.of(context).textTheme.bodyMedium),
                  if (event.pills.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: event.pills
                          .map((pill) =>
                              AppPill(label: pill.label, color: pill.color))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.teal),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: AppTheme.coral),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CalendarModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFECFDF5) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.emerald : AppTheme.gray200,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? AppTheme.tealDark : AppTheme.gray600,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CalendarSessionTypePicker extends StatelessWidget {
  final SessionType selected;
  final ValueChanged<SessionType> onSelected;

  const _CalendarSessionTypePicker({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SessionType.values.map((type) {
        final session = TrainingSession(
          id: '',
          userId: '',
          type: type,
          plannedAt: DateTime.now(),
          durationMinutes: 60,
          intensity: SessionIntensity.moderate,
        );
        final active = selected == type;
        return ChoiceChip(
          label: Text(session.displayName),
          selected: active,
          selectedColor: const Color(0xFFECFDF5),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: active ? AppTheme.emerald : AppTheme.gray200,
            width: 1.5,
          ),
          labelStyle: TextStyle(
            color: active ? AppTheme.tealDark : AppTheme.gray700,
            fontWeight: FontWeight.w700,
          ),
          onSelected: (_) => onSelected(type),
        );
      }).toList(),
    );
  }
}

class _CalendarIntensityPicker extends StatelessWidget {
  final SessionIntensity selected;
  final ValueChanged<SessionIntensity> onSelected;

  const _CalendarIntensityPicker({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SessionIntensity.values.map((intensity) {
        final active = selected == intensity;
        return ChoiceChip(
          label: Text(
            intensity.name[0].toUpperCase() + intensity.name.substring(1),
          ),
          selected: active,
          selectedColor: const Color(0xFFECFDF5),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: active ? AppTheme.emerald : AppTheme.gray200,
            width: 1.5,
          ),
          labelStyle: TextStyle(
            color: active ? AppTheme.tealDark : AppTheme.gray700,
            fontWeight: FontWeight.w700,
          ),
          onSelected: (_) => onSelected(intensity),
        );
      }).toList(),
    );
  }
}

class _CalendarSplitPicker extends StatelessWidget {
  final List<WorkoutSplit> splits;
  final WorkoutSplit? selected;
  final ValueChanged<WorkoutSplit> onSelected;

  const _CalendarSplitPicker({
    required this.splits,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (splits.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(18),
        child: Text(
          'No custom splits yet. Create one from Workouts > My Splits.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      children: splits.map((split) {
        final active = selected?.id == split.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => onSelected(split),
            borderRadius: BorderRadius.circular(18),
            child: AppCard(
              color: active ? const Color(0xFFECFDF5) : Colors.white,
              borderColor: active ? AppTheme.emerald : AppTheme.indigoBorder,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(split.name,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 3),
                        Text('${split.exercises.length} exercises',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  Icon(
                    active
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: active ? AppTheme.teal : AppTheme.gray500,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.inputFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.gray500),
          ],
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBox({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.indigoBorder, width: 1.5),
        ),
        child: Icon(icon, color: AppTheme.indigo),
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;

  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.gray600,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LoggedWorkout {
  final String name;
  final int durationMinutes;
  final String dateLabel;

  const _LoggedWorkout({
    required this.name,
    required this.durationMinutes,
    required this.dateLabel,
  });
}

class _CalendarEvent {
  final String name;
  final String time;
  final IconData icon;
  final Color color;
  final Gradient gradient;
  final List<_EventPill> pills;
  final FoodLog? foodLog;
  final TrainingSession? session;

  const _CalendarEvent({
    required this.name,
    required this.time,
    required this.icon,
    required this.color,
    required this.gradient,
    this.pills = const [],
    this.foodLog,
    this.session,
  });
}

class _EventPill {
  final String label;
  final Color color;

  const _EventPill(this.label, this.color);
}

List<_CalendarEvent> _eventsFor(AppState state, DateTime date) {
  final sessionEvents =
      state.sessions.where((session) => _sameDay(session.plannedAt, date)).map(
            (session) => _CalendarEvent(
              name: session.displayName,
              time: DateFormat('h:mm a').format(session.plannedAt),
              icon: Icons.fitness_center,
              color: AppTheme.indigo,
              gradient: AppTheme.indigoGradient,
              session: session,
            ),
          );

  final foodEvents = state.foodLogs
      .where((log) => _sameDay(log.loggedAt, date))
      .map(
        (log) => _CalendarEvent(
          name: log.nutrition.foodName,
          time: DateFormat('h:mm a').format(log.loggedAt),
          icon: Icons.restaurant,
          color: AppTheme.teal,
          gradient: AppTheme.brandGradient,
          foodLog: log,
          pills: [
            _EventPill('${log.nutrition.carbsG.round()}g Carbs', AppTheme.teal),
            _EventPill(
                '${log.nutrition.proteinG.round()}g Protein', AppTheme.amber),
            _EventPill('${log.nutrition.fatG.round()}g Fat', AppTheme.coral),
          ],
        ),
      );

  final all = [...sessionEvents, ...foodEvents];
  all.sort((a, b) => a.time.compareTo(b.time));
  return all;
}

WorkoutSplit? _findWorkoutSplit(List<WorkoutSplit> splits, String? id) {
  if (id == null) return null;
  for (final split in splits) {
    if (split.id == id) return split;
  }
  return null;
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

Color _muscleColor(String muscle) => switch (muscle) {
      'Chest' => const Color(0xFFDC2626),
      'Triceps' => const Color(0xFFEA580C),
      'Front Delts' => const Color(0xFFD97706),
      'Quads' => const Color(0xFF2563EB),
      'Glutes' => const Color(0xFF7C3AED),
      'Hamstrings' => const Color(0xFFDB2777),
      'Core' => const Color(0xFFCA8A04),
      'Back' => const Color(0xFF16A34A),
      'Biceps' => const Color(0xFF0D9488),
      'Rear Delts' => const Color(0xFF0891B2),
      'Custom' => AppTheme.gray600,
      _ => AppTheme.indigo,
    };
