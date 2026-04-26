import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/training_session.dart';
import '../../models/workout_split.dart';
import '../../repositories/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

class LiftPlannerScreen extends StatefulWidget {
  const LiftPlannerScreen({super.key});

  @override
  State<LiftPlannerScreen> createState() => _LiftPlannerScreenState();
}

class _LiftPlannerScreenState extends State<LiftPlannerScreen> {
  SessionType _type = SessionType.legs;
  SessionIntensity _intensity = SessionIntensity.moderate;
  int _durationMin = 60;
  TimeOfDay _time = const TimeOfDay(hour: 17, minute: 0);
  DateTime _date = DateTime.now();
  bool _customSplitMode = false;
  WorkoutSplit? _selectedSplit;
  bool _repeatWeekly = false;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final selectedSplit = _selectedSplit;
    if (_customSplitMode && selectedSplit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select or create a workout routine first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final plannedAt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    if (_customSplitMode && _repeatWeekly) {
      context.read<AppState>().saveWeeklyWorkoutAssignment(
            WeeklyWorkoutAssignment(
              id: const Uuid().v4(),
              routineId: selectedSplit!.id,
              weekday: plannedAt.weekday,
              minuteOfDay: _time.hour * 60 + _time.minute,
              durationMinutes: _durationMin,
              intensity: _intensity,
            ),
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedSplit.name} added to your weekly calendar.'),
          backgroundColor: AppTheme.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/dashboard');
      }
      return;
    }
    final session = TrainingSession(
      id: const Uuid().v4(),
      userId: context.read<AppState>().profile?.id ?? 'local',
      type: _customSplitMode ? SessionType.fullBody : _type,
      plannedAt: plannedAt,
      durationMinutes: _durationMin,
      intensity: _intensity,
      customName: _customSplitMode ? selectedSplit!.name : null,
      customSplitId: _customSplitMode ? selectedSplit!.id : null,
      plannedExercises:
          _customSplitMode ? List.of(selectedSplit!.exercises) : const [],
      notes: _customSplitMode
          ? '${selectedSplit!.exercises.length} routine exercises'
          : null,
    );
    context.read<AppState>().addSession(session);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${session.displayName} planned.'),
        backgroundColor: AppTheme.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final splits = appState.workoutSplits;
    if (_selectedSplit != null &&
        !splits.any((split) => split.id == _selectedSplit!.id)) {
      _selectedSplit = null;
    }
    final upcoming = appState.sessions
        .where((session) => session.plannedAt.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.plannedAt.compareTo(b.plannedAt));

    return Scaffold(
      body: GradientShell(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  _TopBar(
                    title: 'Plan a Lift',
                    onBack: () => context.canPop()
                        ? context.pop()
                        : context.go('/dashboard'),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _ModeButton(
                                label: 'Quick Session',
                                selected: !_customSplitMode,
                                onTap: () => setState(() {
                                  _customSplitMode = false;
                                  _selectedSplit = null;
                                }),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ModeButton(
                                label: 'Workout Routine',
                                selected: _customSplitMode,
                                onTap: () => setState(() {
                                  _customSplitMode = true;
                                  if (_selectedSplit == null &&
                                      splits.isNotEmpty) {
                                    _selectedSplit = splits.first;
                                  }
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (_customSplitMode)
                          _CustomSplitPicker(
                            splits: splits,
                            selected: _selectedSplit,
                            onSelected: (split) =>
                                setState(() => _selectedSplit = split),
                          )
                        else ...[
                          _SectionLabel('Session Type'),
                          const SizedBox(height: 12),
                          _SessionTypeGrid(
                            selected: _type,
                            onSelected: (type) => setState(() => _type = type),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _SectionLabel('Intensity'),
                        const SizedBox(height: 12),
                        _IntensityGrid(
                          selected: _intensity,
                          onSelected: (value) =>
                              setState(() => _intensity = value),
                        ),
                        const SizedBox(height: 24),
                        _SectionLabel('Duration: $_durationMin min'),
                        Slider(
                          value: _durationMin.toDouble(),
                          min: 15,
                          max: 180,
                          divisions: 11,
                          label: '$_durationMin min',
                          onChanged: (value) =>
                              setState(() => _durationMin = value.round()),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _TapTile(
                                icon: Icons.calendar_today_outlined,
                                label: 'Date',
                                value: DateFormat('d/M/y').format(_date),
                                onTap: _pickDate,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TapTile(
                                icon: Icons.access_time,
                                label: 'Time',
                                value: _time.format(context),
                                onTap: _pickTime,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _CostEstimate(
                          type: _customSplitMode ? SessionType.fullBody : _type,
                          intensity: _intensity,
                          durationMin: _durationMin,
                          split: _customSplitMode ? _selectedSplit : null,
                        ),
                        if (_customSplitMode) ...[
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            value: _repeatWeekly,
                            onChanged: (value) => setState(
                              () => _repeatWeekly = value ?? false,
                            ),
                            title: const Text('Repeat weekly'),
                            subtitle: const Text(
                              'Adds this routine to the weekly calendar.',
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        GradientButton(
                          onPressed: _save,
                          child: const Text('Save Session'),
                        ),
                        if (upcoming.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          _SectionLabel('Planned Sessions'),
                          const SizedBox(height: 12),
                          ...upcoming.map(
                            (session) => _UpcomingSessionTile(
                              session: session,
                              appState: appState,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _TopBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 20),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: AppTheme.indigo),
          ),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFECFDF5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
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

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.gray700,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SessionTypeGrid extends StatelessWidget {
  final SessionType selected;
  final ValueChanged<SessionType> onSelected;

  const _SessionTypeGrid({required this.selected, required this.onSelected});

  static const _icons = {
    SessionType.legs: Icons.directions_walk,
    SessionType.upperPush: Icons.fitness_center,
    SessionType.upperPull: Icons.sports_gymnastics,
    SessionType.fullBody: Icons.directions_run,
    SessionType.hiit: Icons.bolt,
    SessionType.steadyStateCardio: Icons.favorite,
    SessionType.mobility: Icons.self_improvement,
  };

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.15,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
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
        return InkWell(
          onTap: () => onSelected(type),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFECFDF5) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active ? AppTheme.emerald : AppTheme.gray200,
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _icons[type] ?? Icons.fitness_center,
                  color: active ? AppTheme.teal : AppTheme.indigo,
                  size: 25,
                ),
                const SizedBox(height: 7),
                Text(
                  session.displayName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? AppTheme.tealDark : AppTheme.gray700,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _IntensityGrid extends StatelessWidget {
  final SessionIntensity selected;
  final ValueChanged<SessionIntensity> onSelected;

  const _IntensityGrid({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: SessionIntensity.values.map((intensity) {
        final active = selected == intensity;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => onSelected(intensity),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFECFDF5) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active ? AppTheme.emerald : AppTheme.gray200,
                    width: 1.5,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    intensity.name[0].toUpperCase() +
                        intensity.name.substring(1),
                    style: TextStyle(
                      color: active ? AppTheme.tealDark : AppTheme.gray700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CustomSplitPicker extends StatelessWidget {
  final List<WorkoutSplit> splits;
  final WorkoutSplit? selected;
  final ValueChanged<WorkoutSplit> onSelected;

  const _CustomSplitPicker({
    required this.splits,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (splits.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.fitness_center, color: AppTheme.indigo, size: 36),
            const SizedBox(height: 12),
            Text(
              'No workout routines yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Create one from Workouts > My Routines, then return here to schedule it.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Select Your Routine'),
        const SizedBox(height: 12),
        ...splits.map((split) {
          final active = selected?.id == split.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => onSelected(split),
              borderRadius: BorderRadius.circular(22),
              child: AppCard(
                color: active ? const Color(0xFFECFDF5) : Colors.white,
                borderColor: active ? AppTheme.emerald : AppTheme.indigoBorder,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            split.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: active ? AppTheme.teal : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: active ? AppTheme.teal : AppTheme.gray200,
                              width: 2,
                            ),
                          ),
                          child: active
                              ? Center(
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${split.exercises.length} exercises',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    ...split.exercises.take(4).map(
                          (exercise) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    exercise.name,
                                    style: const TextStyle(
                                      color: AppTheme.gray700,
                                    ),
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
                    if (split.muscles.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: split.muscles
                            .take(8)
                            .map(
                              (muscle) => AppPill(
                                label: muscle,
                                color: _muscleColor(muscle),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _TapTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TapTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.teal, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(color: AppTheme.gray600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

class _CostEstimate extends StatelessWidget {
  final SessionType type;
  final SessionIntensity intensity;
  final int durationMin;
  final WorkoutSplit? split;

  const _CostEstimate({
    required this.type,
    required this.intensity,
    required this.durationMin,
    this.split,
  });

  @override
  Widget build(BuildContext context) {
    final session = TrainingSession(
      id: '',
      userId: '',
      type: type,
      plannedAt: DateTime.now(),
      durationMinutes: durationMin,
      intensity: intensity,
    );
    final splitCost = split?.exercises.fold<double>(
      0,
      (sum, exercise) => sum + exercise.sets * _muscleCost(exercise),
    );
    final cost = splitCost ?? session.estimatedMuscleGlycogenCostG;

    return AppCard(
      color: const Color(0xFFFFFBEB),
      borderColor: const Color(0xFFFCD34D),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department, color: AppTheme.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Est. glycogen cost: ~${cost.round()}g muscle glycogen',
              style: const TextStyle(
                color: Color(0xFFB45309),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _muscleCost(SplitExercise exercise) {
    final muscles = exercise.muscles;
    if (muscles.any((m) => m == 'Glutes' || m == 'Quads')) return 25;
    if (muscles.any((m) => m == 'Back' || m == 'Chest')) return 15;
    return 10;
  }
}

class _UpcomingSessionTile extends StatelessWidget {
  final TrainingSession session;
  final AppState appState;

  const _UpcomingSessionTile({required this.session, required this.appState});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppTheme.indigoGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.fitness_center, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${DateFormat('MMM d, h:mm a').format(session.plannedAt)} - ${session.durationMinutes} min',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => appState.deleteSession(session.id),
            icon: const Icon(Icons.delete_outline, color: AppTheme.coral),
          ),
        ],
      ),
    );
  }
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
