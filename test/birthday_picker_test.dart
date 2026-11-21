import 'package:calorie_app/l10n/app_strings.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/birthday_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

BirthdayModel model({DateTime? initial}) => BirthdayModel(
      earliest: DateTime(1920),
      latest: DateTime(2008, 6, 15),
      initial: initial,
    );

void main() {
  tearDown(() => AppStrings.active = 'en');

  group('BirthdayModel rules', () {
    test('starts on a sensible adult date when nothing is given', () {
      final m = model();
      expect(m.value.isAfter(DateTime(2008, 6, 15)), isFalse);
      expect(m.value.year, 1982);
    });

    test('a date too young is pulled back to the youngest allowed', () {
      expect(model(initial: DateTime(2015, 1, 1)).value, DateTime(2008, 6, 15));
    });

    test('a date before 1920 is pushed up to 1920', () {
      expect(model(initial: DateTime(1800, 3, 3)).value, DateTime(1920, 3, 3).isBefore(DateTime(1920)) ? DateTime(1920) : DateTime(1920, 1, 1));
    });

    test('31 January then February becomes the last real day', () {
      final m = model(initial: DateTime(1999, 1, 31));
      m.setMonth(2);
      expect(m.value, DateTime(1999, 2, 28));
    });

    test('29 February moves to the 28th in a year that has none', () {
      final m = model(initial: DateTime(2000, 2, 29));
      m.setYear(2001);
      expect(m.value, DateTime(2001, 2, 28));
    });

    test('29 February survives a leap year', () {
      final m = model(initial: DateTime(2000, 2, 29));
      m.setYear(1996);
      expect(m.value, DateTime(1996, 2, 29));
    });

    test('choosing the youngest year cannot pass the youngest date', () {
      final m = model(initial: DateTime(1990, 12, 25));
      m.setYear(2008);
      expect(m.value, DateTime(2008, 6, 15));
    });

    test('age counts whole years and respects the birthday this year', () {
      final m = model(initial: DateTime(1998, 3, 14));
      expect(m.ageOn(DateTime(2026, 3, 13)), 27);
      expect(m.ageOn(DateTime(2026, 3, 14)), 28);
      expect(m.ageOn(DateTime(2026, 12, 31)), 28);
    });

    test('decades cover every allowed year once, oldest first', () {
      final spans = model().decades();
      expect(spans.first.from, 1920);
      expect(spans.last.to, 2008);
      for (var i = 1; i < spans.length; i++) {
        expect(spans[i].from, spans[i - 1].to + 1);
      }
      expect(spans.last.from, 2000);
    });

    test('jumping to a decade lands in its middle', () {
      final m = model(initial: DateTime(1999, 5, 5));
      final span = m.decades().firstWhere((s) => s.from == 1980);
      m.jumpTo(span);
      expect(m.value.year, 1984);
      expect(m.inSpan(span), isTrue);
    });

    test('a decade label is short', () {
      expect(const DecadeSpan(1990, 1999).label, '1990–99');
    });
  });

  group('how dates read', () {
    test('English puts the month first', () {
      expect(birthdayFieldOrder('en'), [BirthdayField.month, BirthdayField.day, BirthdayField.year]);
      expect(formatBirthday(DateTime(1998, 3, 14), 'en'), 'Mar 14, 1998');
    });

    test('other languages put the day first', () {
      for (final l in ['es', 'fr', 'de', 'pt', 'it']) {
        expect(birthdayFieldOrder(l).first, BirthdayField.day);
      }
      expect(formatBirthday(DateTime(1998, 3, 14), 'fr'), '14 Mar 1998');
    });

    test('there are twelve month names', () {
      expect(shortMonthNames(), hasLength(12));
    });
  });

  group('the sheet', () {
    Future<void> open(WidgetTester tester, BirthdayModel m, {ValueChanged<DateTime>? onDone}) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: CupertinoPageScaffold(
          child: SafeArea(
            child: SingleChildScrollView(
              child: BirthdaySheet(model: m, today: DateTime(2026, 11, 21), onDone: onDone ?? (_) {}),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the date and the age', (tester) async {
      await open(tester, model(initial: DateTime(1998, 3, 14)));
      expect(find.text('Mar 14, 1998'), findsOneWidget);
      expect(find.text("You're 28 years old"), findsOneWidget);
    }, variant: ios);

    testWidgets('a decade chip moves the year and the readout', (tester) async {
      await open(tester, model(initial: DateTime(1998, 3, 14)));
      await tester.ensureVisible(find.byKey(const ValueKey('decade_1980')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('decade_1980')));
      await tester.pumpAndSettle();
      expect(find.text('Mar 14, 1984'), findsOneWidget);
      expect(find.text("You're 42 years old"), findsOneWidget);
    }, variant: ios);

    testWidgets('Done hands back the chosen date', (tester) async {
      DateTime? got;
      await open(tester, model(initial: DateTime(1998, 3, 14)), onDone: (d) => got = d);
      await tester.drag(find.byKey(const ValueKey('decade_1990')), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('decade_2000')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('birthday_done')));
      expect(got, DateTime(2004, 3, 14));
    }, variant: ios);

    testWidgets('the sheet shows the 18+ reminder', (tester) async {
      await open(tester, model());
      expect(find.text('You need to be 18 or older.'), findsOneWidget);
    }, variant: ios);

    testWidgets('outside English the day wheel comes first', (tester) async {
      AppStrings.active = 'es';
      await open(tester, model(initial: DateTime(1998, 3, 14)));
      final day = tester.getTopLeft(find.byKey(const ValueKey('birthday_day'))).dx;
      final month = tester.getTopLeft(find.byKey(const ValueKey('birthday_month'))).dx;
      expect(day < month, isTrue);
    }, variant: ios);
  });
}
