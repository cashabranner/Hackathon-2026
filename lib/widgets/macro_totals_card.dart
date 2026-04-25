import 'package:flutter/material.dart';

import '../models/metabolic_state.dart';
import '../theme/app_theme.dart';

class MacroTotalsCard extends StatelessWidget {
  final MetabolicState state;

  const MacroTotalsCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's Macros",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            Row(
              children: [
                _MacroTile('Carbs', '${state.totalCarbsG.round()}g', AppTheme.teal),
                _MacroTile(
                    'Protein', '${state.totalProteinG.round()}g', AppTheme.amber),
                _MacroTile('Fat', '${state.totalFatG.round()}g', AppTheme.coral),
                _MacroTile('kcal', '${state.totalCalories.round()}',
                    Colors.white54),
              ],
            ),
            const SizedBox(height: 12),
            _MicroRow(state: state),
          ],
        ),
      ),
    );
  }
}

class _MacroTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}

class _MicroRow extends StatelessWidget {
  final MetabolicState state;

  const _MicroRow({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.grass, size: 14, color: Colors.green),
        const SizedBox(width: 4),
        Text(
          'Fiber: ${state.totalFiberG.round()}g',
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
      ],
    );
  }
}
