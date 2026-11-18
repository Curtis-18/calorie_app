import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:calorie_app/models/adjustment.dart';
import 'package:calorie_app/models/detected_food.dart';
import 'package:calorie_app/models/food_entry.dart';
import 'package:calorie_app/models/pending_scan.dart';
import 'package:calorie_app/providers/scan_queue_provider.dart';
import 'package:calorie_app/screens/photo_review_screen.dart';
import 'package:calorie_app/services/photo_estimation.dart';
import 'package:calorie_app/services/voice_note.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/scan_note_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeVoice implements VoiceRecognizer {
  FakeVoice({this.ok = true});
  final bool ok;
  void Function(String, bool)? sink;
  bool stopped = false;
  @override
  Future<bool> available() async => ok;
  @override
  Future<void> listen(void Function(String text, bool done) onText) async => sink = onText;
  @override
  Future<void> stop() async => stopped = true;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('the note on a scan request', () {
    test('is sent trimmed, and left out when blank', () async {
      final bodies = <Map<String, dynamic>>[];
      final client = MockClient((r) async {
        bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
        return http.Response('[]', 200);
      });
      final service = PhotoEstimationService(client: client, tokenProvider: () async => 't');
      await service.analyzePhoto([1], note: '  half of this ');
      await service.analyzePhoto([1], note: '   ');
      await service.analyzePhoto([1]);
      expect(bodies[0]['note'], 'half of this');
      expect(bodies[1].containsKey('note'), isFalse);
      expect(bodies[2].containsKey('note'), isFalse);
    });

    test('the server hints are read, and bad ones ignored', () {
      final f = DetectedFood.fromApiJson({
        'name': 'Fish', 'estimated_grams': 60, 'added': ['butter', 3, 'oil'], 'note_applied': 'Halved because you said half',
      });
      expect(f.added, ['butter', 'oil']);
      expect(f.noteApplied, 'Halved because you said half');
      expect(DetectedFood.fromApiJson({'name': 'x', 'estimated_grams': 1}).added, isEmpty);
    });
  });

  group('adding a note to a waiting scan', () {
    late StreamController<String?> auth;
    late List<Completer<List<DetectedFood>>> calls;
    late List<String?> notes;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      auth = StreamController<String?>.broadcast();
      calls = [];
      notes = [];
    });
    tearDown(() => auth.close());

    ScanQueueNotifier build() {
      final n = ScanQueueNotifier(
        analyze: (bytes, note) {
          notes.add(note);
          final c = Completer<List<DetectedFood>>();
          calls.add(c);
          return c.future;
        },
        currentUserId: () => 'u',
        userIdChanges: auth.stream,
      );
      addTearDown(n.dispose);
      return n;
    }

    Future<void> wait() => Future<void>.delayed(const Duration(milliseconds: 30));
    final photo = Uint8List.fromList([1, 2]);

    test('scans again with the note, and the older answer is ignored', () async {
      final n = build();
      await wait();
      n.start(photo, MealType.dinner);
      n.addNote(n.state.single.id, '  half of this ');
      await wait();
      expect(notes, [null, 'half of this']);

      calls[1].complete([DetectedFood(name: 'New', estimatedGrams: 1, matched: true)]);
      await wait();
      calls[0].complete([DetectedFood(name: 'Old', estimatedGrams: 1, matched: true)]); // late, from before the note
      await wait();
      expect(n.state.single.foods.single.name, 'New');
      expect(n.state.single.status, ScanStatus.ready);
    });

    test('a blank note changes nothing, a long one is cut to the server limit', () async {
      final n = build();
      await wait();
      n.start(photo, MealType.dinner);
      n.addNote(n.state.single.id, '   ');
      expect(calls, hasLength(1));
      n.addNote(n.state.single.id, 'x' * 500);
      await wait();
      expect(notes.last!.length, ScanQueueNotifier.maxNoteLength);
    });

    test('the note is kept with the photo across a restart', () async {
      final n = build();
      await wait();
      n.start(photo, MealType.dinner);
      n.addNote(n.state.single.id, 'with butter');
      await wait();
      notes.clear();
      final again = build();
      await wait();
      expect(again.state.single.note, 'with butter');
      expect(notes, ['with butter']);
    });
  });

  group('the note sheet', () {
    testWidgets('typing a note and applying returns it', (tester) async {
      String? got = 'unset';
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async => got = await showScanNoteSheet(context, recognizer: FakeVoice(ok: false)),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(find.byKey(const ValueKey('scan_note_mic')), findsNothing); // no recogniser, no mic
      await tester.enterText(find.byKey(const ValueKey('scan_note_field')), ' cooked in butter ');
      await tester.tap(find.byKey(const ValueKey('scan_note_apply')));
      await _settle(tester);
      expect(got, 'cooked in butter');
    });

    testWidgets('an empty note cannot be applied, and Not now returns nothing', (tester) async {
      String? got = 'unset';
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async => got = await showScanNoteSheet(context, recognizer: FakeVoice()),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('scan_note_apply')));
      await _settle(tester);
      expect(find.text('Anything to add?'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await _settle(tester);
      expect(got, isNull);
    });

    testWidgets('speaking fills the field, which can still be edited', (tester) async {
      final voice = FakeVoice();
      String? got = 'unset';
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async => got = await showScanNoteSheet(context, recognizer: voice),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('scan_note_mic')));
      await _settle(tester);
      expect(find.text('Listening…'), findsOneWidget);
      voice.sink!('half of this', false);
      voice.sink!('half of this with a diet soda', true);
      await _settle(tester);
      expect(find.text('Listening…'), findsNothing);
      expect(find.text('half of this with a diet soda'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('scan_note_apply')));
      await _settle(tester);
      expect(got, 'half of this with a diet soda');
      expect(voice.stopped, isTrue);
    });
  });

  group('the review screen with a note', () {
    Adjustment butter() => const Adjustment(
          id: 'butter', isScale: false, label: '+ Butter', entryName: 'Butter, 1 tbsp (added)', grams: 14,
          caloriesPer100g: 720, preparations: ['fried'],
        );

    testWidgets('butter the person mentioned is already on, once, and the reason is shown', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final items = [
        DetectedFood(
          name: 'Fish', estimatedGrams: 60, caloriesPer100g: 200, matched: true, preparation: 'fried',
          added: const ['butter'], noteApplied: 'Halved because you said half',
        ),
      ];
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: PhotoReviewScreen(items: items, mealType: MealType.dinner, adjustments: [butter()]),
      ));
      await _settle(tester);
      expect(find.text('Butter, 1 tbsp (added)'), findsOneWidget);
      expect(find.text('✓ Butter'), findsOneWidget); // the chip shows it is on
      expect(find.textContaining('From your note: Halved'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('extra_butter'))); // tapping the chip now switches it off, never doubles it
      await _settle(tester);
      expect(find.text('Butter, 1 tbsp (added)'), findsNothing);
    });
  });
}
