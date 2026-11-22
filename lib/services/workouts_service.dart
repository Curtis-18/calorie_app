import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../models/workouts.dart';
import 'language_client.dart';

/// The Workouts tab's server calls: the curated library, and the movement log.
class WorkoutsService {
  WorkoutsService({this._client, this._tokenProvider, this._now});

  final http.Client? _client;
  final String? Function()? _tokenProvider;
  final DateTime Function()? _now;

  static String? _supabaseToken() => Supabase.instance.client.auth.currentSession?.accessToken;

  /// The device-local day, the same one food logs are saved under.
  String get _today => (_now ?? DateTime.now)().toIso8601String().substring(0, 10);

  Future<http.Response> _send(Future<http.Response> Function(http.Client, Map<String, String>) call) async {
    final token = (_tokenProvider ?? _supabaseToken)();
    if (token == null) throw StateError('signed out');
    final client = _client ?? languageClient();
    try {
      return await call(client, {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 30));
    } finally {
      if (_client == null) client.close();
    }
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);

  dynamic _json(http.Response r) => jsonDecode(utf8.decode(r.bodyBytes));

  Future<WorkoutLibrary> library() async {
    final r = await _send((c, h) => c.get(_uri('/workouts'), headers: h));
    if (r.statusCode != 200) throw StateError('workouts ${r.statusCode}');
    return WorkoutLibrary.fromJson(_json(r) as Map<String, dynamic>);
  }

  Future<WorkoutDetail> detail(String id) async {
    final r = await _send((c, h) => c.get(_uri('/workouts/${Uri.encodeComponent(id)}'), headers: h));
    if (r.statusCode != 200) throw StateError('workout ${r.statusCode}');
    final d = WorkoutDetail.fromJson(_json(r));
    if (d == null) throw StateError('workout unreadable');
    return d;
  }

  Future<MoveWeek> week() async {
    final r = await _send((c, h) => c.get(_uri('/movement/week', {'date': _today}), headers: h));
    if (r.statusCode != 200) throw StateError('week ${r.statusCode}');
    return MoveWeek.fromJson(_json(r) as Map<String, dynamic>);
  }

  Future<List<MovementEntry>> entries() async {
    final r = await _send((c, h) => c.get(_uri('/movement', {'date': _today}), headers: h));
    if (r.statusCode != 200) throw StateError('movement ${r.statusCode}');
    final raw = _json(r);
    return [
      if (raw is List)
        for (final e in raw) ?MovementEntry.fromJson(e),
    ];
  }

  Future<List<ActivityChoice>> choices() async {
    final r = await _send((c, h) => c.get(_uri('/movement/choices'), headers: h));
    if (r.statusCode != 200) throw StateError('choices ${r.statusCode}');
    final raw = (_json(r) as Map<String, dynamic>)['activities'];
    return [
      if (raw is List)
        for (final e in raw) ?ActivityChoice.fromJson(e),
    ];
  }

  /// Log a guided session (pass [routineId]) or something done by hand (pass
  /// [activity]). [id] is chosen by the caller so a retry cannot log twice.
  Future<MovementEntry> log({
    required String id,
    required int minutes,
    String? routineId,
    String? activity,
    String? intensity,
  }) async {
    final body = jsonEncode({
      'id': id,
      'minutes': minutes,
      'date': _today,
      'routine_id': ?routineId,
      'activity': ?activity,
      'intensity': ?intensity,
    });
    final r = await _send((c, h) => c.post(_uri('/movement'), headers: h, body: body));
    if (r.statusCode != 200) throw StateError('log ${r.statusCode}');
    final e = MovementEntry.fromJson(_json(r));
    if (e == null) throw StateError('log unreadable');
    return e;
  }

  /// How much of today's movement is added to the calorie plan (0 = off).
  Future<int> setEatBack(int percent) async {
    final body = jsonEncode({'eat_back_percent': percent});
    final r = await _send((c, h) => c.post(_uri('/movement/prefs'), headers: h, body: body));
    if (r.statusCode != 200) throw StateError('prefs ${r.statusCode}');
    return ((_json(r) as Map<String, dynamic>)['eat_back_percent'] as num?)?.toInt() ?? percent;
  }

  Future<void> delete(String id) async {
    final r = await _send((c, h) => c.delete(_uri('/movement/${Uri.encodeComponent(id)}'), headers: h));
    if (r.statusCode != 204 && r.statusCode != 404) throw StateError('delete ${r.statusCode}');
  }
}
