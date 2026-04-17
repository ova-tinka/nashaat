import 'enums.dart';

class ExerciseEntity {
  final String id;
  final String name;
  final String? description;
  final List<String> muscleGroups;
  final List<String> steps;
  final DifficultyLevel difficultyLevel;
  final ExerciseMeasurement measurementType;
  final String? mediaId;
  final bool isSystem;
  final DateTime createdAt;

  const ExerciseEntity({
    required this.id,
    required this.name,
    this.description,
    this.muscleGroups = const [],
    this.steps = const [],
    this.difficultyLevel = DifficultyLevel.medium,
    this.measurementType = ExerciseMeasurement.repsWeight,
    this.mediaId,
    this.isSystem = true,
    required this.createdAt,
  });

  ExerciseEntity copyWith({
    String? name,
    String? description,
    List<String>? muscleGroups,
    List<String>? steps,
    DifficultyLevel? difficultyLevel,
    ExerciseMeasurement? measurementType,
    String? mediaId,
    bool? isSystem,
  }) {
    return ExerciseEntity(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      muscleGroups: muscleGroups ?? this.muscleGroups,
      steps: steps ?? this.steps,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      measurementType: measurementType ?? this.measurementType,
      mediaId: mediaId ?? this.mediaId,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt,
    );
  }
}
