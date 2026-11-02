import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../models/progress.dart';

class ProgressService {
  ProgressService({this._client, this._tokenProvider, this._now});

  final http.Client? _client;
  final String? Function()? _tokenProvider;
  final DateTime Function()? _now;

  static String? _supabaseToken() => Supabase.instance.client.auth.currentSession?.accessToken;

  /// The user's progress, or null when signed out or the request fails.
  /// The game layer is decoration: it must never break the dashboard.
  Future<ProgressData?> fetch() async {
    final token = (_tokenProvider ?? _supabaseToken)();
    if (token == null) return null;
    // Same device-local date as the food logs, so the streak agrees with
    // the day the user is on.
    final today = (_now ?? DateTime.now)().toIso8601String().substring(0, 10);
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/progress').replace(queryParameters: {'date': today}),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      return ProgressData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }
}

/// What the user has already been congratulated for, so each celebration
/// happens once, not on every refresh or every app launch.
class CelebrationLedger {
  const CelebrationLedger({required this.achievements, required this.level, this.perfectDay});

  final Set<String> achievements;
  final int level;

  /// The date (yyyy-mm-dd) of the last celebrated perfect day.
  final String? perfectDay;

  factory CelebrationLedger.of(ProgressData p) => CelebrationLedger(
        achievements: {for (final a in p.achievements) if (a.unlocked) a.id},
        level: p.level.level,
        perfectDay: p.today.perfectDay ? _day(p.date) : null,
      );

  Map<String, dynamic> toJson() => {
        'achievements': achievements.toList(),
        'level': level,
        'perfectDay': perfectDay,
      };

  factory CelebrationLedger.fromJson(Map<String, dynamic> j) => CelebrationLedger(
        achievements: {...(j['achievements'] as List<dynamic>).cast<String>()},
        level: (j['level'] as num).toInt(),
        perfectDay: j['perfectDay'] as String?,
      );
}

String _day(DateTime d) => d.toIso8601String().substring(0, 10);

/// New celebrations in [progress] compared with [seen], and the updated
/// ledger. With no ledger yet (first launch after the update, or a new
/// device), today's state becomes the baseline: an existing user shouldn't
/// get a burst of badges they "earned" months ago.
(List<Celebration>, CelebrationLedger) diffCelebrations(ProgressData progress, CelebrationLedger? seen) {
  if (seen == null) return (const [], CelebrationLedger.of(progress));

  final events = <Celebration>[];
  final today = _day(progress.date);

  var perfectDay = seen.perfectDay;
  if (progress.today.perfectDay && seen.perfectDay != today) {
    events.add(const PerfectDayCelebration());
    perfectDay = today;
  }

  final achievements = {...seen.achievements};
  for (final a in progress.achievements) {
    if (a.unlocked && achievements.add(a.id)) events.add(AchievementCelebration(a));
  }

  var level = seen.level;
  if (progress.level.level > seen.level) {
    events.add(LevelUpCelebration(progress.level.level));
    level = progress.level.level;
  }

  return (
    events,
    CelebrationLedger(achievements: achievements, level: level, perfectDay: perfectDay),
  );
}
