import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../demo/demo_accounts.dart';
import '../../models/user_profile.dart';
import '../../repositories/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  final _nameCtrl = TextEditingController();
  int _age = 25;
  BiologicalSex _sex = BiologicalSex.male;
  double _heightCm = 175;
  double _weightKg = 75;
  ActivityBaseline _activity = ActivityBaseline.moderatelyActive;
  final Set<String> _allergies = {};
  bool _usesGlp1 = false;

  final _commonAllergies = [
    'Gluten',
    'Dairy',
    'Nuts',
    'Soy',
    'Eggs',
    'Shellfish',
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      setState(() => _page++);
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
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
      body: GradientShell(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  _Header(page: _page),
                  Expanded(
                    child: PageView(
                      controller: _pageCtrl,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _DemoPickerPage(
                          onDemoPicked: (demo) {
                            context.read<AppState>().loadDemoAccount(demo);
                            context.go('/dashboard');
                          },
                          onContinue: _next,
                        ),
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
                          onActivityChanged: (v) =>
                              setState(() => _activity = v),
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
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int page;

  const _Header({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        children: [
          const BrandHeader(),
          const SizedBox(height: 28),
          Row(
            children: List.generate(3, (index) {
              final active = index <= page;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
                  decoration: BoxDecoration(
                    gradient: active ? AppTheme.brandGradient : null,
                    color: active ? null : AppTheme.gray200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _DemoPickerPage extends StatelessWidget {
  final void Function(DemoAccount) onDemoPicked;
  final VoidCallback onContinue;

  const _DemoPickerPage({
    required this.onDemoPicked,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Fuel your lifts with informed physiology estimates.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 34),
          Text(
            'Try a demo account',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          ...DemoAccounts.all.map(
            (demo) => _DemoCard(demo: demo, onTap: () => onDemoPicked(demo)),
          ),
          const SizedBox(height: 28),
          GradientButton(
            onPressed: onContinue,
            child: const Text('Set up my own profile'),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE0E7FF), Color(0xFFF3E8FF)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.person, color: AppTheme.indigo),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(demo.label,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
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
      ),
    );
  }
}

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
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Biometrics',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Used to estimate your glycogen capacity and energy needs.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                hintText: 'Name (optional)',
                prefixIcon: Icon(Icons.person_outline, color: AppTheme.gray500),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          const SizedBox(height: 22),
          _SectionLabel('Biological sex'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SelectableButton(
                  label: 'Male',
                  selected: sex == BiologicalSex.male,
                  onTap: () => onSexChanged(BiologicalSex.male),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SelectableButton(
                  label: 'Female',
                  selected: sex == BiologicalSex.female,
                  onTap: () => onSexChanged(BiologicalSex.female),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SliderField(
            label: 'Age: $age years',
            value: age.toDouble(),
            min: 18,
            max: 80,
            divisions: 62,
            onChanged: (v) => onAgeChanged(v.round()),
          ),
          _SliderField(
            label: 'Height: ${heightCm.round()} cm',
            value: heightCm,
            min: 140,
            max: 220,
            divisions: 80,
            onChanged: onHeightChanged,
          ),
          _SliderField(
            label: 'Weight: ${weightKg.round()} kg',
            value: weightKg,
            min: 40,
            max: 150,
            divisions: 110,
            onChanged: onWeightChanged,
          ),
          const SizedBox(height: 20),
          GradientButton(onPressed: onNext, child: const Text('Continue')),
        ],
      ),
    );
  }
}

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
    ActivityBaseline.lightlyActive: 'Lightly active (1-2x/week)',
    ActivityBaseline.moderatelyActive: 'Moderately active (3-5x/week)',
    ActivityBaseline.veryActive: 'Very active (6-7x/week)',
    ActivityBaseline.extraActive: 'Extra active (athlete / physical job)',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity & Preferences',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 28),
          Text('Activity baseline',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          ..._activityLabels.entries.map(
            (entry) => _ActivityTile(
              label: entry.value,
              selected: activity == entry.key,
              onTap: () => onActivityChanged(entry.key),
            ),
          ),
          const SizedBox(height: 24),
          Text('Allergies / restrictions',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: commonAllergies
                .map(
                  (allergy) => FilterChip(
                    label: Text(allergy),
                    selected: allergies.contains(allergy),
                    selectedColor: const Color(0xFFE0E7FF),
                    checkmarkColor: AppTheme.indigo,
                    side: BorderSide(
                      color: allergies.contains(allergy)
                          ? AppTheme.indigo
                          : AppTheme.gray200,
                      width: 1.5,
                    ),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: allergies.contains(allergy)
                          ? AppTheme.indigo
                          : AppTheme.gray600,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => onAllergyToggled(allergy),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('I use a GLP-1 medication',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'e.g. semaglutide, tirzepatide - affects gastric emptying',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: usesGlp1,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppTheme.teal,
                  onChanged: onGlp1Changed,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          GradientButton(
            onPressed: onFinish,
            child: const Text('Start FuelWindow'),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ActivityTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFECFDF5) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppTheme.emerald : AppTheme.gray200,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.teal : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppTheme.teal : AppTheme.gray200,
                    width: 2,
                  ),
                ),
                child: selected
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
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? AppTheme.slate : AppTheme.gray700,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectableButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFECFDF5) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.emerald : AppTheme.gray200,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected) ...[
              const Icon(Icons.check, color: AppTheme.teal, size: 18),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.tealDark : AppTheme.gray600,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ],
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
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
