import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/metabolic_state.dart';
import '../../repositories/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glycogen_chart.dart';
import '../../widgets/macro_totals_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final ms = state.metabolicState;
    final profile = state.profile;

    if (profile == null || ms == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FuelWindow',
                style: const TextStyle(
                    color: AppTheme.teal,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            Text(profile.name,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        actions: [
          if (state.isDemoMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('DEMO',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                backgroundColor: AppTheme.amber.withAlpha(40),
                labelStyle: const TextStyle(color: AppTheme.amber),
                side: const BorderSide(color: AppTheme.amber, width: 1),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/onboarding'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          children: [
            _GlycogenPanel(state: ms),
            const SizedBox(height: 4),
            MacroTotalsCard(state: ms),
            const SizedBox(height: 4),
            _SessionCard(appState: state),
            const SizedBox(height: 4),
            if (state.prescription != null) _PrescriptionPreview(appState: state),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: _DashboardFAB(appState: state),
    );
  }
}

// ─── Glycogen panel ──────────────────────────────────────────────────────────

class _GlycogenPanel extends StatelessWidget {
  final MetabolicState state;
  const _GlycogenPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final ms = state;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Metabolic State',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              _phaseLabel(ms.bloodGlucosePhase.name),
              style: TextStyle(
                  color: _phaseColor(ms.bloodGlucosePhase.name),
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: _GlycogenBar(
                  label: 'Liver',
                  pct: ms.liverFillPct,
                  grams: ms.liverGlycogenG,
                  capacity: ms.liverCapacityG,
                  color: AppTheme.teal,
                  isLow: ms.isLiverLow,
                )),
                const SizedBox(width: 16),
                Expanded(
                    child: _GlycogenBar(
                  label: 'Muscle',
                  pct: ms.muscleFillPct,
                  grams: ms.muscleGlycogenG,
                  capacity: ms.muscleCapacityG,
                  color: AppTheme.amber,
                  isLow: ms.isMuscleLow,
                )),
              ],
            ),
            const SizedBox(height: 16),
            GlycogenChart(
              curve: ms.curve,
              liverCapacity: ms.liverCapacityG,
              muscleCapacity: ms.muscleCapacityG,
            ),
            const SizedBox(height: 8),
            const GlycogenLegend(),
          ],
        ),
      ),
    );
  }

  String _phaseLabel(String name) => switch (name) {
        'fasted' => '⚡ Fasted',
        'stable' => '✅ Stable',
        'postPrandial' => '📈 Post-meal (rising)',
        'elevated' => '⚠️ Elevated',
        _ => name,
      };

  Color _phaseColor(String name) => switch (name) {
        'fasted' => AppTheme.coral,
        'stable' => AppTheme.teal,
        'postPrandial' => AppTheme.amber,
        'elevated' => AppTheme.coral,
        _ => Colors.white54,
      };
}

class _GlycogenBar extends StatelessWidget {
  final String label;
  final double pct;
  final double grams;
  final double capacity;
  final Color color;
  final bool isLow;

  const _GlycogenBar({
    required this.label,
    required this.pct,
    required this.grams,
    required this.capacity,
    required this.color,
    required this.isLow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12)),
            if (isLow)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.coral.withAlpha(40),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('LOW',
                    style: TextStyle(
                        color: AppTheme.coral,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: AppTheme.surfaceCard,
            valueColor: AlwaysStoppedAnimation(isLow ? AppTheme.coral : color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${grams.round()}g / ${capacity.round()}g',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}

// ─── Session card ────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final AppState appState;
  const _SessionCard({required this.appState});

  @override
  Widget build(BuildContext context) {
    final session = appState.nextSession;
    if (session == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.fitness_center, color: AppTheme.teal),
          title: const Text('No upcoming session'),
          subtitle: const Text('Tap + to plan a lift'),
          trailing: IconButton(
            icon: const Icon(Icons.add, color: AppTheme.teal),
            onPressed: () => context.push('/lift-planner'),
          ),
        ),
      );
    }

    final hours = session.plannedAt.difference(appState.now).inMinutes / 60;
    final hoursLabel = hours < 0
        ? 'In progress'
        : hours < 1
            ? '${(hours * 60).round()} min'
            : '${hours.toStringAsFixed(1)}h';

    return Card(
      child: InkWell(
        onTap: () => context.push('/lift-planner'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.teal.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fitness_center,
                    color: AppTheme.teal, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.displayName,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                        '${session.durationMinutes} min · ${session.intensity.name} intensity',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(hoursLabel,
                      style: const TextStyle(
                          color: AppTheme.teal,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  const Text('away',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Prescription preview ─────────────────────────────────────────────────────

class _PrescriptionPreview extends StatelessWidget {
  final AppState appState;
  const _PrescriptionPreview({required this.appState});

  @override
  Widget build(BuildContext context) {
    final rx = appState.prescription!;
    return Card(
      child: InkWell(
        onTap: () => context.push('/prescription'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, color: AppTheme.teal, size: 18),
                  const SizedBox(width: 6),
                  Text('Fuel Prescription',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (rx.urgentRefuel)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.coral.withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('URGENT',
                          style: TextStyle(
                              color: AppTheme.coral,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(rx.headline,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(rx.summary,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatChip('${rx.targetCarbsG.round()}g carbs',
                      AppTheme.teal),
                  const SizedBox(width: 8),
                  _StatChip('${rx.targetProteinG.round()}g protein',
                      AppTheme.amber),
                  const Spacer(),
                  const Text('View details →',
                      style:
                          TextStyle(color: AppTheme.teal, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── FAB ──────────────────────────────────────────────────────────────────────

class _DashboardFAB extends StatelessWidget {
  final AppState appState;
  const _DashboardFAB({required this.appState});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'fab-plan',
          backgroundColor: AppTheme.amber,
          onPressed: () => context.push('/lift-planner'),
          child: const Icon(Icons.fitness_center, color: AppTheme.slate),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.extended(
          heroTag: 'fab-log',
          backgroundColor: AppTheme.teal,
          onPressed: () => context.push('/food-log'),
          icon: const Icon(Icons.add, color: AppTheme.slate),
          label: const Text('Log Food',
              style: TextStyle(color: AppTheme.slate, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
