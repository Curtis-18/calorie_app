import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';

/// Profile pictures are stored square at this size: sharp on any avatar the
/// app draws, and small enough that a friends list loads quickly.
const avatarSize = 512;

/// Turn any photo into what gets uploaded: rotation baked in, centre-cropped
/// to a square, [avatarSize] pixels, JPEG.
Future<Uint8List> prepareAvatar(Uint8List photo) => compute(_square, photo);

Uint8List _square(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Not an image');
  var photo = img.bakeOrientation(decoded);
  final side = photo.width < photo.height ? photo.width : photo.height;
  photo = img.copyCrop(
    photo,
    x: (photo.width - side) ~/ 2,
    y: (photo.height - side) ~/ 2,
    width: side,
    height: side,
  );
  if (side != avatarSize) {
    photo = img.copyResize(photo, width: avatarSize, height: avatarSize, interpolation: img.Interpolation.average);
  }
  return Uint8List.fromList(img.encodeJpg(photo, quality: 85));
}

class AvatarException implements Exception {
  const AvatarException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Setting and removing your own profile picture.
class AvatarService {
  AvatarService({this._client, this._tokenProvider});

  final http.Client? _client;
  final String? Function()? _tokenProvider;

  static String? _supabaseToken() => Supabase.instance.client.auth.currentSession?.accessToken;

  Future<http.Response> _send(Future<http.Response> Function(http.Client, Map<String, String>) call) async {
    final token = (_tokenProvider ?? _supabaseToken)();
    if (token == null) throw const AvatarException("You've been signed out. Please log in again.");
    final client = _client ?? http.Client();
    try {
      return await call(client, {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const AvatarException('The server is taking too long. It may be waking up, so try again.');
    } on http.ClientException {
      throw const AvatarException("Couldn't reach the server. Check your connection and try again.");
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

  Uri get _uri => Uri.parse('${ApiConfig.baseUrl}/me/avatar');

  /// Upload [image] (already prepared) as your picture.
  Future<void> upload(Uint8List image) async {
    final r = await _send((c, h) => c.post(_uri, headers: h, body: jsonEncode({'image': base64Encode(image)})));
    if (r.statusCode == 200) return;
    throw AvatarException(_detail(r, "Couldn't save your photo. Please try again."));
  }

  Future<void> remove() async {
    final r = await _send((c, h) => c.delete(_uri, headers: h));
    if (r.statusCode == 204) return;
    throw AvatarException(_detail(r, "Couldn't remove your photo. Please try again."));
  }
}
