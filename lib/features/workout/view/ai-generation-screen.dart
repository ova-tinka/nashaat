import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/workout-plan-entity.dart';
import '../../../infra/repository-locator.dart';
import '../../../shared/design/atoms/app-badge.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-chip.dart';
import '../../../shared/design/atoms/app-divider.dart';
import '../../../shared/design/molecules/app-section-header.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
import '../../../shared/logger.dart';
import '../../../core/entities/enums.dart';
import '../model/workout-models.dart';

/// Entry point for AI workout generation.
class AiGenerationScreen extends StatefulWidget {
  const AiGenerationScreen({super.key});

  @override
  State<AiGenerationScreen> createState() => _AiGenerationScreenState();
}

class _AiGenerationScreenState extends State<AiGenerationScreen> {
  final _formKey = GlobalKey<FormState>();

  String _goals = '';
  String _trainingStyle = 'Strength';
  final List<String> _focusAreas = [];
  int _minutesPerSession = 45;
  int _sessionsPerWeek = 3;
  final List<String> _equipment = [];
  String _intensity = 'Medium';
  String _experience = 'intermediate';

  bool _isGenerating = false;
  String? _error;

  static const _trainingStyles = [
    'Strength', 'Cardio', 'HIIT', 'Yoga', 'Calisthenics', 'Mixed',
  ];

  static const _intensities = ['Low', 'Medium', 'High'];
  static const _experiences = ['beginner', 'intermediate', 'advanced'];

  static const _muscleGroups = [
    'Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Legs', 'Core', 'Full Body',
  ];

  static const _equipmentOptions = [
    'None (bodyweight)', 'Dumbbells', 'Barbell',
    'Resistance Bands', 'Pull-up Bar', 'Gym Machines',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(
          'AI GENERATION',
          style: AppTypography.sectionHeader.copyWith(fontSize: 13, letterSpacing: 2),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.base),
            child: Center(child: AppBadge.acid('VIP')),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: AppDivider(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, 120,
          ),
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base, vertical: 10,
                ),
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.errorMuted,
                  border: Border.all(color: AppColors.error),
                ),
                child: Text(_error!, style: AppTypography.body.copyWith(color: AppColors.error)),
              ),

            AppSectionHeader('Your Goals', padding: const EdgeInsets.only(top: 8, bottom: 8)),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'What do you want to achieve?',
                hintText: 'e.g. Build muscle, improve endurance, lose weight',
              ),
              style: AppTypography.body,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Please describe your goals' : null,
              onChanged: (v) => _goals = v,
            ),
            const SizedBox(height: AppSpacing.base),

            AppSectionHeader('Training Style', padding: const EdgeInsets.only(top: 8, bottom: 8)),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _trainingStyles.map((s) {
                return AppSelectChip(
                  label: s,
                  selected: _trainingStyle == s,
                  onTap: () => setState(() => _trainingStyle = s),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.base),

            AppSectionHeader('Focus Areas (optional)', padding: const EdgeInsets.only(top: 8, bottom: 8)),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _muscleGroups.map((g) {
                return AppSelectChip(
                  label: g,
                  selected: _focusAreas.contains(g),
                  onTap: () => setState(() {
                    if (_focusAreas.contains(g)) {
                      _focusAreas.remove(g);
                    } else {
                      _focusAreas.add(g);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.base),

            AppSectionHeader('Session Settings', padding: const EdgeInsets.only(top: 8, bottom: 8)),
            Row(
              children: [
                Expanded(
                  child: _StepperField(
                    label: 'Min / session',
                    value: _minutesPerSession,
                    min: 15,
                    max: 120,
                    step: 5,
                    onChanged: (v) => setState(() => _minutesPerSession = v),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _StepperField(
                    label: 'Sessions / week',
                    value: _sessionsPerWeek,
                    min: 1,
                    max: 7,
                    step: 1,
                    onChanged: (v) => setState(() => _sessionsPerWeek = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.base),

            AppSectionHeader('Available Equipment', padding: const EdgeInsets.only(top: 8, bottom: 8)),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _equipmentOptions.map((e) {
                return AppSelectChip(
                  label: e,
                  selected: _equipment.contains(e),
                  onTap: () => setState(() {
                    if (_equipment.contains(e)) {
                      _equipment.remove(e);
                    } else {
                      _equipment.add(e);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.base),

            AppSectionHeader('Intensity', padding: const EdgeInsets.only(top: 8, bottom: 8)),
            Row(
              children: _intensities.map((i) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: AppSelectChip(
                    label: i,
                    selected: _intensity == i,
                    onTap: () => setState(() => _intensity = i),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.base),

            AppSectionHeader('Experience Level', padding: const EdgeInsets.only(top: 8, bottom: 8)),
            Row(
              children: _experiences.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: AppSelectChip(
                    label: e[0].toUpperCase() + e.substring(1),
                    selected: _experience == e,
                    onTap: () => setState(() => _experience = e),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: AppButton.acid(
            _isGenerating ? 'Generating...' : 'Generate Workout Plan',
            isLoading: _isGenerating,
            onPressed: _isGenerating ? null : _generate,
            width: double.infinity,
            icon: _isGenerating ? null : Icons.auto_awesome,
          ),
        ),
      ),
    );
  }

  Future<void> _generate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState!.save();

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final input = AiWorkoutInput(
        goals: _goals,
        trainingStyle: _trainingStyle,
        focusAreas: _focusAreas,
        minutesPerSession: _minutesPerSession,
        sessionsPerWeek: _sessionsPerWeek,
        equipment: _equipment,
        intensity: _intensity,
        experienceLevel: _experience,
      );

      final plan = await _generatePlan(input);

      if (mounted) Navigator.pop(context, plan);
    } catch (e) {
      Log.error('AiGenerationScreen', e);
      setState(() {
        _error = 'Generation failed. Please try again.';
        _isGenerating = false;
      });
    }
  }

  Future<WorkoutPlanEntity> _generatePlan(AiWorkoutInput input) async {
    // Placeholder AI generation — produces a structured plan from the input.
    // Replace with actual AI API call when integrating a service.
    await Future.delayed(const Duration(seconds: 2));

    final userId = Supabase.instance.client.auth.currentUser!.id;
    final exercises = _buildExercisesForInput(input);
    final scheduledDays = _buildSchedule(input.sessionsPerWeek);

    final plan = WorkoutPlanEntity(
      id: '',
      userId: userId,
      title: '${input.trainingStyle} – ${input.experienceLevel[0].toUpperCase()}${input.experienceLevel.substring(1)}',
      description:
          'AI-generated ${input.trainingStyle.toLowerCase()} plan. ${input.minutesPerSession} min/session, ${input.sessionsPerWeek}x/week. Goals: ${input.goals}.',
      source: WorkoutSource.aiGenerated,
      scheduledDays: scheduledDays,
      exercises: exercises,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final repo = RepositoryLocator.instance.workoutPlan;
    return repo.createPlan(plan);
  }

  List<WorkoutPlanExercise> _buildExercisesForInput(AiWorkoutInput input) {
    final exercises = <WorkoutPlanExercise>[];

    final Map<String, List<String>> styleExercises = {
      'Strength': ['Bench Press', 'Squat', 'Deadlift', 'Overhead Press', 'Barbell Row'],
      'Cardio': ['Running', 'Cycling', 'Jump Rope', 'Rowing', 'Stair Climber'],
      'HIIT': ['Burpees', 'Mountain Climbers', 'Jump Squats', 'High Knees', 'Box Jumps'],
      'Yoga': ['Sun Salutation', 'Warrior Pose', 'Downward Dog', 'Plank Hold', 'Child Pose'],
      'Calisthenics': ['Push-ups', 'Pull-ups', 'Dips', 'Pistol Squats', 'L-Sit'],
      'Mixed': ['Push-ups', 'Squats', 'Plank', 'Lunges', 'Dumbbell Rows'],
    };

    final names = styleExercises[input.trainingStyle] ?? styleExercises['Mixed']!;

    for (final name in names) {
      exercises.add(WorkoutPlanExercise(
        exerciseId: 'ai_${name.toLowerCase().replaceAll(' ', '_')}',
        exerciseName: name,
        sets: input.experienceLevel == 'beginner' ? 2 : 3,
        reps: 10,
        restSeconds: input.intensity == 'High' ? 30 : 60,
      ));
    }

    return exercises;
  }

  List<int> _buildSchedule(int sessionsPerWeek) {
    const allDays = [1, 2, 3, 4, 5, 6, 7];
    if (sessionsPerWeek >= 7) return allDays;
    final step = 7 / sessionsPerWeek;
    return List.generate(
      sessionsPerWeek,
      (i) => allDays[(i * step).floor()],
    )..sort();
  }
}

class _StepperField extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _StepperField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.paperBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.labelMuted),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, color: AppColors.ink, size: 18),
                onPressed: value > min ? () => onChanged(value - step) : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              Text(
                '$value',
                style: AppTypography.monoStrong.copyWith(fontSize: 18),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.ink, size: 18),
                onPressed: value < max ? () => onChanged(value + step) : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
