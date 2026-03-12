import '../entities/enums.dart';
import '../entities/media-entity.dart';

abstract class MediaRepository {
  Future<MediaEntity> uploadMedia(
    String userId,
    String storagePath, {
    String? fileName,
    String? mimeType,
    int? sizeBytes,
    MediaType type = MediaType.image,
  });

  Future<MediaEntity?> getMedia(String mediaId);

  Future<void> deleteMedia(String mediaId);
}
