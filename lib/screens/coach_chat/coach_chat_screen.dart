import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/food_log.dart';
import '../../models/fuel_prescription.dart';
import '../../models/metabolic_state.dart';
import '../../models/training_session.dart';
import '../../models/user_profile.dart';
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
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<CoachChatMessage> _messages = [];
  bool _isSending = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
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
                          const _EmptyCoachState()
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
  const _EmptyCoachState();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(18),
      child: Text(
        'Ready when you are.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.gray600, fontSize: 15),
      ),
    );
  }
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
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? Colors.white : AppTheme.gray700,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ),
    );
  }
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
  final bool enabled;
  final VoidCallback onSend;

  const _CoachInputBar({
    required this.controller,
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
    'recent_food_logs': _recentFoods(state.foodLogs, now),
    'upcoming_sessions': _upcomingSessions(state.sessions, now),
    'recent_sessions': _recentSessions(state.sessions, now),
  };
}

Map<String, dynamic>? _profileMetrics(UserProfile? profile) {
  if (profile == null) return null;
  return {
    'age_years': profile.ageYears,
    'sex': profile.sex.name,
    'height_cm': profile.heightCm,
    'weight_kg': profile.weightKg,
    'activity_baseline': profile.activityBaseline.name,
    'uses_glp1': profile.usesGlp1,
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
    'timing': prescription.timing.name,
    'headline': prescription.headline,
    'summary': prescription.summary,
    'target_carbs_g': prescription.targetCarbsG,
    'target_protein_g': prescription.targetProteinG,
    'urgent_refuel': prescription.urgentRefuel,
    'session': _sessionMetrics(prescription.session),
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
    'name': session.displayName,
    'type': session.type.name,
    'planned_at': session.plannedAt.toIso8601String(),
    'duration_minutes': session.durationMinutes,
    'intensity': session.intensity.name,
    'estimated_muscle_glycogen_cost_g': session.estimatedMuscleGlycogenCostG,
    'notes': session.notes,
  };
}
