import 'dart:convert';

import 'package:calorie_app/models/snaps.dart';
import 'package:calorie_app/services/snaps_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/glass.dart';
import 'package:calorie_app/widgets/snaps/sent_bites_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _snap(String id, List<Map<String, dynamic>> recipients, {String? caption}) => {
      'snap_id': id,
      'caption': caption,
      'created_at': DateTime.now().toUtc().subtract(const Duration(hours: 1)).toIso8601String(),
      'expires_at': DateTime.now().toUtc().add(const Duration(hours: 23)).toIso8601String(),
      'image_url': null, // no network in tests: the placeholder is shown
      'recipients': recipients,
    };

Map<String, dynamic> _to(String name, {bool viewed = false, String? reaction}) =>
    {'user_id': 'u-$name', 'username': name, 'viewed': viewed, 'reaction': reaction};

/// UTF-8, as the real server answers (the default would choke on an emoji).
http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  test('status line', () {
    SentSnap s(List<Map<String, dynamic>> r) => SentSnap.fromJson(_snap('a', r));
    expect(sentStatus(s([_to('sam')])), 'Sent to @sam · not opened yet');
    expect(sentStatus(s([_to('sam', viewed: true)])), 'Seen by @sam');
    expect(sentStatus(s([_to('sam'), _to('bea')])), 'Sent to 2 friends · not opened yet');
    expect(sentStatus(s([_to('sam', viewed: true), _to('bea'), _to('kai', viewed: true)])), 'Seen by 2 of 3');
  });

  group('the sheet', () {
    Future<void> open(WidgetTester tester, MockClient client) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                child: const Text('open'),
                onPressed: () => showAppSheet<void>(
                  context: context,
                  builder: (_) => AppSheet(
                    child: SentBitesSheet(service: SnapsService(client: client, tokenProvider: () => 't')),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await settle(tester);
    }

    testWidgets('lists what was sent, who saw it and how they reacted', (tester) async {
      await open(tester, MockClient((r) async {
        return _json([
          _snap('a', [_to('sam', viewed: true, reaction: '🔥'), _to('bea')], caption: 'Sunday roast'),
          _snap('b', [_to('kai')]),
        ]);
      }));
      expect(find.text('Seen by 1 of 2'), findsOneWidget);
      expect(find.text('Sunday roast'), findsOneWidget);
      expect(find.text('🔥 @sam'), findsOneWidget);
      expect(find.text('Sent to @kai · not opened yet'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('taking a bite back asks first, then removes it', (tester) async {
      final deleted = <String>[];
      await open(tester, MockClient((r) async {
        if (r.method == 'DELETE') {
          deleted.add(r.url.path);
          return http.Response('', 204);
        }
        return http.Response(jsonEncode([_snap('a', [_to('sam')]), _snap('b', [_to('kai')])]), 200);
      }));

      await tester.tap(find.bySemanticsLabel('Take this bite back').first);
      await settle(tester);
      expect(find.text('Take this bite back?'), findsOneWidget);
      await tester.tap(find.text('Keep'));
      await settle(tester);
      expect(deleted, isEmpty);

      await tester.tap(find.bySemanticsLabel('Take this bite back').first);
      await settle(tester);
      await tester.tap(find.text('Take back'));
      await settle(tester);
      expect(deleted, ['/snaps/a']);
      expect(find.text('Sent to @sam · not opened yet'), findsNothing);
      expect(find.text('Sent to @kai · not opened yet'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('nothing sent, and a failed load, each say so', (tester) async {
      await open(tester, MockClient((_) async => http.Response('[]', 200)));
      expect(find.text("You haven't sent a bite in the last 24 hours."), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await open(tester, MockClient((_) async => http.Response('{"detail":"Bites aren\'t available right now."}', 503)));
      expect(find.text("Bites aren't available right now."), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
