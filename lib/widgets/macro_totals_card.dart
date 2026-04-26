import 'package:flutter/material.dart';

import '../models/metabolic_state.dart';
import '../theme/app_theme.dart';
import 'app_ui.dart';

class MacroTotalsCard extends StatelessWidget {
  final MetabolicState state;

  const MacroTotalsCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's Macros",
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 20)),
            const SizedBox(height: 18),
            Row(
              children: [
                _MacroTile(
                    'Carbs', '${state.totalCarbsG.round()}g', AppTheme.teal),
                _MacroTile('Protein', '${state.totalProteinG.round()}g',
                    AppTheme.amber),
                _MacroTile(
                    'Fat', '${state.totalFatG.round()}g', AppTheme.coral),
                _MacroTile(
                    'kcal', '${state.totalCalories.round()}', AppTheme.gray500),
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
                  color: color, fontSize: 28, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: AppTheme.gray600, fontSize: 13)),
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
          style: const TextStyle(fontSize: 13, color: AppTheme.gray600),
        ),
      ],
    );
  }
}
