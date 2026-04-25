import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/fuel_prescription.dart';
import '../../repositories/app_state.dart';
import '../../services/explanation_service.dart';
import '../../theme/app_theme.dart';

class PrescriptionScreen extends StatefulWidget {
  const PrescriptionScreen({super.key});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  bool _showWhy = false;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final rx = appState.prescription;
    final ms = appState.metabolicState;

    if (rx == null || ms == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fuel Prescription')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'No upcoming session planned.\nGo to Lift Planner to schedule one.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final whyText = ExplanationService.explainPrescription(
        rx, ms, rx.session);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuel Prescription'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
        children: [
          _HeaderCard(rx: rx),
          if (rx.preLiftMeals.isNotEmpty)
            _MealSection(
                title: 'Pre-Lift Meals',
                icon: Icons.dining,
                color: AppTheme.teal,
                items: rx.preLiftMeals),
          if (rx.duringLiftFuels.isNotEmpty)
            _MealSection(
                title: 'During Session',
                icon: Icons.bolt,
                color: AppTheme.amber,
                items: rx.duringLiftFuels),
          if (rx.postLiftMeals.isNotEmpty)
            _MealSection(
                title: 'Post-Lift Recovery',
                icon: Icons.replay,
                color: AppTheme.coral,
                items: rx.postLiftMeals),
          _WhyCard(
            explanation: whyText,
            isExpanded: _showWhy,
            onToggle: () => setState(() => _showWhy = !_showWhy),
          ),
          _GlossaryCard(),
        ],
      ),
    );
  }
}

// ─── Header card ────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final FuelPrescription rx;
  const _HeaderCard({required this.rx});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _timingColor(rx.timing).withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _timingColor(rx.timing).withAlpha(100)),
                  ),
                  child: Text(
                    _timingLabel(rx.timing),
                    style: TextStyle(
                        color: _timingColor(rx.timing),
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                if (rx.urgentRefuel) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.coral.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppTheme.coral.withAlpha(100)),
                    ),
                    child: const Text(
                      '⚠ URGENT REFUEL',
                      style: TextStyle(
                          color: AppTheme.coral,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text(rx.headline,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(rx.summary,
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                _TargetChip(
                    'Target carbs',
                    '${rx.targetCarbsG.round()}g',
                    AppTheme.teal),
                const SizedBox(width: 10),
                _TargetChip(
                    'Target protein',
                    '${rx.targetProteinG.round()}g',
                    AppTheme.amber),
                const SizedBox(width: 10),
                _TargetChip(
                    'Session',
                    rx.session.displayName,
                    Colors.white38),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timingLabel(PrescriptionTiming t) => switch (t) {
        PrescriptionTiming.preLift => '1–3 h pre-lift',
        PrescriptionTiming.immediatelyPre => '< 45 min pre',
        PrescriptionTiming.duringLift => 'During session',
        PrescriptionTiming.postLift => 'Post-lift window',
        PrescriptionTiming.restDay => 'Rest day',
      };

  Color _timingColor(PrescriptionTiming t) => switch (t) {
        PrescriptionTiming.postLift => AppTheme.coral,
        PrescriptionTiming.immediatelyPre => AppTheme.amber,
        _ => AppTheme.teal,
      };
}

class _TargetChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TargetChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: color.withAlpha(180), fontSize: 10)),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ─── Meal section ────────────────────────────────────────────────────────────

class _MealSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<FuelItem> items;
  const _MealSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => _FuelItemCard(item: item, color: color)),
        ],
      ),
    );
  }
}

class _FuelItemCard extends StatefulWidget {
  final FuelItem item;
  final Color color;
  const _FuelItemCard({required this.item, required this.color});

  @override
  State<_FuelItemCard> createState() => _FuelItemCardState();
}

class _FuelItemCardState extends State<_FuelItemCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.color.withAlpha(40)),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.item.name,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
              Row(
                children: [
                  if (widget.item.carbsG > 0)
                    _MacroBadge('${widget.item.carbsG.round()}g C',
                        AppTheme.teal),
                  if (widget.item.proteinG > 0) ...[
                    const SizedBox(width: 6),
                    _MacroBadge('${widget.item.proteinG.round()}g P',
                        AppTheme.amber),
                  ],
                  if (widget.item.fatG > 0) ...[
                    const SizedBox(width: 6),
                    _MacroBadge(
                        '${widget.item.fatG.round()}g F', AppTheme.coral),
                  ],
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.color.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.item.rationale,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MacroBadge(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Why card ────────────────────────────────────────────────────────────────

class _WhyCard extends StatelessWidget {
  final String explanation;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _WhyCard({
    required this.explanation,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.teal.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.science_outlined,
                        color: AppTheme.teal, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('Why?',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppTheme.teal)),
                  const Spacer(),
                  Text(
                    isExpanded ? 'Collapse' : 'The physiology behind this',
                    style: const TextStyle(
                        color: AppTheme.teal, fontSize: 13),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.teal,
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 14),
                Text(explanation,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(height: 1.6)),
                const SizedBox(height: 12),
                const _Disclaimer(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.white38, size: 15),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'These are informed physiology estimates, not medical-grade precision or clinical recommendations.',
              style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Glossary card ───────────────────────────────────────────────────────────

class _GlossaryCard extends StatefulWidget {
  @override
  State<_GlossaryCard> createState() => _GlossaryCardState();
}

class _GlossaryCardState extends State<_GlossaryCard> {
  bool _expanded = false;

  static final _terms = [
    ('Liver Glycogen', ExplanationService.explainGlycogen()),
    ('Fructose vs Glucose', ExplanationService.explainFructose()),
    ('GLP-1', ExplanationService.explainGlp1()),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_book_outlined,
                      color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Text('Physiology Glossary',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white70)),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white38,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 12),
                ..._GlossaryCard._terms.map((t) => _GlossaryEntry(title: t.$1, text: t.$2)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GlossaryEntry extends StatelessWidget {
  final String title;
  final String text;
  const _GlossaryEntry({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppTheme.teal,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}
