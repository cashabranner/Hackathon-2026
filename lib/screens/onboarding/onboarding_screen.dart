import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../demo/demo_accounts.dart';
import '../../models/user_profile.dart';
import '../../repositories/app_state.dart';
import '../../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  // Form state
  final _nameCtrl = TextEditingController();
  int _age = 25;
  BiologicalSex _sex = BiologicalSex.male;
  double _heightCm = 175;
  double _weightKg = 75;
  ActivityBaseline _activity = ActivityBaseline.moderatelyActive;
  final Set<String> _allergies = {};
  bool _usesGlp1 = false;

  final _commonAllergies = ['Gluten', 'Dairy', 'Nuts', 'Soy', 'Eggs', 'Shellfish'];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      setState(() => _page++);
    } else {
      _finish();
    }
  }

  void _finish() {
    final profile = UserProfile(
      id: const Uuid().v4(),
      name: _nameCtrl.text.trim().isEmpty ? 'Athlete' : _nameCtrl.text.trim(),
      ageYears: _age,
      sex: _sex,
      heightCm: _heightCm,
      weightKg: _weightKg,
      activityBaseline: _activity,
      allergies: _allergies.toList(),
      usesGlp1: _usesGlp1,
      createdAt: DateTime.now(),
    );
    context.read<AppState>().saveProfile(profile);
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _DemoPickerPage(onDemoPicked: (demo) {
                    context.read<AppState>().loadDemoAccount(demo);
                    context.go('/dashboard');
                  }, onContinue: _next),
                  _BiometricsPage(
                    nameCtrl: _nameCtrl,
                    age: _age,
                    sex: _sex,
                    heightCm: _heightCm,
                    weightKg: _weightKg,
                    onAgeChanged: (v) => setState(() => _age = v),
                    onSexChanged: (v) => setState(() => _sex = v),
                    onHeightChanged: (v) => setState(() => _heightCm = v),
                    onWeightChanged: (v) => setState(() => _weightKg = v),
                    onNext: _next,
                  ),
                  _PreferencesPage(
                    activity: _activity,
                    allergies: _allergies,
                    commonAllergies: _commonAllergies,
                    usesGlp1: _usesGlp1,
                    onActivityChanged: (v) => setState(() => _activity = v),
                    onAllergyToggled: (a) => setState(() {
                      if (_allergies.contains(a)) {
                        _allergies.remove(a);
                      } else {
                        _allergies.add(a);
                      }
                    }),
                    onGlp1Changed: (v) => setState(() => _usesGlp1 = v),
                    onFinish: _finish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.teal,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt, color: AppTheme.slate, size: 22),
              ),
              const SizedBox(width: 10),
              Text('FuelWindow',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: AppTheme.teal)),
            ],
          ),
          const SizedBox(height: 20),
          // Step indicator
          Row(
            children: List.generate(3, (i) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  height: 3,
                  decoration: BoxDecoration(
                    color: i <= _page
                        ? AppTheme.teal
                        : AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Page 0: Demo picker ────────────────────────────────────────────────────

class _DemoPickerPage extends StatelessWidget {
  final void Function(DemoAccount) onDemoPicked;
  final VoidCallback onContinue;

  const _DemoPickerPage(
      {required this.onDemoPicked, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 6),
          Text(
            'Fuel your lifts with informed physiology estimates.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          Text('Try a demo account',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...DemoAccounts.all.map((demo) => _DemoCard(
                demo: demo,
                onTap: () => onDemoPicked(demo),
              )),
          const SizedBox(height: 24),
          const Divider(color: AppTheme.surfaceCard),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onContinue,
            child: const Text('Set up my own profile →'),
          ),
        ],
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  final DemoAccount demo;
  final VoidCallback onTap;

  const _DemoCard({required this.demo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.teal.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.person, color: AppTheme.teal, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(demo.label,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(demo.description,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.teal),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Page 1: Biometrics ─────────────────────────────────────────────────────

class _BiometricsPage extends StatelessWidget {
  final TextEditingController nameCtrl;
  final int age;
  final BiologicalSex sex;
  final double heightCm;
  final double weightKg;
  final void Function(int) onAgeChanged;
  final void Function(BiologicalSex) onSexChanged;
  final void Function(double) onHeightChanged;
  final void Function(double) onWeightChanged;
  final VoidCallback onNext;

  const _BiometricsPage({
    required this.nameCtrl,
    required this.age,
    required this.sex,
    required this.heightCm,
    required this.weightKg,
    required this.onAgeChanged,
    required this.onSexChanged,
    required this.onHeightChanged,
    required this.onWeightChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Biometrics',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Used to estimate your glycogen capacity and energy needs.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name (optional)',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 20),
          _label(context, 'Biological sex'),
          const SizedBox(height: 8),
          SegmentedButton<BiologicalSex>(
            segments: const [
              ButtonSegment(value: BiologicalSex.male, label: Text('Male')),
              ButtonSegment(
                  value: BiologicalSex.female, label: Text('Female')),
            ],
            selected: {sex},
            onSelectionChanged: (s) => onSexChanged(s.first),
          ),
          const SizedBox(height: 20),
          _label(context, 'Age: $age years'),
          Slider(
            value: age.toDouble(),
            min: 16,
            max: 75,
            divisions: 59,
            label: '$age',
            activeColor: AppTheme.teal,
            onChanged: (v) => onAgeChanged(v.round()),
          ),
          _label(context, 'Height: ${heightCm.round()} cm'),
          Slider(
            value: heightCm,
            min: 140,
            max: 220,
            divisions: 80,
            label: '${heightCm.round()} cm',
            activeColor: AppTheme.teal,
            onChanged: onHeightChanged,
          ),
          _label(context, 'Weight: ${weightKg.round()} kg'),
          Slider(
            value: weightKg,
            min: 40,
            max: 160,
            divisions: 120,
            label: '${weightKg.round()} kg',
            activeColor: AppTheme.teal,
            onChanged: onWeightChanged,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onNext, child: const Text('Continue →')),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: Colors.white70));
  }
}

// ─── Page 2: Preferences ────────────────────────────────────────────────────

class _PreferencesPage extends StatelessWidget {
  final ActivityBaseline activity;
  final Set<String> allergies;
  final List<String> commonAllergies;
  final bool usesGlp1;
  final void Function(ActivityBaseline) onActivityChanged;
  final void Function(String) onAllergyToggled;
  final void Function(bool) onGlp1Changed;
  final VoidCallback onFinish;

  const _PreferencesPage({
    required this.activity,
    required this.allergies,
    required this.commonAllergies,
    required this.usesGlp1,
    required this.onActivityChanged,
    required this.onAllergyToggled,
    required this.onGlp1Changed,
    required this.onFinish,
  });

  static const _activityLabels = {
    ActivityBaseline.sedentary: 'Sedentary (desk job, little exercise)',
    ActivityBaseline.lightlyActive: 'Lightly active (1–2×/week)',
    ActivityBaseline.moderatelyActive: 'Moderately active (3–5×/week)',
    ActivityBaseline.veryActive: 'Very active (6–7×/week)',
    ActivityBaseline.extraActive: 'Extra active (athlete / physical job)',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity & Preferences',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Text('Activity baseline',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ..._activityLabels.entries.map((e) => RadioListTile<ActivityBaseline>(
                title: Text(e.value,
                    style: Theme.of(context).textTheme.bodyMedium),
                value: e.key,
                groupValue: activity,
                activeColor: AppTheme.teal,
                onChanged: (v) => v != null ? onActivityChanged(v) : null,
              )),
          const SizedBox(height: 20),
          Text('Allergies / restrictions',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: commonAllergies
                .map((a) => FilterChip(
                      label: Text(a),
                      selected: allergies.contains(a),
                      selectedColor: AppTheme.coral.withAlpha(80),
                      onSelected: (_) => onAllergyToggled(a),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text('I use a GLP-1 medication'),
            subtitle: const Text(
                'e.g. semaglutide, tirzepatide — affects gastric emptying'),
            value: usesGlp1,
            activeColor: AppTheme.teal,
            onChanged: onGlp1Changed,
          ),
          const SizedBox(height: 28),
          FilledButton(onPressed: onFinish, child: const Text('Start FuelWindow')),
        ],
      ),
    );
  }
}
