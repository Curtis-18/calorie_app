import 'dart:convert';
import 'dart:typed_data';

import 'detected_food.dart';
import 'food_entry.dart';

enum ScanStatus {
  /// The photo is being looked at.
  scanning,

  /// Foods were found and are waiting for the person to check them.
  ready,

  /// The scan worked but found no food.
  empty,

  /// The scan failed; [PendingScan.message] says why.
  failed,
}

/// One meal photo on its way through the scan: shown on Today the moment it is
/// taken, so the person is never staring at a spinner while Gemini works.
class PendingScan {
  PendingScan({
    required this.id,
    required this.meal,
    required this.image,
    required this.startedAt,
    this.status = ScanStatus.scanning,
    this.foods = const [],
    this.message,
    this.retryable = false,
    this.note,
  });

  final String id;
  final MealType meal;

  /// The (already shrunk) photo. Kept so a failed scan can be tried again and
  /// the card can show a thumbnail.
  final Uint8List image;
  final DateTime startedAt;
  ScanStatus status;
  List<DetectedFood> foods;
  String? message;
  bool retryable;

  /// What the person said about the meal; sent with the scan.
  String? note;

  /// Bumped on every run, so the answer to an older run (before a note was
  /// added) is ignored.
  int run = 0;

  /// Only the photo is saved to the device (never the result), so a scan that
  /// was in flight when the app closed simply runs again when it reopens.
  Map<String, dynamic> toJson() => {
        'id': id,
        'meal': meal.name,
        'image': base64Encode(image),
        'started': startedAt.toIso8601String(),
        if (note != null) 'note': note,
      };

  static PendingScan? fromJson(Object? raw) {
    try {
      final json = raw as Map<String, dynamic>;
      final meal = MealType.values.firstWhere((m) => m.name == json['meal']);
      return PendingScan(
        id: json['id'] as String,
        meal: meal,
        image: base64Decode(json['image'] as String),
        startedAt: DateTime.parse(json['started'] as String),
        note: json['note'] as String?,
      );
    } catch (_) {
      return null; // a damaged record is dropped, never a crash at start-up
    }
  }
}
