import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/app_tour.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

final _a = GlobalKey(debugLabel: 'a');
final _b = GlobalKey(debugLabel: 'b');
final _c = GlobalKey(debugLabel: 'c');

List<TourStep> _steps({GlobalKey? first, GlobalKey? second, GlobalKey? third}) => [
      TourStep(targetKey: first ?? _a, icon: CupertinoIcons.flame, title: 'First', body: 'one'),
      TourStep(
        targetKey: second ?? _b,
        icon: CupertinoIcons.search,
        title: 'Second',
        body: 'two',
        shape: TourShape.circle,
      ),
      TourStep(
        targetKey: third ?? _c,
        icon: CupertinoIcons.camera,
        title: 'Third',
        body: 'three',
        shape: TourShape.pill,
      ),
    ];

/// Three targets on screen plus a button that starts the tour and records
/// how it ended.
class _Host extends StatefulWidget {
  const _Host({required this.steps, this.showThird = true});

  final List<TourStep> steps;
  final bool showThird;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  TourResult? result;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(key: _a, width: 200, height: 120),
            const SizedBox(height: 40),
            SizedBox(key: _b, width: 50, height: 50),
            const Spacer(),
            if (widget.showThird) SizedBox(key: _c, width: 64, height: 36),
            CupertinoButton(
              child: const Text('start'),
              onPressed: () async {
                final r = await AppTour.show(context, steps: widget.steps);
                setState(() => result = r);
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<_HostState> _start(WidgetTester tester, {bool showThird = true, bool reduceMotion = false}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    CupertinoApp(
      theme: AppTheme.cupertino,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: _Host(steps: _steps(), showThird: showThird),
    ),
  );
  await tester.tap(find.text('start'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return tester.state<_HostState>(find.byType(_Host));
}

/// Run animations to completion, plus one frame so finished transitions
/// (outgoing cards, the popped route) are actually removed.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('walks every step with Next and finishes with Got it', (tester) async {
    final host = await _start(tester);

    expect(find.text('First'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await _settle(tester);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('First'), findsNothing);

    await tester.tap(find.text('Next'));
    await _settle(tester);
    expect(find.text('Third'), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('Skip'), findsNothing, reason: 'no Skip on the last step');

    await tester.tap(find.text('Got it'));
    await _settle(tester);
    expect(find.text('Third'), findsNothing);
    expect(host.result, TourResult.finished);
  });

  testWidgets('Skip ends the tour early', (tester) async {
    final host = await _start(tester);
    await tester.tap(find.text('Skip'));
    await _settle(tester);
    expect(find.text('First'), findsNothing);
    expect(host.result, TourResult.skipped);
  });

  testWidgets('tapping the dimmed area advances, tapping the card does not', (tester) async {
    await _start(tester);

    await tester.tap(find.text('one')); // card body
    await _settle(tester);
    expect(find.text('First'), findsOneWidget);

    await tester.tapAt(const Offset(370, 830)); // scrim corner
    await _settle(tester);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('system back dismisses the tour as skipped', (tester) async {
    final host = await _start(tester);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text('First'), findsNothing);
    expect(host.result, TourResult.skipped);
  });

  testWidgets('steps whose target is not on screen are left out', (tester) async {
    final host = await _start(tester, showThird: false);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await _settle(tester);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await _settle(tester);
    expect(host.result, TourResult.finished);
  });

  testWidgets('with no targets on screen it closes immediately', (tester) async {
    await tester.pumpWidget(CupertinoApp(
      home: Builder(
        builder: (context) => CupertinoButton(
          child: const Text('start'),
          onPressed: () => AppTour.show(context, steps: _steps(
            first: GlobalKey(),
            second: GlobalKey(),
            third: GlobalKey(),
          )),
        ),
      ),
    ));
    await tester.tap(find.text('start'));
    await _settle(tester);
    expect(find.text('First'), findsNothing);
    expect(find.text('start'), findsOneWidget);
  });

  testWidgets('reduced motion: no pulse animation left running', (tester) async {
    await _start(tester, reduceMotion: true);
    expect(find.text('First'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Second'), findsOneWidget);
    // pumpAndSettle would time out if the repeating pulse were still ticking.
    await tester.pumpAndSettle();
  });
}
