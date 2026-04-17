import '../../core/entities/enums.dart';
import '../../core/entities/media-entity.dart';
import '../../core/repositories/media-repository.dart';
import '../../shared/logger.dart';
import 'supabase-client.dart';

class SupabaseMediaRepository implements MediaRepository {
  final _db = SupabaseClientProvider.client;

  @override
  Future<MediaEntity> uploadMedia(
    String userId,
    String storagePath, {
    String? fileName,
    String? mimeType,
    int? sizeBytes,
    MediaType type = MediaType.image,
  }) async {
    Log.db('saving media metadata: $storagePath');
    final data = await _db
        .from('media')
        .insert({
          'user_id': userId,
          'storage_path': storagePath,
          'file_name': ?fileName,
          'mime_type': ?mimeType,
          'size_bytes': ?sizeBytes,
          'type': _typeToString(type),
        })
        .select()
        .single();
    return _fromMap(data);
  }

  @override
  Future<MediaEntity?> getMedia(String mediaId) async {
    final data = await _db
        .from('media')
        .select()
        .eq('id', mediaId)
        .maybeSingle();
    if (data == null) return null;
    return _fromMap(data);
  }

  @override
  Future<void> deleteMedia(String mediaId) async {
    Log.db('deleting media metadata: $mediaId');
    await _db.from('media').delete().eq('id', mediaId);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  MediaEntity _fromMap(Map<String, dynamic> map) => MediaEntity(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        storagePath: map['storage_path'] as String,
        fileName: map['file_name'] as String?,
        mimeType: map['mime_type'] as String?,
        sizeBytes: map['size_bytes'] as int?,
        type: _parseType(map['type'] as String? ?? 'image'),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  MediaType _parseType(String s) => switch (s) {
        'video' => MediaType.video,
        'document' => MediaType.document,
        _ => MediaType.image,
      };

  String _typeToString(MediaType t) => switch (t) {
        MediaType.image => 'image',
        MediaType.video => 'video',
        MediaType.document => 'document',
      };
}
