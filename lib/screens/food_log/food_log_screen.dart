import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/food_log.dart';
import '../../models/nutrition_estimate.dart';
import '../../repositories/app_state.dart';
import '../../services/food_parser.dart';
import '../../theme/app_theme.dart';

class FoodLogScreen extends StatefulWidget {
  const FoodLogScreen({super.key});

  @override
  State<FoodLogScreen> createState() => _FoodLogScreenState();
}

class _FoodLogScreenState extends State<FoodLogScreen> {
  final _inputCtrl = TextEditingController();
  NutritionEstimate? _preview;
  bool _showPreview = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  void _parseInput() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    final est = FoodParser.parseText(text);
    setState(() {
      _preview = est;
      _showPreview = true;
    });
  }

  void _confirmLog() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    context.read<AppState>().logFood(text);
    _inputCtrl.clear();
    setState(() {
      _preview = null;
      _showPreview = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Food logged ✓'),
        backgroundColor: AppTheme.teal,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final logs = appState.foodLogs.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Log'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _InputSection(
            ctrl: _inputCtrl,
            preview: _showPreview ? _preview : null,
            onParse: _parseInput,
            onConfirm: _confirmLog,
            onClearPreview: () => setState(() => _showPreview = false),
          ),
          const Divider(height: 1, color: AppTheme.surfaceCard),
          Expanded(
            child: logs.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: logs.length,
                    itemBuilder: (ctx, i) =>
                        _FoodLogTile(log: logs[i], appState: appState),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Input section ───────────────────────────────────────────────────────────

class _InputSection extends StatelessWidget {
  final TextEditingController ctrl;
  final NutritionEstimate? preview;
  final VoidCallback onParse;
  final VoidCallback onConfirm;
  final VoidCallback onClearPreview;

  const _InputSection({
    required this.ctrl,
    required this.preview,
    required this.onParse,
    required this.onConfirm,
    required this.onClearPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    hintText:
                        'e.g. two eggs, oatmeal with blueberries, coffee',
                    hintStyle: const TextStyle(color: Colors.white30),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search, color: AppTheme.teal),
                      onPressed: onParse,
                    ),
                  ),
                  onSubmitted: (_) => onParse(),
                  textInputAction: TextInputAction.search,
                ),
              ),
            ],
          ),
          if (preview != null) ...[
            const SizedBox(height: 12),
            _NutritionPreviewCard(
              estimate: preview!,
              onConfirm: onConfirm,
              onDismiss: onClearPreview,
            ),
          ],
        ],
      ),
    );
  }
}

class _NutritionPreviewCard extends StatelessWidget {
  final NutritionEstimate estimate;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const _NutritionPreviewCard({
    required this.estimate,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.teal.withAlpha(60)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(estimate.foodName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppTheme.teal)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.white38),
                onPressed: onDismiss,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _NutrientBadge('Carbs', '${estimate.carbsG.round()}g',
                  AppTheme.teal),
              const SizedBox(width: 8),
              _NutrientBadge('Protein', '${estimate.proteinG.round()}g',
                  AppTheme.amber),
              const SizedBox(width: 8),
              _NutrientBadge(
                  'Fat', '${estimate.fatG.round()}g', AppTheme.coral),
              const SizedBox(width: 8),
              _NutrientBadge(
                  'kcal', '${estimate.calories.round()}', Colors.white54),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Glucose: ${estimate.glucoseG.round()}g · Fructose: ${estimate.fructoseG.round()}g · Fiber: ${estimate.fiberG.round()}g',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          if (estimate.isHighFat || estimate.isHighFiber) ...[
            const SizedBox(height: 4),
            Text(
              '⏳ Slower absorption expected'
              '${estimate.isHighFat ? " (high fat)" : ""}'
              '${estimate.isHighFiber ? " (high fiber)" : ""}',
              style: const TextStyle(
                  color: AppTheme.amber, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onConfirm,
            child: const Text('Log this food ✓'),
          ),
        ],
      ),
    );
  }
}

class _NutrientBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _NutrientBadge(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        Text(label,
            style:
                const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}

// ─── Log tile ────────────────────────────────────────────────────────────────

class _FoodLogTile extends StatelessWidget {
  final FoodLog log;
  final AppState appState;
  const _FoodLogTile({required this.log, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.coral.withAlpha(60),
        child: const Icon(Icons.delete_outline, color: AppTheme.coral),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove food log?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Remove',
                      style: TextStyle(color: AppTheme.coral))),
            ],
          ),
        );
      },
      onDismissed: (_) => appState.deleteFoodLog(log.id),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.teal.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.restaurant, color: AppTheme.teal, size: 20),
        ),
        title: Text(log.nutrition.foodName,
            style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          '${log.nutrition.carbsG.round()}g carbs · ${log.nutrition.proteinG.round()}g protein · ${log.nutrition.calories.round()} kcal',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        trailing: Text(
          _timeLabel(log.loggedAt),
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final h = dt.hour;
    final amPm = h < 12 ? 'am' : 'pm';
    final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour:${dt.minute.toString().padLeft(2, '0')}$amPm';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_outlined,
                size: 60, color: Colors.white.withAlpha(30)),
            const SizedBox(height: 16),
            Text('No food logged yet',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white38)),
            const SizedBox(height: 8),
            Text('Describe what you ate above to track your glycogen.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
