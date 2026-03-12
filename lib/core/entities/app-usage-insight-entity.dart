class AppUsageInsightEntity {
  final String id;
  final String userId;
  final DateTime usageDate;
  final int totalScreenTimeMinutes;
  /// Maps app identifier → minutes used, e.g. {'com.instagram.android': 45}
  final Map<String, int> appBreakdown;
  final DateTime createdAt;

  const AppUsageInsightEntity({
    required this.id,
    required this.userId,
    required this.usageDate,
    this.totalScreenTimeMinutes = 0,
    this.appBreakdown = const {},
    required this.createdAt,
  });

  AppUsageInsightEntity copyWith({
    int? totalScreenTimeMinutes,
    Map<String, int>? appBreakdown,
  }) {
    return AppUsageInsightEntity(
      id: id,
      userId: userId,
      usageDate: usageDate,
      totalScreenTimeMinutes:
          totalScreenTimeMinutes ?? this.totalScreenTimeMinutes,
      appBreakdown: appBreakdown ?? this.appBreakdown,
      createdAt: createdAt,
    );
  }
}
