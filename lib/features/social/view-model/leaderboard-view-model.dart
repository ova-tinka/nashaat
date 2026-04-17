import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/leaderboard-entity.dart';
import '../../../core/entities/profile-entity.dart';
import '../../../core/repositories/leaderboard-repository.dart';
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

  LeaderboardViewModel({
    required LeaderboardRepository leaderboardRepo,
    required ProfileRepository profileRepo,
  })  : _leaderboardRepo = leaderboardRepo,
        _profileRepo = profileRepo;

  List<LeaderboardEntity> _leaderboards = [];
  LeaderboardEntity? _selectedLeaderboard;
  List<LeaderboardEntry> _rankings = [];
  bool _isLoading = false;
  bool _isLoadingRankings = false;
  String? _error;

  List<LeaderboardEntity> get leaderboards =>
      List.unmodifiable(_leaderboards);
  LeaderboardEntity? get selectedLeaderboard => _selectedLeaderboard;
  List<LeaderboardEntry> get rankings => List.unmodifiable(_rankings);
  bool get isLoading => _isLoading;
  bool get isLoadingRankings => _isLoadingRankings;
  String? get error => _error;

  String get currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  int get myRank {
    final idx = _rankings.indexWhere((r) => r.userId == currentUserId);
    return idx == -1 ? 0 : idx + 1;
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _leaderboards =
          await _leaderboardRepo.getUserLeaderboards(currentUserId);
      if (_leaderboards.isNotEmpty && _selectedLeaderboard == null) {
        _selectedLeaderboard = _leaderboards.first;
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
      final profiles = await Future.wait(
        members.map((m) => _profileRepo.getProfile(m.userId)),
      );

      _rankings = [];
      for (int i = 0; i < members.length; i++) {
        final member = members[i];
        final profile = profiles[i];
        _rankings.add(LeaderboardEntry(
          userId: member.userId,
          displayName: _displayName(profile),
          weeklyScore: member.weeklyScore,
          rank: i + 1,
          streakCount: profile?.streakCount ?? 0,
        ));
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
      _leaderboards.insert(0, lb);
      _selectedLeaderboard = lb;
      _rankings = [
        LeaderboardEntry(
          userId: currentUserId,
          displayName: 'You',
          weeklyScore: 0,
          rank: 1,
          streakCount: 0,
        ),
      ];
      notifyListeners();
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

  String _displayName(ProfileEntity? p) {
    if (p == null) return 'Athlete';
    return p.username ?? p.firstName ?? p.email.split('@').first;
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
