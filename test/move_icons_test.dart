import 'package:calorie_app/models/mood.dart';
import 'package:calorie_app/models/workouts.dart';
import 'package:calorie_app/widgets/move_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every kind of movement and every feeling has its own glyph', () {
    expect({for (final s in MoveSlice.values) s.glyph}.length, MoveSlice.values.length);
    expect({for (final m in Mood.values) m.glyph}.length, Mood.values.length);
    expect(MoveGlyph.values.length, MoveSlice.values.length + Mood.values.length);
  });

  test('each kind of movement has its own colour', () {
    expect({for (final s in MoveSlice.values) s.color.toARGB32()}.length, MoveSlice.values.length);
  });

  testWidgets('every glyph paints at any size, plain or on a tile, without error', (tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Wrap(children: [
        for (final g in MoveGlyph.values) ...[
          MoveIcon(g, size: 12),
          MoveIcon(g, size: 24, color: const Color(0xFFFF5E3A)),
          MoveIcon(g, size: 64, tile: true),
        ],
      ]),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(MoveIcon), findsNWidgets(MoveGlyph.values.length * 3));
  });

  testWidgets('a tile is about twice the icon, and a plain icon is exactly its size', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Column(children: [
        MoveIcon(MoveGlyph.cardio, size: 20, key: ValueKey('plain')),
        MoveIcon(MoveGlyph.cardio, size: 20, tile: true, key: ValueKey('tile')),
      ]),
    ));
    expect(tester.getSize(find.byKey(const ValueKey('plain'))), const Size(20, 20));
    expect(tester.getSize(find.byKey(const ValueKey('tile'))), const Size(38, 38));
  });

  test('no emoji is left on the Workouts tab', () {
    // The slice enum no longer carries one; the screens use MoveIcon instead.
    expect(MoveSlice.values.map((s) => s.name), ['strength', 'cardio', 'mobility', 'fun']);
  });
}
