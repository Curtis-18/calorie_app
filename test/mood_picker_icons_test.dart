import 'package:calorie_app/models/mood.dart';
import 'package:calorie_app/services/recipe_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/mood_picker.dart';
import 'package:calorie_app/widgets/move_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('each feeling chip on Recipes shows its own icon and label, not an emoji', (tester) async {
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) return;
      original?.call(d);
    };
    addTearDown(() => FlutterError.onError = original);
    await tester.pumpWidget(CupertinoApp(
      theme: AppTheme.cupertino,
      home: CupertinoPageScaffold(
        child: SingleChildScrollView(
          child: MoodPicker(
            service: RecipeService(client: MockClient((_) async => http.Response('{}', 200))),
            pool: const [],
            onOpen: (_) {},
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(MoveIcon), findsNWidgets(Mood.values.length));
    for (final m in Mood.values) {
      expect(find.text(m.label), findsOneWidget);
    }
    expect(find.textContaining(RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true)), findsNothing);
  });
}
