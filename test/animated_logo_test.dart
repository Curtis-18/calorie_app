import 'package:calorie_app/widgets/animated_logo.dart';
import 'package:calorie_app/widgets/splash.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: MediaQueryData(size: const Size(400, 800), disableAnimations: reduceMotion),
    child: Center(child: child),
  ),
);

void main() {
  testWidgets('the animated logo builds and keeps animating', (tester) async {
    await tester.pumpWidget(_host(const AnimatedLogo(size: 160, intro: true)));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(AnimatedLogo), findsOneWidget);
    expect(find.bySemanticsLabel('NuStreak'), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('reduced motion shows it still, with nothing running', (tester) async {
    await tester.pumpWidget(_host(const AnimatedLogo(size: 160, intro: true), reduceMotion: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the launch screen says NUSTREAK', (tester) async {
    await tester.pumpWidget(_host(const AppSplash(visible: true, child: SizedBox())));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('NUSTREAK'), findsOneWidget);
    expect(find.text('CALORIE TRACKER'), findsNothing);
  });
}
