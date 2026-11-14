import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import 'user_cache.dart';

class AccountException implements Exception {
  const AccountException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Deleting the signed-in person's account (App Store guideline 5.1.1(v)).
class AccountService {
  AccountService({this._client, this._tokenProvider, String? Function()? currentUserId})
      : _currentUserId = currentUserId ?? UserCache.currentUserId;

  final http.Client? _client;
  final String? Function()? _tokenProvider;
  final String? Function() _currentUserId;

  static String? _supabaseToken() => Supabase.instance.client.auth.currentSession?.accessToken;

  /// Delete the account and everything in it on the server, then forget this
  /// person's data on the device. Throws [AccountException] (with nothing
  /// deleted) if the server can't do it. The caller signs out afterwards.
  Future<void> deleteAccount() async {
    final token = (_tokenProvider ?? _supabaseToken)();
    final userId = _currentUserId();
    if (token == null) throw const AccountException("You've been signed out. Please log in again.");

    final client = _client ?? http.Client();
    final http.Response response;
    try {
      response = await client
          .delete(Uri.parse('${ApiConfig.baseUrl}/me'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 60)); // may include a server cold start
    } on TimeoutException {
      throw const AccountException('The server is taking too long. It may be waking up, so try again.');
    } on http.ClientException {
      throw const AccountException("Couldn't reach the server. Check your connection and try again.");
    } finally {
      if (_client == null) client.close();
    }

    // 401 after a lost response means the first attempt went through: the
    // account, and so the sign-in, is already gone.
    if (response.statusCode != 204 && response.statusCode != 401) {
      throw AccountException(_detail(response, "Couldn't delete your account. Please try again."));
    }
    if (userId != null) await forgetOnDevice(userId);
  }

  /// Remove this person's cached profile, food log and progress ledger.
  static Future<void> forgetOnDevice(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (key == UserCache.profileKey(userId) || key.startsWith(UserCache.logPrefix(userId)) || key.endsWith(':$userId')) {
        await prefs.remove(key);
      }
    }
  }

  static String _detail(http.Response r, String fallback) {
    try {
      final detail = (jsonDecode(r.body) as Map<String, dynamic>)['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    } catch (_) {}
    return fallback;
  }
}
