import 'enums.dart';

class BlockingRuleEntity {
  final String id;
  final String userId;
  final ItemType itemType;
  /// Package name for apps (e.g. 'com.instagram.android') or domain for websites (e.g. 'youtube.com')
  final String itemIdentifier;
  final RuleStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BlockingRuleEntity({
    required this.id,
    required this.userId,
    required this.itemType,
    required this.itemIdentifier,
    this.status = RuleStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  BlockingRuleEntity copyWith({RuleStatus? status, DateTime? updatedAt}) {
    return BlockingRuleEntity(
      id: id,
      userId: userId,
      itemType: itemType,
      itemIdentifier: itemIdentifier,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
