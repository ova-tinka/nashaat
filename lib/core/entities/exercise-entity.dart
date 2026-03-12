import 'enums.dart';

class ExerciseEntity {
  final String id;
  final String name;
  final String? description;
  final String? muscleGroup;
  final ExerciseMeasurement measurementType;
  final String? mediaId;
  final bool isSystem;
  final DateTime createdAt;

  const ExerciseEntity({
    required this.id,
    required this.name,
    this.description,
    this.muscleGroup,
    this.measurementType = ExerciseMeasurement.repsWeight,
    this.mediaId,
    this.isSystem = true,
    required this.createdAt,
  });
}
