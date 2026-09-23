class PublicProfileEntity {
  final String id;
  final String? username;
  final String? firstName;
  final String? lastName;
  final int streakCount;

  const PublicProfileEntity({
    required this.id,
    this.username,
    this.firstName,
    this.lastName,
    this.streakCount = 0,
  });
}
