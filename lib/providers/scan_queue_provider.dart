import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/detected_food.dart';
import '../models/food_entry.dart';
import '../models/pending_scan.dart';
import '../services/photo_estimation.dart';
import '../services/snaps_service.dart' show newSnapId;
import '../services/user_cache.dart';
import 'food_region_provider.dart';

/// Meal photos being scanned in the background.
///
/// Taking a photo used to block the whole screen behind "Analysing your meal"
/// until Gemini and USDA had answered (several seconds, up to a minute on a
/// cold server). Now the photo becomes a card on Today at once, the scan runs
/// behind it, and the person reviews the foods when they are ready.
///
/// Nothing is logged until the person reviews the result, same as before, and
/// a scan that is still pending does not count toward the day's totals.
class ScanQueueNotifier extends StateNotifier<List<PendingScan>> {
  ScanQueueNotifier({
    Future<List<DetectedFood>> Function(List<int> bytes, String? note)? analyze,
    String? Function()? currentUserId,
    Stream<String?>? userIdChanges,
    Future<SharedPreferences> Function()? prefs,
    this.retryDelays = defaultRetryDelays,
    DateTime Function()? now,
    String? Function()? region,
  })  : _analyze = analyze ??
            ((bytes, note) => PhotoEstimationService().analyzePhoto(bytes, note: note, region: region?.call())),
        _currentUserId = currentUserId ?? UserCache.currentUserId,
        _prefs = prefs ?? SharedPreferences.getInstance,
        _now = now ?? DateTime.now,
        super(const []) {
    _subscription = (userIdChanges ?? UserCache.userIdChanges()).listen(_onUser);
    _onUser(_currentUserId());
  }

  /// A failure that a retry can fix (timeout, dropped connection, server
  /// busy) is tried again after each pause, then left for the person's own
  /// "Try again". Same pauses as saving a log entry.
  static const defaultRetryDelays = [Duration(seconds: 1), Duration(seconds: 3)];

  /// Photos waiting at once. Each is a few hundred KB kept on the device, and
  /// more than this means the person is not reviewing them.
  static const maxPending = 3;

  static String storageKey(String userId) => 'pending_scans:$userId';

  final List<Duration> retryDelays;
  final Future<List<DetectedFood>> Function(List<int> bytes, String? note) _analyze;
  final String? Function() _currentUserId;
  final Future<SharedPreferences> Function() _prefs;
  final DateTime Function() _now;
  StreamSubscription<String?>? _subscription;
  String? _userId;

  /// Bumped when the user changes, so a scan for the previous person can't
  /// show its result to the next one.
  int _generation = 0;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onUser(String? userId) {
    if (userId == _userId) return; // a token refresh, nothing to do
    _userId = userId;
    _generation++;
    state = const [];
    if (userId != null) unawaited(_restore(userId, _generation));
  }

  Future<void> _restore(String userId, int generation) async {
    try {
      final prefs = await _prefs();
      if (!mounted || generation != _generation) return;
      final saved = prefs.getStringList(storageKey(userId)) ?? const [];
      final jobs = <PendingScan>[];
      for (final raw in saved) {
        final job = PendingScan.fromJson(jsonDecode(raw));
        if (job != null) jobs.add(job);
      }
      if (jobs.isEmpty) return;
      state = jobs.take(maxPending).toList();
      for (final job in state) {
        unawaited(_run(job, generation));
      }
    } catch (_) {
      // Storage unavailable or damaged: start with nothing waiting.
    }
  }

  /// Whether another photo can be taken now.
  bool get hasRoom => state.length < maxPending;

  /// Start scanning [image] for [meal]. Returns the new card's id, or null
  /// when [maxPending] photos are already waiting.
  String? start(Uint8List image, MealType meal) {
    if (!hasRoom || _userId == null) return null;
    final job = PendingScan(id: newSnapId(), meal: meal, image: image, startedAt: _now());
    state = [...state, job];
    final generation = _generation;
    unawaited(_persist());
    unawaited(_run(job, generation));
    return job.id;
  }

  Future<void> _run(PendingScan job, int generation) async {
    final run = ++job.run;
    bool current() => job.run == run && _alive(job.id, generation);
    job
      ..status = ScanStatus.scanning
      ..message = null;
    _notify(job.id, generation);

    var attempt = 0;
    while (true) {
      try {
        final foods = await _analyze(job.image, job.note);
        if (!current()) return;
        job
          ..foods = foods
          ..status = foods.isEmpty ? ScanStatus.empty : ScanStatus.ready;
        break;
      } catch (e) {
        if (!current()) return;
        final retryable = e is PhotoAnalysisException && e.retryable;
        if (retryable && attempt < retryDelays.length) {
          await Future<void>.delayed(retryDelays[attempt++]);
          if (!current()) return;
          continue;
        }
        job
          ..status = ScanStatus.failed
          ..retryable = retryable
          ..message = e is PhotoAnalysisException
              ? e.message
              : 'Something went wrong while scanning your meal. Please try again.';
        break;
      }
    }
    _notify(job.id, generation);
  }

  bool _alive(String id, int generation) =>
      mounted && generation == _generation && state.any((j) => j.id == id);

  void _notify(String id, int generation) {
    if (!_alive(id, generation)) return;
    state = [...state];
  }

  /// Try a failed scan again with the same photo.
  void retry(String id) {
    final job = _find(id);
    if (job == null || job.status == ScanStatus.scanning) return;
    unawaited(_run(job, _generation));
  }

  /// Scan again with what the person said about the meal ("half of this,
  /// cooked in butter"). It is a second scan, only when they choose to add one.
  void addNote(String id, String text) {
    final job = _find(id);
    final note = text.trim();
    if (job == null || note.isEmpty) return;
    job.note = note.length > maxNoteLength ? note.substring(0, maxNoteLength) : note;
    unawaited(_persist());
    unawaited(_run(job, _generation));
  }

  /// Same limit as the server.
  static const maxNoteLength = 300;

  /// Remove a card: dismissed by the person, or its foods were reviewed.
  void remove(String id) {
    if (_find(id) == null) return;
    state = state.where((j) => j.id != id).toList();
    unawaited(_persist());
  }

  PendingScan? _find(String id) {
    for (final j in state) {
      if (j.id == id) return j;
    }
    return null;
  }

  Future<void> _persist() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final prefs = await _prefs();
      if (state.isEmpty) {
        await prefs.remove(storageKey(userId));
      } else {
        await prefs.setStringList(storageKey(userId), [for (final j in state) jsonEncode(j.toJson())]);
      }
    } catch (_) {
      // Too big for storage or storage off: the scan still works this session.
    }
  }
}

final scanQueueProvider =
    StateNotifierProvider<ScanQueueNotifier, List<PendingScan>>(
        (ref) => ScanQueueNotifier(region: () => ref.read(foodRegionProvider)));
