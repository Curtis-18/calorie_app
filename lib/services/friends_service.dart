import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../models/friends.dart';

class FriendsException implements Exception {
  const FriendsException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Friend requests, friendships and blocks through the backend.
class FriendsService {
  FriendsService({this._client, this._tokenProvider});

  final http.Client? _client;
  final String? Function()? _tokenProvider;

  static String? _supabaseToken() => Supabase.instance.client.auth.currentSession?.accessToken;

  Future<http.Response> _send(
    Future<http.Response> Function(http.Client, Map<String, String>) call,
  ) async {
    final token = (_tokenProvider ?? _supabaseToken)();
    if (token == null) throw const FriendsException("You've been signed out. Please log in again.");
    final client = _client ?? http.Client();
    try {
      return await call(client, {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw const FriendsException('The server is taking too long. It may be waking up, so try again.');
    } on http.ClientException {
      throw const FriendsException("Couldn't reach the server. Check your connection and try again.");
    } finally {
      if (_client == null) client.close();
    }
  }

  static String _detail(http.Response r, String fallback) {
    try {
      final detail = (jsonDecode(r.body) as Map<String, dynamic>)['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    } catch (_) {}
    return fallback;
  }

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  /// Friends, requests and the user's own username, loaded together.
  Future<FriendsData> load() async {
    final results = await Future.wait([
      _send((c, h) => c.get(_uri('/friends'), headers: h)),
      _send((c, h) => c.get(_uri('/me'), headers: h)),
    ]);
    final friends = results[0];
    if (friends.statusCode != 200) throw const FriendsException("Couldn't load your friends. Please try again.");
    String? mine;
    if (results[1].statusCode == 200) {
      mine = (jsonDecode(results[1].body) as Map<String, dynamic>)['username'] as String?;
    }
    return FriendsData.fromJson(jsonDecode(friends.body) as Map<String, dynamic>, myUsername: mine);
  }

  Future<RequestResult> sendRequest(String username) async {
    final r = await _send((c, h) =>
        c.post(_uri('/friends/requests'), headers: h, body: jsonEncode({'username': username.trim()})));
    if (r.statusCode == 200) {
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      return RequestResult(RequestOutcome.fromApi(json['outcome'] as String?), json['username'] as String? ?? username);
    }
    throw FriendsException(_detail(r, "Couldn't send that request. Please try again."));
  }

  Future<void> _action(Future<http.Response> Function(http.Client, Map<String, String>) call, String failure) async {
    final r = await _send(call);
    if (r.statusCode == 204) return;
    throw FriendsException(_detail(r, failure));
  }

  Future<void> accept(String friendshipId) => _action(
      (c, h) => c.post(_uri('/friends/requests/$friendshipId/accept'), headers: h), "Couldn't accept that request.");

  Future<void> decline(String friendshipId) => _action(
      (c, h) => c.post(_uri('/friends/requests/$friendshipId/decline'), headers: h), "Couldn't decline that request.");

  /// Unfriend, or cancel a request you sent.
  Future<void> remove(String friendshipId) =>
      _action((c, h) => c.delete(_uri('/friends/$friendshipId'), headers: h), "Couldn't remove them. Please try again.");

  Future<void> block(String friendshipId) => _action(
      (c, h) => c.post(_uri('/friends/$friendshipId/block'), headers: h), "Couldn't block them. Please try again.");

  Future<List<Person>> blocks() async {
    final r = await _send((c, h) => c.get(_uri('/blocks'), headers: h));
    if (r.statusCode != 200) throw const FriendsException("Couldn't load your blocked list.");
    return (jsonDecode(r.body) as List).map((e) => Person.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> unblock(String userId) =>
      _action((c, h) => c.delete(_uri('/blocks/$userId'), headers: h), "Couldn't unblock them. Please try again.");
}
