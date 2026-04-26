import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/fuel_prescription.dart';
import '../../repositories/app_state.dart';
import '../../services/explanation_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

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
        body: GradientShell(
          child: SafeArea(
            child: Column(
              children: [
                _TopBar(
                  title: 'Fuel Prescription',
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go('/dashboard'),
                ),
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No upcoming session planned.\nGo to Plan a Lift to schedule one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.gray600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final whyText = ExplanationService.explainPrescription(rx, ms, rx.session);

    return Scaffold(
      body: GradientShell(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  _TopBar(
                    title: 'Fuel Prescription',
                    onBack: () => context.canPop()
                        ? context.pop()
                        : context.go('/dashboard'),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      children: [
                        _HeaderCard(rx: rx),
                        if (rx.preLiftMeals.isNotEmpty)
                          _MealSection(
                            title: 'Pre-Lift Meals',
                            icon: Icons.restaurant,
                            color: AppTheme.teal,
                            items: rx.preLiftMeals,
                          ),
                        if (rx.duringLiftFuels.isNotEmpty)
                          _MealSection(
                            title: 'During Session',
                            icon: Icons.bolt,
                            color: AppTheme.amber,
                            items: rx.duringLiftFuels,
                          ),
                        if (rx.postLiftMeals.isNotEmpty)
                          _MealSection(
                            title: 'Post-Lift Recovery',
                            icon: Icons.replay,
                            color: AppTheme.coral,
                            items: rx.postLiftMeals,
                          ),
                        _WhyCard(
                          explanation: whyText,
                          expanded: _showWhy,
                          onToggle: () => setState(() => _showWhy = !_showWhy),
                        ),
                        const _GlossaryCard(),
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

class _HeaderCard extends StatelessWidget {
  final FuelPrescription rx;

  const _HeaderCard({required this.rx});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      gradient: AppTheme.indigoGradient,
      borderColor: Colors.transparent,
      padding: const EdgeInsets.all(22),
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _timingLabel(rx.timing),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (rx.urgentRefuel)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Urgent refuel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            rx.headline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            rx.summary,
            style: const TextStyle(
              color: Color(0xFFE0E7FF),
              fontSize: 15,
              height: 1.42,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _TargetStat(
                  label: 'Target carbs',
                  value: '${rx.targetCarbsG.round()}g',
                ),
              ),
              Expanded(
                child: _TargetStat(
                  label: 'Target protein',
                  value: '${rx.targetProteinG.round()}g',
                ),
              ),
              Expanded(
                child: _TargetStat(
                  label: 'Session',
                  value: rx.session.displayName,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _timingLabel(PrescriptionTiming timing) => switch (timing) {
        PrescriptionTiming.preLift => '1-3 h pre-lift',
        PrescriptionTiming.immediatelyPre => '< 45 min pre',
        PrescriptionTiming.duringLift => 'During session',
        PrescriptionTiming.postLift => 'Post-lift window',
        PrescriptionTiming.restDay => 'Rest day',
      };
}

class _TargetStat extends StatelessWidget {
  final String label;
  final String value;

  const _TargetStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFFC7D2FE), fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 18),
              ),
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
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.name,
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppTheme.gray500,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (item.carbsG > 0)
                      AppPill(
                          label: '${item.carbsG.round()}g C',
                          color: AppTheme.teal),
                    if (item.proteinG > 0)
                      AppPill(
                          label: '${item.proteinG.round()}g P',
                          color: AppTheme.amber),
                    if (item.fatG > 0)
                      AppPill(
                          label: '${item.fatG.round()}g F',
                          color: AppTheme.coral),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: widget.color.withAlpha(18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      item.rationale,
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
      ),
    );
  }
}

class _WhyCard extends StatelessWidget {
  final String explanation;
  final bool expanded;
  final VoidCallback onToggle;

  const _WhyCard({
    required this.explanation,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        color: const Color(0xFFEFF6FF),
        borderColor: const Color(0xFFBFDBFE),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onToggle,
              child: Row(
                children: [
                  const Icon(Icons.school_outlined, color: AppTheme.indigo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Why this prescription?',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: const Color(0xFF312E81))),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.indigo,
                  ),
                ],
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 12),
              Text(
                explanation,
                style: const TextStyle(
                  color: Color(0xFF3730A3),
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GlossaryCard extends StatelessWidget {
  const _GlossaryCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      color: Color(0xFFEEF2FF),
      borderColor: Color(0xFFC7D2FE),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_outlined, color: AppTheme.indigo),
              SizedBox(width: 8),
              Text(
                'Physiology Glossary',
                style: TextStyle(
                  color: Color(0xFF312E81),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _GlossaryText(
            title: 'Liver glycogen',
            body:
                'A small glucose reserve that helps maintain blood sugar between meals and during training.',
          ),
          _GlossaryText(
            title: 'Muscle glycogen',
            body:
                'Stored carbohydrate inside muscle tissue for high-intensity lifting and intervals.',
          ),
          _GlossaryText(
            title: 'Fructose vs glucose',
            body:
                'Fructose preferentially refills liver stores; glucose helps refill both liver and muscle.',
          ),
        ],
      ),
    );
  }
}

class _GlossaryText extends StatelessWidget {
  final String title;
  final String body;

  const _GlossaryText({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text.rich(
        TextSpan(
          text: '$title: ',
          style: const TextStyle(
            color: Color(0xFF3730A3),
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
          children: [
            TextSpan(
              text: body,
              style: const TextStyle(
                color: Color(0xFF4338CA),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
