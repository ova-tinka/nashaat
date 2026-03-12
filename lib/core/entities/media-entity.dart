import 'enums.dart';

class MediaEntity {
  final String id;
  final String userId;
  final String storagePath;
  final String? fileName;
  final String? mimeType;
  final int? sizeBytes;
  final MediaType type;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MediaEntity({
    required this.id,
    required this.userId,
    required this.storagePath,
    this.fileName,
    this.mimeType,
    this.sizeBytes,
    this.type = MediaType.image,
    required this.createdAt,
    required this.updatedAt,
  });
}
