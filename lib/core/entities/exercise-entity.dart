import 'enums.dart';

class ExerciseEntity {
  final String id;
  final String name;
  final String? description;
  final List<String> muscleGroups;
  final List<String> instructions;
  final DifficultyLevel difficultyLevel;
  final ExerciseMeasurement measurementType;
  final String? mediaId;
  final String? mediaLink;
  final bool isSystem;
  final DateTime createdAt;

  const ExerciseEntity({
    required this.id,
    required this.name,
    this.description,
    this.muscleGroups = const [],
    this.instructions = const [],
    this.difficultyLevel = DifficultyLevel.medium,
    this.measurementType = ExerciseMeasurement.repsWeight,
    this.mediaId,
    this.mediaLink,
    this.isSystem = true,
    required this.createdAt,
  });

  ExerciseEntity copyWith({
    String? name,
    String? description,
    List<String>? muscleGroups,
    List<String>? instructions,
    DifficultyLevel? difficultyLevel,
    ExerciseMeasurement? measurementType,
    String? mediaId,
    String? mediaLink,
    bool? isSystem,
  }) {
    return ExerciseEntity(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      muscleGroups: muscleGroups ?? this.muscleGroups,
      instructions: instructions ?? this.instructions,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      measurementType: measurementType ?? this.measurementType,
      mediaId: mediaId ?? this.mediaId,
      mediaLink: mediaLink ?? this.mediaLink,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt,
    );
  }
}
