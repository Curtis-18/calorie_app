import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../models/food_entry.dart';
import 'user_cache.dart';

/// Reads one day's food log from the server, for browsing past days.
///
/// Past days used to come from the device cache only, so a new phone, a new
/// browser or cleared storage showed every earlier day as empty even though
/// the entries were safe on the server. `GET /logs/today?date=` already
/// returns any single date (the name is historical).
class DayLogService {
  DayLogService({this._client, this._tokenProvider, this.timeout = const Duration(seconds: 15)});

  final http.Client? _client;
  final String? Function()? _tokenProvider;
  final Duration timeout;

  static String? _supabaseToken() => Supabase.instance.client.auth.currentSession?.accessToken;

  static String dayString(DateTime d) => d.toIso8601String().substring(0, 10);

  /// The server's entries for [day], newest first, or null when they can't be
  /// had (offline, signed out, server error): the caller keeps what it has.
  /// A successful read refreshes this user's device cache for that day, so
  /// the day also works offline afterwards.
  Future<List<FoodEntry>?> fetch(DateTime day) async {
    final userId = UserCache.currentUserId();
    final token = (_tokenProvider ?? _supabaseToken)();
    if (userId == null || token == null) return null;

    final client = _client ?? http.Client();
    try {
      final response = await client.get(
        Uri.parse('${ApiConfig.baseUrl}/logs/today?date=${dayString(day)}'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(timeout);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as List<dynamic>;
      final entries = data.map((e) => FoodEntry.fromApiJson(e as Map<String, dynamic>)).toList();

      // Don't write one user's day into another's cache if they switched
      // while this was in flight.
      if (UserCache.currentUserId() == userId) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          UserCache.logKey(userId, day),
          entries.map((e) => jsonEncode(e.toJson())).toList(),
        );
      }
      return entries;
    } catch (_) {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }
}
