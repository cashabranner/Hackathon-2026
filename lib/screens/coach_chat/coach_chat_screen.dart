import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/food_log.dart';
import '../../models/fuel_prescription.dart';
import '../../models/metabolic_state.dart';
import '../../models/training_session.dart';
import '../../models/user_profile.dart';
import '../../models/workout_split.dart';
import '../../repositories/app_state.dart';
import '../../services/coach_chat_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

class CoachChatScreen extends StatefulWidget {
  const CoachChatScreen({super.key});

  @override
  State<CoachChatScreen> createState() => _CoachChatScreenState();
}

class _CoachChatScreenState extends State<CoachChatScreen> {
  static const List<_CoachPromptCategory> _promptCategories = [
    _CoachPromptCategory(
      label: 'Muscle & performance',
      prompts: [
        _CoachPresetPrompt(
          label: 'Muscle % up',
          prompt: 'How to get my muscle % up?',
        ),
        _CoachPresetPrompt(
          label: 'Performance boost',
          prompt: 'Based on my current stats, what should I change this week?',
        ),
      ],
    ),
    _CoachPromptCategory(
      label: 'Workout fueling',
      prompts: [
        _CoachPresetPrompt(
          label: 'Pre-workout fuel',
          prompt: 'What should I eat 60-90 minutes before my next workout?',
        ),
        _CoachPresetPrompt(
          label: 'Post-workout refuel',
          prompt: 'How should I refuel after today\'s session?',
        ),
      ],
    ),
    _CoachPromptCategory(
      label: 'Plan adjustments',
      prompts: [
        _CoachPresetPrompt(
          label: 'Food plan review',
          prompt:
              'Can you review my current food plan and macros for this week?',
        ),
        _CoachPresetPrompt(
          label: 'Rest vs training',
          prompt:
              'How should I adjust nutrition on rest days vs training days?',
        ),
      ],
    ),
  ];

  final _inputCtrl = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollCtrl = ScrollController();
  final List<CoachChatMessage> _messages = [];
  bool _isSending = false;
  int? _selectedCategoryIndex;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    if (!AppConfig.hasCoachChat) {
      _showSnack('Coach endpoint is not configured.');
      return;
    }

    final appState = context.read<AppState>();
    final userMessage = CoachChatMessage(
      role: CoachChatRole.user,
      content: text,
    );

    setState(() {
      _messages.add(userMessage);
      _isSending = true;
      _inputCtrl.clear();
    });
    _scrollToBottom();

    try {
      final reply = await CoachChatService.sendMessage(
        coachChatUrl: AppConfig.coachChatUrl,
        anonKey: AppConfig.supabaseAnonKey,
        metrics: _metricsFor(appState),
        messages: _messages,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(CoachChatMessage(
          role: CoachChatRole.assistant,
          content: reply,
        ));
      });
    } catch (_) {
      if (!mounted) return;
      _showSnack('Coach chat is unavailable right now.');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  void _sendPresetPrompt(_CoachPresetPrompt prompt) {
    if (_isSending) return;
    _inputCtrl.text = prompt.prompt;
    _send();
  }

  void _selectPromptCategory(int index) {
    if (_isSending) return;
    setState(() => _selectedCategoryIndex = index);
  }

  void _focusManualInput() {
    if (_isSending) return;
    _inputFocusNode.requestFocus();
    _scrollToBottom();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final metabolicState = appState.metabolicState;

    return Scaffold(
      body: GradientShell(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  _CoachHeader(onBack: () => context.pop()),
                  Expanded(
                    child: ListView(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      children: [
                        if (metabolicState != null)
                          _MetricSnapshot(state: metabolicState),
                        const SizedBox(height: 12),
                        if (_messages.isEmpty)
                          _EmptyCoachState(
                            categories: _promptCategories,
                            selectedCategoryIndex: _selectedCategoryIndex,
                            onCategoryTap: _selectPromptCategory,
                            onPromptTap: _sendPresetPrompt,
                            onManualTap: _focusManualInput,
                          )
                        else
                          ..._messages.map((message) => _ChatBubble(
                                message: message,
                              )),
                        if (_isSending) const _ThinkingBubble(),
                      ],
                    ),
                  ),
                  _CoachInputBar(
                    controller: _inputCtrl,
                    focusNode: _inputFocusNode,
                    enabled: !_isSending,
                    onSend: _send,
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

class _CoachHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _CoachHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 14),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: AppTheme.indigo),
          ),
          const Expanded(
            child: Text(
              'AI Coach',
              style: TextStyle(
                color: Color(0xFF312E81),
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(Icons.auto_awesome, color: AppTheme.purple),
        ],
      ),
    );
  }
}

class _MetricSnapshot extends StatelessWidget {
  final MetabolicState state;

  const _MetricSnapshot({required this.state});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          AppPill(
            label: 'Liver ${(state.liverFillPct * 100).round()}%',
            color: AppTheme.teal,
          ),
          AppPill(
            label: 'Muscle ${(state.muscleFillPct * 100).round()}%',
            color: AppTheme.amber,
          ),
          AppPill(
            label: '${state.totalCarbsG.round()}g carbs today',
            color: AppTheme.indigo,
          ),
          AppPill(
            label: _phaseLabel(state.bloodGlucosePhase),
            color: _phaseColor(state.bloodGlucosePhase),
          ),
        ],
      ),
    );
  }

  String _phaseLabel(BloodGlucosePhase phase) => switch (phase) {
        BloodGlucosePhase.fasted => 'Fasted',
        BloodGlucosePhase.stable => 'Stable',
        BloodGlucosePhase.postPrandial => 'Post-meal',
        BloodGlucosePhase.elevated => 'Elevated',
      };

  Color _phaseColor(BloodGlucosePhase phase) => switch (phase) {
        BloodGlucosePhase.fasted => AppTheme.coral,
        BloodGlucosePhase.stable => AppTheme.teal,
        BloodGlucosePhase.postPrandial => AppTheme.amber,
        BloodGlucosePhase.elevated => AppTheme.coral,
      };
}

class _EmptyCoachState extends StatelessWidget {
  final List<_CoachPromptCategory> categories;
  final int? selectedCategoryIndex;
  final ValueChanged<int> onCategoryTap;
  final ValueChanged<_CoachPresetPrompt> onPromptTap;
  final VoidCallback onManualTap;

  const _EmptyCoachState({
    required this.categories,
    required this.selectedCategoryIndex,
    required this.onCategoryTap,
    required this.onPromptTap,
    required this.onManualTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const Text(
            'Ready when you are.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.gray600, fontSize: 15),
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'What type of question do you have?',
              style: TextStyle(
                color: AppTheme.gray500,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: List.generate(categories.length, (index) {
                final category = categories[index];
                final isSelected = selectedCategoryIndex == index;
                return ChoiceChip(
                  label: Text(category.label),
                  selected: isSelected,
                  selectedColor: const Color(0xFFEFF6FF),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? AppTheme.indigo : AppTheme.indigoBorder,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.indigo : AppTheme.gray700,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) => onCategoryTap(index),
                );
              }),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onManualTap,
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Other (type manually)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.gray700,
                side: const BorderSide(color: AppTheme.indigoBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            if (selectedCategoryIndex != null) ...[
              const SizedBox(height: 14),
              const Text(
                'Choose a question',
                style: TextStyle(
                  color: AppTheme.gray500,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children:
                    categories[selectedCategoryIndex!].prompts.map((prompt) {
                  return ActionChip(
                    label: Text(prompt.label),
                    onPressed: () => onPromptTap(prompt),
                    side: const BorderSide(color: AppTheme.indigoBorder),
                    backgroundColor: Colors.white,
                    labelStyle: const TextStyle(
                      color: AppTheme.gray700,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CoachPresetPrompt {
  final String label;
  final String prompt;

  const _CoachPresetPrompt({
    required this.label,
    required this.prompt,
  });
}

class _CoachPromptCategory {
  final String label;
  final List<_CoachPresetPrompt> prompts;

  const _CoachPromptCategory({
    required this.label,
    required this.prompts,
  });
}

class _ChatBubble extends StatelessWidget {
  final CoachChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == CoachChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.teal : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isUser ? Colors.transparent : AppTheme.indigoBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: isUser
            ? Text(
                message.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.45,
                ),
              )
            : _AssistantMessageContent(content: message.content),
      ),
    );
  }
}

class _AssistantMessageContent extends StatelessWidget {
  final String content;

  const _AssistantMessageContent({required this.content});

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      color: AppTheme.gray700,
      fontSize: 15,
      height: 1.45,
    );
    final headingStyle = baseStyle.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: AppTheme.indigo,
      height: 1.35,
    );
    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.w700);

    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final children = <Widget>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        children.add(const SizedBox(height: 8));
        continue;
      }

      final isBullet = line.startsWith('* ') || line.startsWith('- ');
      if (isBullet) {
        final bulletBody = line.substring(2).trim();
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: baseStyle),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: baseStyle,
                      children: _inlineMarkdownSpans(
                        bulletBody,
                        baseStyle: baseStyle,
                        boldStyle: boldStyle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      final normalized = line.replaceAll('**', '');
      final isHeading = (line.startsWith('**') && line.endsWith('**')) ||
          (normalized.endsWith(':') && normalized.length <= 80);
      final style = isHeading ? headingStyle : baseStyle;
      final emphasisStyle = isHeading
          ? headingStyle.copyWith(fontWeight: FontWeight.w800)
          : boldStyle;

      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RichText(
            text: TextSpan(
              style: style,
              children: _inlineMarkdownSpans(
                line,
                baseStyle: style,
                boldStyle: emphasisStyle,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

List<InlineSpan> _inlineMarkdownSpans(
  String text, {
  required TextStyle baseStyle,
  required TextStyle boldStyle,
}) {
  final spans = <InlineSpan>[];
  var remaining = text;
  var isBold = false;

  while (remaining.isNotEmpty) {
    final markerIndex = remaining.indexOf('**');
    if (markerIndex == -1) {
      spans.add(TextSpan(
        text: remaining,
        style: isBold ? boldStyle : baseStyle,
      ));
      break;
    }

    if (markerIndex > 0) {
      spans.add(TextSpan(
        text: remaining.substring(0, markerIndex),
        style: isBold ? boldStyle : baseStyle,
      ));
    }

    isBold = !isBold;
    remaining = remaining.substring(markerIndex + 2);
  }

  return spans;
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: AppPill(label: 'Thinking...', color: AppTheme.purple),
      ),
    );
  }
}

class _CoachInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSend;

  const _CoachInputBar({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.indigoBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => enabled ? onSend() : null,
              decoration: const InputDecoration(
                hintText: 'Ask about fueling, timing, or recovery',
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.send),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.teal,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.gray200,
              disabledForegroundColor: AppTheme.gray500,
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _metricsFor(AppState state) {
  final now = state.now;
  return {
    'generated_at': now.toIso8601String(),
    'profile': _profileMetrics(state.profile),
    'metabolic_state': _metabolicMetrics(state.metabolicState),
    'prescription': _prescriptionMetrics(state.prescription),
    'workout_splits': _workoutSplitMetrics(state.workoutSplits),
    'current_workout_split': _currentWorkoutSplitMetrics(
      state.nextSession,
      state.workoutSplits,
    ),
    'stats_summary': _statsSummary(state),
    'recent_food_logs': _recentFoods(state.foodLogs, now),
    'upcoming_sessions': _upcomingSessions(state.sessions, now),
    'recent_sessions': _recentSessions(state.sessions, now),
  };
}

Map<String, dynamic>? _profileMetrics(UserProfile? profile) {
  if (profile == null) return null;
  final heightM = profile.heightCm / 100;
  final bmi = heightM > 0 ? profile.weightKg / (heightM * heightM) : null;
  return {
    'user_id': profile.id,
    'name': profile.name,
    'age_years': profile.ageYears,
    'sex': profile.sex.name,
    'height_cm': profile.heightCm,
    'weight_kg': profile.weightKg,
    'bmi': bmi,
    'activity_multiplier': profile.activityMultiplier,
    'activity_baseline': profile.activityBaseline.name,
    'uses_glp1': profile.usesGlp1,
    'member_since': profile.createdAt.toIso8601String(),
    'allergies': profile.allergies,
  };
}

Map<String, dynamic>? _metabolicMetrics(MetabolicState? state) {
  if (state == null) return null;
  return {
    'as_of': state.asOf.toIso8601String(),
    'liver_glycogen_g': state.liverGlycogenG,
    'liver_capacity_g': state.liverCapacityG,
    'liver_fill_pct': state.liverFillPct,
    'muscle_glycogen_g': state.muscleGlycogenG,
    'muscle_capacity_g': state.muscleCapacityG,
    'muscle_fill_pct': state.muscleFillPct,
    'blood_glucose_phase': state.bloodGlucosePhase.name,
    'total_carbs_g': state.totalCarbsG,
    'total_protein_g': state.totalProteinG,
    'total_fat_g': state.totalFatG,
    'total_calories': state.totalCalories,
    'total_fiber_g': state.totalFiberG,
  };
}

Map<String, dynamic>? _prescriptionMetrics(FuelPrescription? prescription) {
  if (prescription == null) return null;
  return {
    'user_id': prescription.userId,
    'generated_at': prescription.generatedAt.toIso8601String(),
    'timing': prescription.timing.name,
    'headline': prescription.headline,
    'summary': prescription.summary,
    'why_explanation': prescription.whyExplanation,
    'target_carbs_g': prescription.targetCarbsG,
    'target_protein_g': prescription.targetProteinG,
    'urgent_refuel': prescription.urgentRefuel,
    'session': _sessionMetrics(prescription.session),
    'pre_lift_meals': prescription.preLiftMeals
        .map((item) => _fuelItemMetrics(item))
        .toList(),
    'during_lift_fuels': prescription.duringLiftFuels
        .map((item) => _fuelItemMetrics(item))
        .toList(),
    'post_lift_meals': prescription.postLiftMeals
        .map((item) => _fuelItemMetrics(item))
        .toList(),
  };
}

Map<String, dynamic> _fuelItemMetrics(FuelItem item) {
  return {
    'name': item.name,
    'carbs_g': item.carbsG,
    'protein_g': item.proteinG,
    'fat_g': item.fatG,
    'rationale': item.rationale,
  };
}

List<Map<String, dynamic>> _recentFoods(List<FoodLog> logs, DateTime now) {
  final cutoff = now.subtract(const Duration(hours: 24));
  final sorted = logs
      .where((log) => log.loggedAt.isAfter(cutoff) || log.loggedAt == cutoff)
      .toList()
    ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
  return sorted.take(8).map((log) {
    final n = log.nutrition;
    return {
      'food_name': n.foodName,
      'raw_input': log.rawInput,
      'logged_at': log.loggedAt.toIso8601String(),
      'source': log.source,
      'carbs_g': n.carbsG,
      'protein_g': n.proteinG,
      'fat_g': n.fatG,
      'fiber_g': n.fiberG,
      'calories': n.calories,
    };
  }).toList();
}

List<Map<String, dynamic>> _upcomingSessions(
  List<TrainingSession> sessions,
  DateTime now,
) {
  final upcoming = sessions.where((s) => s.plannedAt.isAfter(now)).toList()
    ..sort((a, b) => a.plannedAt.compareTo(b.plannedAt));
  return upcoming.take(4).map(_sessionMetrics).toList();
}

List<Map<String, dynamic>> _recentSessions(
  List<TrainingSession> sessions,
  DateTime now,
) {
  final recent = sessions.where((s) => s.plannedAt.isBefore(now)).toList()
    ..sort((a, b) => b.plannedAt.compareTo(a.plannedAt));
  return recent.take(4).map(_sessionMetrics).toList();
}

Map<String, dynamic> _sessionMetrics(TrainingSession session) {
  return {
    'id': session.id,
    'name': session.displayName,
    'type': session.type.name,
    'planned_at': session.plannedAt.toIso8601String(),
    'duration_minutes': session.durationMinutes,
    'intensity': session.intensity.name,
    'estimated_muscle_glycogen_cost_g': session.estimatedMuscleGlycogenCostG,
    'notes': session.notes,
    'custom_split_id': session.customSplitId,
  };
}

List<Map<String, dynamic>> _workoutSplitMetrics(List<WorkoutSplit> splits) {
  return splits.map<Map<String, dynamic>>((split) {
    return {
      'id': split.id,
      'name': split.name,
      'muscles': split.muscles,
      'exercises': split.exercises.map<Map<String, dynamic>>((exercise) {
        return {
          'name': exercise.name,
          'muscles': exercise.muscles,
          'sets': exercise.sets,
          'reps': exercise.reps,
        };
      }).toList(),
    };
  }).toList();
}

Map<String, dynamic>? _currentWorkoutSplitMetrics(
  TrainingSession? nextSession,
  List<WorkoutSplit> splits,
) {
  final splitId = nextSession?.customSplitId;
  if (splitId == null) return null;

  WorkoutSplit? matched;
  for (final split in splits) {
    if (split.id == splitId) {
      matched = split;
      break;
    }
  }
  if (matched == null) return null;

  return {
    'id': matched.id,
    'name': matched.name,
    'muscles': matched.muscles,
    'exercise_count': matched.exercises.length,
  };
}

Map<String, dynamic> _statsSummary(AppState state) {
  final metabolic = state.metabolicState;
  final now = state.now;
  final dayStart = DateTime(now.year, now.month, now.day);
  final todaysFoods = state.foodLogs.where((log) {
    final loggedAt = log.loggedAt;
    return !loggedAt.isBefore(dayStart) && !loggedAt.isAfter(now);
  }).toList();

  double carbs = 0;
  double protein = 0;
  double fat = 0;
  double calories = 0;
  double fiber = 0;
  for (final log in todaysFoods) {
    carbs += log.nutrition.carbsG;
    protein += log.nutrition.proteinG;
    fat += log.nutrition.fatG;
    calories += log.nutrition.calories;
    fiber += log.nutrition.fiberG;
  }

  return {
    'food_logs_today_count': todaysFoods.length,
    'sessions_planned_count': state.sessions.length,
    'workout_splits_count': state.workoutSplits.length,
    'muscle_fill_pct': metabolic?.muscleFillPct,
    'liver_fill_pct': metabolic?.liverFillPct,
    'blood_glucose_phase': metabolic?.bloodGlucosePhase.name,
    'todays_carbs_g': carbs,
    'todays_protein_g': protein,
    'todays_fat_g': fat,
    'todays_fiber_g': fiber,
    'todays_calories': calories,
  };
}
