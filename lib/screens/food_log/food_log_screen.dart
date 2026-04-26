import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/food_log.dart';
import '../../models/nutrition_estimate.dart';
import '../../repositories/app_state.dart';
import '../../services/food_parser.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

class FoodLogScreen extends StatefulWidget {
  const FoodLogScreen({super.key});

  @override
  State<FoodLogScreen> createState() => _FoodLogScreenState();
}

class _FoodLogScreenState extends State<FoodLogScreen> {
  final _inputCtrl = TextEditingController();
  NutritionEstimate? _preview;
  String _previewSource = 'local_fallback';
  bool _isParsing = false;
  bool _isLogging = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _parseInput() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isParsing || _isLogging) return;

    setState(() => _isParsing = true);

    var source = 'local_fallback';
    late NutritionEstimate estimate;
    try {
      if (AppConfig.hasRemoteFoodParser) {
        estimate = await FoodParser.parseTextRemote(
          text,
          AppConfig.foodParserUrl,
          AppConfig.supabaseAnonKey,
        );
        source = 'edge_function';
      } else {
        estimate = FoodParser.parseText(text);
      }
    } catch (_) {
      estimate = FoodParser.parseText(text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Using local estimate for now'),
            backgroundColor: AppTheme.amber,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _preview = estimate;
      _previewSource = source;
      _isParsing = false;
    });
  }

  Future<void> _confirmLog() async {
    final text = _inputCtrl.text.trim();
    final preview = _preview;
    if (text.isEmpty || preview == null || _isLogging) return;

    setState(() => _isLogging = true);
    await context.read<AppState>().logFood(
          text,
          nutrition: preview,
          source: _previewSource,
        );

    if (!mounted) return;
    _inputCtrl.clear();
    setState(() {
      _preview = null;
      _previewSource = 'local_fallback';
      _isLogging = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Food logged.'),
        backgroundColor: AppTheme.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final logs = appState.foodLogs.reversed.toList();

    return Scaffold(
      body: GradientShell(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  _TopBar(
                    title: 'Food Log',
                    onBack: () => context.canPop()
                        ? context.pop()
                        : context.go('/dashboard'),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      children: [
                        _InputSection(
                          ctrl: _inputCtrl,
                          preview: _preview,
                          previewSource: _previewSource,
                          isParsing: _isParsing,
                          isLogging: _isLogging,
                          onParse: _parseInput,
                          onConfirm: _confirmLog,
                          onDismiss: () => setState(() => _preview = null),
                        ),
                        const SizedBox(height: 14),
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Recent Meals',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 14),
                              if (logs.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Text(
                                      'No food logged yet',
                                      style: TextStyle(color: AppTheme.gray500),
                                    ),
                                  ),
                                )
                              else
                                ...logs.map(
                                  (log) => _FoodLogTile(
                                    log: log,
                                    appState: appState,
                                  ),
                                ),
                            ],
                          ),
                        ),
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

class _InputSection extends StatelessWidget {
  final TextEditingController ctrl;
  final NutritionEstimate? preview;
  final String previewSource;
  final bool isParsing;
  final bool isLogging;
  final VoidCallback onParse;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const _InputSection({
    required this.ctrl,
    required this.preview,
    required this.previewSource,
    required this.isParsing,
    required this.isLogging,
    required this.onParse,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Describe a meal',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: 'two eggs, oatmeal with blueberries, coffee',
              suffixIcon: IconButton(
                icon: isParsing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search, color: AppTheme.teal),
                onPressed: isParsing || isLogging ? null : onParse,
              ),
            ),
            onSubmitted: (_) {
              if (!isParsing && !isLogging) onParse();
            },
          ),
          if (preview != null) ...[
            const SizedBox(height: 14),
            _NutritionPreviewCard(
              estimate: preview!,
              source: previewSource,
              isLogging: isLogging,
              onConfirm: onConfirm,
              onDismiss: onDismiss,
            ),
          ],
        ],
      ),
    );
  }
}

class _NutritionPreviewCard extends StatelessWidget {
  final NutritionEstimate estimate;
  final String source;
  final bool isLogging;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const _NutritionPreviewCard({
    required this.estimate,
    required this.source,
    required this.isLogging,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.teal.withAlpha(90)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  estimate.foodName,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppTheme.tealDark),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: isLogging ? null : onDismiss,
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppPill(
                  label: '${estimate.carbsG.round()}g C', color: AppTheme.teal),
              AppPill(
                  label: '${estimate.proteinG.round()}g P',
                  color: AppTheme.amber),
              AppPill(
                  label: '${estimate.fatG.round()}g F', color: AppTheme.coral),
              AppPill(
                  label: '${estimate.calories.round()} kcal',
                  color: AppTheme.gray500),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Glucose: ${estimate.glucoseG.round()}g - Fructose: ${estimate.fructoseG.round()}g - Fiber: ${estimate.fiberG.round()}g',
            style: const TextStyle(color: AppTheme.gray600, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            source == 'edge_function' ? 'AI estimate' : 'Local estimate',
            style: const TextStyle(color: AppTheme.gray500, fontSize: 12),
          ),
          if (estimate.isHighFat || estimate.isHighFiber) ...[
            const SizedBox(height: 6),
            const Text(
              'Slower absorption expected',
              style: TextStyle(color: AppTheme.amber, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          GradientButton(
            onPressed: isLogging ? null : onConfirm,
            child: Text(isLogging ? 'Logging...' : 'Log this food'),
          ),
        ],
      ),
    );
  }
}

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
        decoration: BoxDecoration(
          color: AppTheme.coral.withAlpha(30),
          borderRadius: BorderRadius.circular(16),
        ),
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
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: AppTheme.coral),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => appState.deleteFoodLog(log.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.inputFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.restaurant, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.nutrition.foodName,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    '${log.nutrition.carbsG.round()}g carbs - ${log.nutrition.proteinG.round()}g protein - ${log.nutrition.calories.round()} kcal',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Text(
              DateFormat('h:mm a').format(log.loggedAt),
              style: const TextStyle(color: AppTheme.gray500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
