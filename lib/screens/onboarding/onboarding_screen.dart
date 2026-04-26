import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../demo/demo_accounts.dart';
import '../../models/nutrition_estimate.dart';
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
  final _preferredFoodsCtrl = TextEditingController(text: 'Rice, eggs, banana');
  final _pantryFoodsCtrl = TextEditingController(text: 'Oats, rice, chicken');
  final _avoidedFoodsCtrl = TextEditingController();
  final _preferredExercisesCtrl = TextEditingController(
    text: 'Squat, bench press, row',
  );
  int _age = 25;
  BiologicalSex _sex = BiologicalSex.male;
  double _heightCm = 175;
  double _weightKg = 75;
  ActivityBaseline _activity = ActivityBaseline.moderatelyActive;
  final Set<String> _allergies = {};
  final Set<String> _preferredWeekdays = {'Mon', 'Wed', 'Fri'};
  final Set<String> _muscleEmphases = {'Legs', 'Back'};
  final Map<int, bool> _mealVotes = {};
  String _dietStyle = 'Balanced';
  int _cookingTimeMinutes = 20;
  int _gymDaysPerWeek = 4;
  int _preferredDurationMinutes = 60;
  bool _usesGlp1 = false;
  bool _nutritionSkipped = false;

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
    _preferredFoodsCtrl.dispose();
    _pantryFoodsCtrl.dispose();
    _avoidedFoodsCtrl.dispose();
    _preferredExercisesCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 8) {
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
      foodPreferences: FoodPreferences(
        preferredFoods: _csv(_preferredFoodsCtrl.text),
        pantryFoods: _csv(_pantryFoodsCtrl.text),
        avoidedFoods: _csv(_avoidedFoodsCtrl.text),
        dietStyle: _dietStyle,
        cookingTimePreferenceMinutes: _cookingTimeMinutes,
      ),
      workoutPreferences: WorkoutPreferences(
        gymDaysPerWeek: _gymDaysPerWeek,
        preferredDurationMinutes: _preferredDurationMinutes,
        preferredWeekdays: _preferredWeekdays.toList(),
        muscleEmphases: _muscleEmphases.toList(),
        preferredExercises: _csv(_preferredExercisesCtrl.text),
      ),
      usesGlp1: _usesGlp1,
      createdAt: DateTime.now(),
    );
    final appState = context.read<AppState>();
    appState.saveProfile(profile);
    final yesMeals = _mealVotes.entries
        .where((entry) => entry.value)
        .map((entry) => _mealSuggestions[entry.key])
        .toList();
    if (_nutritionSkipped || yesMeals.isEmpty) {
      appState.seedGenericMealsIfNeeded();
    } else {
      for (final meal in yesMeals) {
        appState.saveMeal(meal);
      }
      for (final meal in _mealSuggestions.skip(3).take(3)) {
        appState.saveMeal(meal);
      }
    }
    context.go('/dashboard');
  }

  void _skipNutrition() {
    setState(() => _nutritionSkipped = true);
    _goToPage(7);
  }

  void _goToPage(int page) {
    setState(() => _page = page);
    _pageCtrl.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  List<NutritionEstimate> get _mealSuggestions {
    final liked = _csv(_preferredFoodsCtrl.text);
    final pantry = _csv(_pantryFoodsCtrl.text);
    final base = [...liked, ...pantry];
    final carb = base.any((f) => f.toLowerCase().contains('rice'))
        ? 'Rice'
        : base.any((f) => f.toLowerCase().contains('oat'))
            ? 'Oats'
            : 'Potato';
    final protein = base.any((f) => f.toLowerCase().contains('egg'))
        ? 'Eggs'
        : base.any((f) => f.toLowerCase().contains('yogurt'))
            ? 'Greek Yogurt'
            : 'Chicken';
    final fruit = base.any((f) => f.toLowerCase().contains('banana'))
        ? 'Banana'
        : 'Berries';
    return [
      _meal('$carb + $protein Bowl', 54, 34, 10),
      _meal('$protein with $fruit', 38, 28, 6),
      _meal('$carb, $fruit, and Protein Shake', 68, 32, 5),
      _meal('Quick $fruit Yogurt Bowl', 44, 30, 4),
      _meal('$carb Power Plate', 72, 26, 8),
      _meal('$protein Recovery Meal', 36, 42, 9),
    ];
  }

  NutritionEstimate _meal(
      String name, double carbs, double protein, double fat) {
    return NutritionEstimate(
      foodName: name,
      grams: 400,
      carbsG: carbs,
      glucoseG: carbs * 0.75,
      fructoseG: carbs * 0.15,
      fiberG: 5,
      proteinG: protein,
      fatG: fat,
      calories: carbs * 4 + protein * 4 + fat * 9,
      isHighFat: fat >= 15,
      isHighFiber: false,
    );
  }

  List<String> _csv(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

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
                  _Header(page: _page, totalPages: 9),
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
                        _AllergiesSetupPage(
                          allergies: _allergies,
                          commonAllergies: _commonAllergies,
                          avoidedFoodsCtrl: _avoidedFoodsCtrl,
                          usesGlp1: _usesGlp1,
                          onAllergyToggled: (a) => setState(() {
                            if (_allergies.contains(a)) {
                              _allergies.remove(a);
                            } else {
                              _allergies.add(a);
                            }
                          }),
                          onGlp1Changed: (v) => setState(() => _usesGlp1 = v),
                          onSkip: _skipNutrition,
                          onNext: _next,
                        ),
                        _FoodLikesSetupPage(
                          preferredFoodsCtrl: _preferredFoodsCtrl,
                          pantryFoodsCtrl: _pantryFoodsCtrl,
                          dietStyle: _dietStyle,
                          cookingTimeMinutes: _cookingTimeMinutes,
                          onDietStyleChanged: (value) =>
                              setState(() => _dietStyle = value),
                          onCookingTimeChanged: (value) =>
                              setState(() => _cookingTimeMinutes = value),
                          onSkip: _skipNutrition,
                          onNext: _next,
                        ),
                        for (var i = 0; i < 3; i++)
                          _MealVotePage(
                            meal: _mealSuggestions[i],
                            onVote: (yes) {
                              setState(() => _mealVotes[i] = yes);
                              _next();
                            },
                            onSkip: _skipNutrition,
                          ),
                        _WorkoutFrequencyPage(
                          activity: _activity,
                          gymDaysPerWeek: _gymDaysPerWeek,
                          preferredDurationMinutes: _preferredDurationMinutes,
                          preferredWeekdays: _preferredWeekdays,
                          onActivityChanged: (v) =>
                              setState(() => _activity = v),
                          onGymDaysChanged: (value) =>
                              setState(() => _gymDaysPerWeek = value),
                          onDurationChanged: (value) =>
                              setState(() => _preferredDurationMinutes = value),
                          onWeekdayToggled: (day) => setState(() {
                            if (_preferredWeekdays.contains(day)) {
                              _preferredWeekdays.remove(day);
                            } else {
                              _preferredWeekdays.add(day);
                            }
                          }),
                          onSkip: _finish,
                          onNext: _next,
                        ),
                        _WorkoutPriorityPage(
                          muscleEmphases: _muscleEmphases,
                          preferredExercisesCtrl: _preferredExercisesCtrl,
                          onMuscleToggled: (muscle) => setState(() {
                            if (_muscleEmphases.contains(muscle)) {
                              _muscleEmphases.remove(muscle);
                            } else {
                              _muscleEmphases.add(muscle);
                            }
                          }),
                          onSkip: _finish,
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
  final int totalPages;

  const _Header({required this.page, required this.totalPages});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        children: [
          const BrandHeader(),
          const SizedBox(height: 28),
          Row(
            children: List.generate(totalPages, (index) {
              final active = index <= page;
              return Expanded(
                child: Container(
                  height: 4,
                  margin:
                      EdgeInsets.only(right: index == totalPages - 1 ? 0 : 4),
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

  const _DemoPickerPage({required this.onDemoPicked, required this.onContinue});

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
                      Text(
                        demo.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        demo.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
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
          Text(
            'Your Biometrics',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
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

class _AllergiesSetupPage extends StatelessWidget {
  final Set<String> allergies;
  final List<String> commonAllergies;
  final TextEditingController avoidedFoodsCtrl;
  final bool usesGlp1;
  final void Function(String) onAllergyToggled;
  final void Function(bool) onGlp1Changed;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _AllergiesSetupPage({
    required this.allergies,
    required this.commonAllergies,
    required this.avoidedFoodsCtrl,
    required this.usesGlp1,
    required this.onAllergyToggled,
    required this.onGlp1Changed,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Food Restrictions',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'These foods are filtered out of meal ideas.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: commonAllergies
                .map(
                  (allergy) => FilterChip(
                    label: Text(allergy),
                    selected: allergies.contains(allergy),
                    onSelected: (_) => onAllergyToggled(allergy),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          _PreferenceTextField(
            controller: avoidedFoodsCtrl,
            label: 'Avoided foods',
            hint: 'Foods you dislike or avoid',
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: usesGlp1,
            onChanged: onGlp1Changed,
            title: const Text('I use a GLP-1 medication'),
            subtitle: const Text('Used for slower digestion estimates.'),
          ),
          const SizedBox(height: 24),
          GradientButton(onPressed: onNext, child: const Text('Continue')),
          TextButton(
              onPressed: onSkip, child: const Text('Skip nutrition setup')),
        ],
      ),
    );
  }
}

class _FoodLikesSetupPage extends StatelessWidget {
  final TextEditingController preferredFoodsCtrl;
  final TextEditingController pantryFoodsCtrl;
  final String dietStyle;
  final int cookingTimeMinutes;
  final void Function(String) onDietStyleChanged;
  final void Function(int) onCookingTimeChanged;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _FoodLikesSetupPage({
    required this.preferredFoodsCtrl,
    required this.pantryFoodsCtrl,
    required this.dietStyle,
    required this.cookingTimeMinutes,
    required this.onDietStyleChanged,
    required this.onCookingTimeChanged,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Foods You Use',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Fuel will prefer foods you like and already have.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          _PreferenceTextField(
            controller: preferredFoodsCtrl,
            label: 'Foods I like',
            hint: 'Rice, eggs, banana',
          ),
          _PreferenceTextField(
            controller: pantryFoodsCtrl,
            label: 'Foods available at home',
            hint: 'Oats, rice, chicken',
          ),
          DropdownButtonFormField<String>(
            initialValue: dietStyle,
            decoration: const InputDecoration(labelText: 'Current diet style'),
            items: const ['Balanced', 'High-carb', 'High-protein', 'Vegetarian']
                .map((style) =>
                    DropdownMenuItem(value: style, child: Text(style)))
                .toList(),
            onChanged: (value) {
              if (value != null) onDietStyleChanged(value);
            },
          ),
          _SliderField(
            label: 'Cooking time: $cookingTimeMinutes min/meal',
            value: cookingTimeMinutes.toDouble(),
            min: 0,
            max: 45,
            divisions: 9,
            onChanged: (value) => onCookingTimeChanged(value.round()),
          ),
          const SizedBox(height: 24),
          GradientButton(onPressed: onNext, child: const Text('Continue')),
          TextButton(
              onPressed: onSkip, child: const Text('Skip nutrition setup')),
        ],
      ),
    );
  }
}

class _MealVotePage extends StatelessWidget {
  final NutritionEstimate meal;
  final ValueChanged<bool> onVote;
  final VoidCallback onSkip;

  const _MealVotePage({
    required this.meal,
    required this.onVote,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Would You Eat This?',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal.foodName,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppPill(
                        label: '${meal.calories.round()} kcal',
                        color: AppTheme.gray500),
                    AppPill(
                        label: '${meal.carbsG.round()}g C',
                        color: AppTheme.teal),
                    AppPill(
                        label: '${meal.proteinG.round()}g P',
                        color: AppTheme.amber),
                    AppPill(
                        label: '${meal.fatG.round()}g F',
                        color: AppTheme.coral),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onVote(false),
                  child: const Text('No'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GradientButton(
                  onPressed: () => onVote(true),
                  child: const Text('Yes'),
                ),
              ),
            ],
          ),
          TextButton(
              onPressed: onSkip, child: const Text('Skip nutrition setup')),
        ],
      ),
    );
  }
}

class _WorkoutFrequencyPage extends StatelessWidget {
  final ActivityBaseline activity;
  final int gymDaysPerWeek;
  final int preferredDurationMinutes;
  final Set<String> preferredWeekdays;
  final void Function(ActivityBaseline) onActivityChanged;
  final void Function(int) onGymDaysChanged;
  final void Function(int) onDurationChanged;
  final void Function(String) onWeekdayToggled;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _WorkoutFrequencyPage({
    required this.activity,
    required this.gymDaysPerWeek,
    required this.preferredDurationMinutes,
    required this.preferredWeekdays,
    required this.onActivityChanged,
    required this.onGymDaysChanged,
    required this.onDurationChanged,
    required this.onWeekdayToggled,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Workout Schedule',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 20),
          ..._PreferencesPage._activityLabels.entries.map(
            (entry) => _ActivityTile(
              label: entry.value,
              selected: activity == entry.key,
              onTap: () => onActivityChanged(entry.key),
            ),
          ),
          _SliderField(
            label: 'Gym days/week: $gymDaysPerWeek',
            value: gymDaysPerWeek.toDouble(),
            min: 3,
            max: 6,
            divisions: 3,
            onChanged: (value) => onGymDaysChanged(value.round()),
          ),
          _SliderField(
            label: 'Preferred duration: $preferredDurationMinutes min',
            value: preferredDurationMinutes.toDouble(),
            min: 30,
            max: 90,
            divisions: 4,
            onChanged: (value) => onDurationChanged(value.round()),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map(
                  (day) => FilterChip(
                    label: Text(day),
                    selected: preferredWeekdays.contains(day),
                    onSelected: (_) => onWeekdayToggled(day),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          GradientButton(
              onPressed: onNext, child: const Text('Create Workout Plan')),
          TextButton(
              onPressed: onSkip, child: const Text('Skip workout creation')),
        ],
      ),
    );
  }
}

class _WorkoutPriorityPage extends StatelessWidget {
  final Set<String> muscleEmphases;
  final TextEditingController preferredExercisesCtrl;
  final void Function(String) onMuscleToggled;
  final VoidCallback onSkip;
  final VoidCallback onFinish;

  const _WorkoutPriorityPage({
    required this.muscleEmphases,
    required this.preferredExercisesCtrl,
    required this.onMuscleToggled,
    required this.onSkip,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    const muscles = ['Legs', 'Chest', 'Back', 'Shoulders', 'Arms', 'Core'];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Workout Priorities',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Select priority muscles or leave none selected.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          ...muscles.map(
            (muscle) => SwitchListTile(
              value: muscleEmphases.contains(muscle),
              onChanged: (_) => onMuscleToggled(muscle),
              title: Text(muscle),
            ),
          ),
          _PreferenceTextField(
            controller: preferredExercisesCtrl,
            label: 'Preferred exercises',
            hint: 'Squat, bench press, row',
          ),
          const SizedBox(height: 24),
          AppCard(
            child: Text(
              'Fuel will save a recommended split with exercise order, sets, and rep ranges based on these choices.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 18),
          GradientButton(onPressed: onFinish, child: const Text('Enter Fuel')),
          TextButton(onPressed: onSkip, child: const Text('Skip')),
        ],
      ),
    );
  }
}

class _PreferencesPage extends StatelessWidget {
  final ActivityBaseline activity;
  final Set<String> allergies;
  final List<String> commonAllergies;
  final TextEditingController preferredFoodsCtrl;
  final TextEditingController pantryFoodsCtrl;
  final TextEditingController avoidedFoodsCtrl;
  final TextEditingController preferredExercisesCtrl;
  final String dietStyle;
  final int cookingTimeMinutes;
  final int gymDaysPerWeek;
  final int preferredDurationMinutes;
  final Set<String> preferredWeekdays;
  final Set<String> muscleEmphases;
  final bool usesGlp1;
  final void Function(ActivityBaseline) onActivityChanged;
  final void Function(String) onAllergyToggled;
  final void Function(String) onDietStyleChanged;
  final void Function(int) onCookingTimeChanged;
  final void Function(int) onGymDaysChanged;
  final void Function(int) onDurationChanged;
  final void Function(String) onWeekdayToggled;
  final void Function(String) onMuscleToggled;
  final void Function(bool) onGlp1Changed;
  final VoidCallback onFinish;

  const _PreferencesPage({
    required this.activity,
    required this.allergies,
    required this.commonAllergies,
    required this.preferredFoodsCtrl,
    required this.pantryFoodsCtrl,
    required this.avoidedFoodsCtrl,
    required this.preferredExercisesCtrl,
    required this.dietStyle,
    required this.cookingTimeMinutes,
    required this.gymDaysPerWeek,
    required this.preferredDurationMinutes,
    required this.preferredWeekdays,
    required this.muscleEmphases,
    required this.usesGlp1,
    required this.onActivityChanged,
    required this.onAllergyToggled,
    required this.onDietStyleChanged,
    required this.onCookingTimeChanged,
    required this.onGymDaysChanged,
    required this.onDurationChanged,
    required this.onWeekdayToggled,
    required this.onMuscleToggled,
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
          Text(
            'Activity',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 28),
          Text(
            'Activity baseline',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          ..._activityLabels.entries.map(
            (entry) => _ActivityTile(
              label: entry.value,
              selected: activity == entry.key,
              onTap: () => onActivityChanged(entry.key),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Allergies / restrictions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
          Text(
            'Food preferences',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _PreferenceTextField(
            controller: preferredFoodsCtrl,
            label: 'Preferred foods',
            hint: 'Rice, eggs, banana',
          ),
          _PreferenceTextField(
            controller: pantryFoodsCtrl,
            label: 'Pantry / available foods',
            hint: 'Oats, rice, chicken',
          ),
          _PreferenceTextField(
            controller: avoidedFoodsCtrl,
            label: 'Avoided foods',
            hint: 'Foods you dislike or avoid',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: dietStyle,
            decoration: const InputDecoration(labelText: 'Current diet style'),
            items: const ['Balanced', 'High-carb', 'High-protein', 'Vegetarian']
                .map(
                  (style) => DropdownMenuItem(value: style, child: Text(style)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onDietStyleChanged(value);
            },
          ),
          _SliderField(
            label: 'Cooking time: $cookingTimeMinutes min/meal',
            value: cookingTimeMinutes.toDouble(),
            min: 0,
            max: 45,
            divisions: 9,
            onChanged: (value) => onCookingTimeChanged(value.round()),
          ),
          const SizedBox(height: 24),
          Text('Workout setup', style: Theme.of(context).textTheme.titleLarge),
          _SliderField(
            label: 'Gym days/week: $gymDaysPerWeek',
            value: gymDaysPerWeek.toDouble(),
            min: 3,
            max: 6,
            divisions: 3,
            onChanged: (value) => onGymDaysChanged(value.round()),
          ),
          _SliderField(
            label: 'Preferred duration: $preferredDurationMinutes min',
            value: preferredDurationMinutes.toDouble(),
            min: 30,
            max: 90,
            divisions: 4,
            onChanged: (value) => onDurationChanged(value.round()),
          ),
          const SizedBox(height: 8),
          _SectionLabel('Training days'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map(
                  (day) => FilterChip(
                    label: Text(day),
                    selected: preferredWeekdays.contains(day),
                    onSelected: (_) => onWeekdayToggled(day),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          _SectionLabel('Muscle emphases'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['Legs', 'Chest', 'Back', 'Shoulders', 'Arms', 'Core']
                .map(
                  (muscle) => FilterChip(
                    label: Text(muscle),
                    selected: muscleEmphases.contains(muscle),
                    onSelected: (_) => onMuscleToggled(muscle),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          _PreferenceTextField(
            controller: preferredExercisesCtrl,
            label: 'Preferred exercises',
            hint: 'Squat, bench press, row',
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
                      Text(
                        'I use a GLP-1 medication',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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
            child: const Text('Start Fuel'),
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

class _PreferenceTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _PreferenceTextField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, hintText: hint),
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
