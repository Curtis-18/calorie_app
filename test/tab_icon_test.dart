import 'package:calorie_app/screens/main_shell.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/move_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => CupertinoApp(theme: AppTheme.cupertino, home: Center(child: child));

void main() {
  testWidgets('a tab with one of our own glyphs draws it instead of a font icon', (tester) async {
    await tester.pumpWidget(_host(const TabIcon(icon: CupertinoIcons.bolt, glyph: MoveGlyph.strength, active: false)));
    expect(find.byType(MoveIcon), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.bolt), findsNothing);
  });

  testWidgets('a tab without one still draws its font icon', (tester) async {
    await tester.pumpWidget(_host(const TabIcon(icon: CupertinoIcons.book, active: true)));
    expect(find.byIcon(CupertinoIcons.book), findsOneWidget);
    expect(find.byType(MoveIcon), findsNothing);
  });

  testWidgets('the glyph is tinted like the other tabs: accent when active, quiet when not', (tester) async {
    await tester.pumpWidget(_host(const TabIcon(icon: CupertinoIcons.bolt, glyph: MoveGlyph.strength, active: true)));
    final on = tester.widget<MoveIcon>(find.byType(MoveIcon)).color;
    await tester.pumpWidget(_host(const TabIcon(icon: CupertinoIcons.bolt, glyph: MoveGlyph.strength, active: false)));
    final off = tester.widget<MoveIcon>(find.byType(MoveIcon)).color;
    expect(on, isNot(off));
  });
}
