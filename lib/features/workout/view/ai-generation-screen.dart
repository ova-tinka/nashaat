import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/workout-plan-entity.dart';
import '../../../infra/repository-locator.dart';
import '../../../shared/logger.dart';
import '../model/workout-models.dart';

/// Entry point for AI workout generation.
///
/// Collects user preferences, calls the AI service boundary, and returns
/// a [WorkoutPlanEntity] via Navigator.pop for the caller to save.
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
    'Strength',
    'Cardio',
    'HIIT',
    'Yoga',
    'Calisthenics',
    'Mixed',
  ];

  static const _intensities = ['Low', 'Medium', 'High'];

  static const _experiences = ['beginner', 'intermediate', 'advanced'];

  static const _muscleGroups = [
    'Chest',
    'Back',
    'Shoulders',
    'Biceps',
    'Triceps',
    'Legs',
    'Core',
    'Full Body',
  ];

  static const _equipmentOptions = [
    'None (bodyweight)',
    'Dumbbells',
    'Barbell',
    'Resistance Bands',
    'Pull-up Bar',
    'Gym Machines',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate with AI'),
        actions: [
          Chip(
            avatar: Icon(Icons.auto_awesome, size: 16, color: cs.onTertiaryContainer),
            label: const Text('VIP'),
            backgroundColor: cs.tertiaryContainer,
            labelStyle: TextStyle(
              color: cs.onTertiaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!,
                    style: TextStyle(color: cs.onErrorContainer)),
              ),

            _SectionTitle(title: 'Your Goals'),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'What do you want to achieve?',
                hintText: 'e.g. Build muscle, improve endurance, lose weight',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Please describe your goals' : null,
              onChanged: (v) => _goals = v,
            ),
            const SizedBox(height: 16),

            _SectionTitle(title: 'Training Style'),
            Wrap(
              spacing: 8,
              children: _trainingStyles.map((s) {
                final selected = _trainingStyle == s;
                return FilterChip(
                  label: Text(s),
                  selected: selected,
                  onSelected: (_) => setState(() => _trainingStyle = s),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            _SectionTitle(title: 'Focus Areas (optional)'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _muscleGroups.map((g) {
                final selected = _focusAreas.contains(g);
                return FilterChip(
                  label: Text(g),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _focusAreas.add(g);
                    } else {
                      _focusAreas.remove(g);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            _SectionTitle(title: 'Session Settings'),
            Row(
              children: [
                Expanded(
                  child: _StepperField(
                    label: 'Minutes / session',
                    value: _minutesPerSession,
                    min: 15,
                    max: 120,
                    step: 5,
                    onChanged: (v) => setState(() => _minutesPerSession = v),
                  ),
                ),
                const SizedBox(width: 12),
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
            const SizedBox(height: 16),

            _SectionTitle(title: 'Available Equipment'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _equipmentOptions.map((e) {
                final selected = _equipment.contains(e);
                return FilterChip(
                  label: Text(e),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _equipment.add(e);
                    } else {
                      _equipment.remove(e);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            _SectionTitle(title: 'Intensity'),
            SegmentedButton<String>(
              segments: _intensities
                  .map((i) => ButtonSegment(value: i, label: Text(i)))
                  .toList(),
              selected: {_intensity},
              onSelectionChanged: (s) =>
                  setState(() => _intensity = s.first),
            ),
            const SizedBox(height: 16),

            _SectionTitle(title: 'Experience Level'),
            SegmentedButton<String>(
              segments: _experiences
                  .map((e) => ButtonSegment(
                        value: e,
                        label: Text(
                          e[0].toUpperCase() + e.substring(1),
                        ),
                      ))
                  .toList(),
              selected: {_experience},
              onSelectionChanged: (s) =>
                  setState(() => _experience = s.first),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _isGenerating ? null : _generate,
            icon: _isGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
                _isGenerating ? 'Generating…' : 'Generate Workout Plan'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
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

      // AI service boundary — generates a plan from input.
      // When a real AI service is integrated, replace this call.
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
    // Generates a reasonable set of exercises based on style + focus areas.
    // In a real implementation this would come from an AI model.
    final exercises = <WorkoutPlanExercise>[];

    final Map<String, List<String>> styleExercises = {
      'Strength': [
        'Bench Press',
        'Squat',
        'Deadlift',
        'Overhead Press',
        'Barbell Row',
      ],
      'Cardio': [
        'Running',
        'Cycling',
        'Jump Rope',
        'Rowing',
        'Stair Climber',
      ],
      'HIIT': [
        'Burpees',
        'Mountain Climbers',
        'Jump Squats',
        'High Knees',
        'Box Jumps',
      ],
      'Yoga': [
        'Sun Salutation',
        'Warrior Pose',
        'Downward Dog',
        'Plank Hold',
        'Child Pose',
      ],
      'Calisthenics': [
        'Push-ups',
        'Pull-ups',
        'Dips',
        'Pistol Squats',
        'L-Sit',
      ],
      'Mixed': [
        'Push-ups',
        'Squats',
        'Plank',
        'Lunges',
        'Dumbbell Rows',
      ],
    };

    final names = styleExercises[input.trainingStyle] ??
        styleExercises['Mixed']!;

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
    // Spreads sessions evenly through the week.
    const allDays = [1, 2, 3, 4, 5, 6, 7];
    if (sessionsPerWeek >= 7) return allDays;
    final step = 7 / sessionsPerWeek;
    return List.generate(
      sessionsPerWeek,
      (i) => allDays[(i * step).floor()],
    )..sort();
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                visualDensity: VisualDensity.compact,
                onPressed:
                    value > min ? () => onChanged(value - step) : null,
              ),
              Text(
                '$value',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                visualDensity: VisualDensity.compact,
                onPressed:
                    value < max ? () => onChanged(value + step) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
