import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/leaderboard-entity.dart';
import '../../../core/entities/achievement-entity.dart';
import '../../../core/entities/profile-entity.dart';
import '../../../core/entities/public-profile-entity.dart';
import '../../../core/repositories/leaderboard-repository.dart';
import '../../../core/repositories/achievement-repository.dart';
import '../../../core/repositories/profile-repository.dart';
import '../../../shared/logger.dart';

class LeaderboardEntry {
  final String userId;
  final String displayName;
  final int weeklyScore;
  final int rank;
  final int streakCount;

  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.weeklyScore,
    required this.rank,
    required this.streakCount,
  });
}

class LeaderboardViewModel extends ChangeNotifier {
  final LeaderboardRepository _leaderboardRepo;
  final ProfileRepository _profileRepo;
  final AchievementRepository _achievementRepo;
  final String Function() _getUserId;

  LeaderboardViewModel({
    required LeaderboardRepository leaderboardRepo,
    required ProfileRepository profileRepo,
    required AchievementRepository achievementRepo,
    String Function()? getUserId,
  }) : _leaderboardRepo = leaderboardRepo,
       _profileRepo = profileRepo,
       _achievementRepo = achievementRepo,
       _getUserId =
           getUserId ??
           (() => Supabase.instance.client.auth.currentUser?.id ?? '');

  List<LeaderboardEntity> _leaderboards = [];
  LeaderboardEntity? _selectedLeaderboard;
  List<LeaderboardEntry> _rankings = [];
  bool _isLoading = false;
  bool _isLoadingRankings = false;
  String? _error;
  ProfileEntity? _currentUserProfile;
  List<UserAchievementEntity> _userAchievements = [];
  List<UnlockedAchievementEntity> _newlyUnlockedAchievements = [];

  List<LeaderboardEntity> get leaderboards => List.unmodifiable(_leaderboards);
  LeaderboardEntity? get selectedLeaderboard => _selectedLeaderboard;
  List<LeaderboardEntry> get rankings => List.unmodifiable(_rankings);
  bool get isLoading => _isLoading;
  bool get isLoadingRankings => _isLoadingRankings;
  String? get error => _error;
  ProfileEntity? get currentUserProfile => _currentUserProfile;
  List<UserAchievementEntity> get userAchievements =>
      List.unmodifiable(_userAchievements);
  List<UnlockedAchievementEntity> get newlyUnlockedAchievements =>
      List.unmodifiable(_newlyUnlockedAchievements);

  String get currentUserId => _getUserId();

  int get myRank {
    final idx = _rankings.indexWhere((r) => r.userId == currentUserId);
    return idx == -1 ? 0 : idx + 1;
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _leaderboards = await _leaderboardRepo.getUserLeaderboards(currentUserId);
      if (_leaderboards.isEmpty) {
        _selectedLeaderboard = null;
        _rankings = [];
      } else {
        // Reconcile saved workouts that predate the latest scoring rule.
        await _leaderboardRepo.recalculateMyWeeklyScore();
        final selectedId = _selectedLeaderboard?.id;
        _selectedLeaderboard = _leaderboards.firstWhere(
          (leaderboard) => leaderboard.id == selectedId,
          orElse: () => _leaderboards.first,
        );
        await _loadRankings(_selectedLeaderboard!.id);
      }
    } catch (e) {
      Log.error('LeaderboardViewModel', e);
      _error = 'Could not load leaderboards.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectLeaderboard(LeaderboardEntity leaderboard) async {
    _selectedLeaderboard = leaderboard;
    await _loadRankings(leaderboard.id);
  }

  Future<void> _loadRankings(String leaderboardId) async {
    _isLoadingRankings = true;
    notifyListeners();

    try {
      final members = await _leaderboardRepo.getMembers(leaderboardId);
      final sortedMembers = [...members]
        ..sort((a, b) {
          final byScore = b.weeklyScore.compareTo(a.weeklyScore);
          return byScore != 0 ? byScore : a.userId.compareTo(b.userId);
        });
      final profiles = await Future.wait(
        sortedMembers.map((m) => _profileRepo.getPublicProfile(m.userId)),
      );

      _rankings = [];
      for (int i = 0; i < sortedMembers.length; i++) {
        final member = sortedMembers[i];
        final profile = profiles[i];
        _rankings.add(
          LeaderboardEntry(
            userId: member.userId,
            displayName: _displayName(profile),
            weeklyScore: member.weeklyScore,
            rank: i + 1,
            streakCount: profile?.streakCount ?? 0,
          ),
        );
      }
      Log.db('loaded ${_rankings.length} leaderboard entries');
    } catch (e) {
      Log.error('LeaderboardViewModel._loadRankings', e);
    } finally {
      _isLoadingRankings = false;
      notifyListeners();
    }
  }

  Future<void> createLeaderboard(String name) async {
    try {
      final inviteCode = _generateInviteCode();
      final lb = await _leaderboardRepo.createLeaderboard(
        currentUserId,
        name,
        inviteCode,
      );
      await _leaderboardRepo.recalculateMyWeeklyScore();
      _leaderboards.insert(0, lb);
      _selectedLeaderboard = lb;
      await _loadRankings(lb.id);
    } catch (e) {
      Log.error('LeaderboardViewModel.createLeaderboard', e);
      _error = 'Could not create leaderboard.';
      notifyListeners();
    }
  }

  Future<void> joinByInviteCode(String code) async {
    try {
      final lb = await _leaderboardRepo.getLeaderboardByInviteCode(code);
      if (lb == null) {
        _error = 'Invite code not found.';
        notifyListeners();
        return;
      }
      await _leaderboardRepo.joinLeaderboard(lb.id, currentUserId);
      await _leaderboardRepo.recalculateMyWeeklyScore();
      _newlyUnlockedAchievements = await _achievementRepo
          .evaluateUserAchievements();
      final refreshedData = await Future.wait([
        _profileRepo.getProfile(currentUserId),
        _achievementRepo.getUserAchievements(currentUserId),
      ]);
      _currentUserProfile = refreshedData[0] as ProfileEntity?;
      _userAchievements = refreshedData[1] as List<UserAchievementEntity>;
      _leaderboards.add(lb);
      _selectedLeaderboard = lb;
      await _loadRankings(lb.id);
    } catch (e) {
      Log.error('LeaderboardViewModel.joinByInviteCode', e);
      _error = 'Could not join leaderboard.';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _displayName(PublicProfileEntity? p) {
    if (p == null) return 'Athlete';
    return p.username ?? p.firstName ?? 'Athlete';
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
