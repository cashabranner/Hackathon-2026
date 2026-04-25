import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/training_session.dart';
import '../../repositories/app_state.dart';
import '../../theme/app_theme.dart';

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

  void _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppTheme.teal),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppTheme.teal),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final plannedAt = DateTime(
        _date.year, _date.month, _date.day, _time.hour, _time.minute);
    final session = TrainingSession(
      id: const Uuid().v4(),
      userId: context.read<AppState>().profile?.id ?? 'local',
      type: _type,
      plannedAt: plannedAt,
      durationMinutes: _durationMin,
      intensity: _intensity,
    );
    context.read<AppState>().addSession(session);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${session.displayName} planned ✓'),
        backgroundColor: AppTheme.teal,
        duration: const Duration(seconds: 2),
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final upcoming = appState.sessions
        .where((s) => s.plannedAt.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.plannedAt.compareTo(b.plannedAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan a Lift'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel('Session Type'),
            const SizedBox(height: 10),
            _SessionTypePicker(
                selected: _type,
                onSelected: (t) => setState(() => _type = t)),
            const SizedBox(height: 20),
            _SectionLabel('Intensity'),
            const SizedBox(height: 10),
            _IntensityPicker(
                selected: _intensity,
                onSelected: (i) => setState(() => _intensity = i)),
            const SizedBox(height: 20),
            _SectionLabel('Duration: $_durationMin min'),
            Slider(
              value: _durationMin.toDouble(),
              min: 15,
              max: 120,
              divisions: 21,
              label: '$_durationMin min',
              activeColor: AppTheme.teal,
              onChanged: (v) => setState(() => _durationMin = v.round()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TapTile(
                    icon: Icons.calendar_today,
                    label: 'Date',
                    value:
                        '${_date.day}/${_date.month}/${_date.year}',
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
            const SizedBox(height: 8),
            _CostEstimateRow(type: _type, intensity: _intensity, durationMin: _durationMin),
            const SizedBox(height: 28),
            FilledButton(onPressed: _save, child: const Text('Save Session')),
            if (upcoming.isNotEmpty) ...[
              const SizedBox(height: 28),
              _SectionLabel('Planned Sessions'),
              const SizedBox(height: 10),
              ...upcoming.map((s) => _UpcomingSessionTile(
                    session: s,
                    appState: appState,
                  )),
            ],
            const SizedBox(height: 60),
          ],
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
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: Colors.white70));
  }
}

class _SessionTypePicker extends StatelessWidget {
  final SessionType selected;
  final void Function(SessionType) onSelected;
  const _SessionTypePicker({required this.selected, required this.onSelected});

  static const _icons = {
    SessionType.legs: Icons.directions_walk,
    SessionType.upperPush: Icons.fitness_center,
    SessionType.upperPull: Icons.sports_gymnastics,
    SessionType.fullBody: Icons.sports,
    SessionType.hiit: Icons.bolt,
    SessionType.steadyStateCardio: Icons.directions_run,
    SessionType.mobility: Icons.self_improvement,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: SessionType.values.map((t) {
        final isSelected = t == selected;
        final session = TrainingSession(
          id: '',
          userId: '',
          type: t,
          plannedAt: DateTime.now(),
          durationMinutes: 60,
          intensity: SessionIntensity.moderate,
        );
        return GestureDetector(
          onTap: () => onSelected(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.teal.withAlpha(40)
                  : AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppTheme.teal : Colors.white12,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _icons[t] ?? Icons.fitness_center,
                  size: 16,
                  color: isSelected ? AppTheme.teal : Colors.white54,
                ),
                const SizedBox(width: 6),
                Text(session.displayName,
                    style: TextStyle(
                      color: isSelected ? AppTheme.teal : Colors.white70,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _IntensityPicker extends StatelessWidget {
  final SessionIntensity selected;
  final void Function(SessionIntensity) onSelected;
  const _IntensityPicker(
      {required this.selected, required this.onSelected});

  static const _colors = {
    SessionIntensity.low: Colors.green,
    SessionIntensity.moderate: AppTheme.teal,
    SessionIntensity.high: AppTheme.amber,
    SessionIntensity.maximal: AppTheme.coral,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: SessionIntensity.values.map((i) {
        final isSelected = i == selected;
        final color = _colors[i]!;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withAlpha(40)
                    : AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? color : Colors.white12,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    i.name[0].toUpperCase() + i.name.substring(1),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? color : Colors.white54,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
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

class _TapTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _TapTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.teal, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                Text(value,
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CostEstimateRow extends StatelessWidget {
  final SessionType type;
  final SessionIntensity intensity;
  final int durationMin;
  const _CostEstimateRow(
      {required this.type, required this.intensity, required this.durationMin});

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
    final cost = session.estimatedMuscleGlycogenCostG;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.amber.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.amber.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department,
              color: AppTheme.amber, size: 16),
          const SizedBox(width: 8),
          Text(
            'Est. glycogen cost: ~${cost.round()}g muscle glycogen',
            style: const TextStyle(color: AppTheme.amber, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _UpcomingSessionTile extends StatelessWidget {
  final TrainingSession session;
  final AppState appState;
  const _UpcomingSessionTile(
      {required this.session, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.teal.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child:
            const Icon(Icons.fitness_center, color: AppTheme.teal, size: 20),
      ),
      title: Text(session.displayName),
      subtitle: Text(
          '${session.durationMinutes} min · ${session.intensity.name}'),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
        onPressed: () => appState.deleteSession(session.id),
      ),
    );
  }
}
