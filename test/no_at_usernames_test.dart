import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('usernames are shown as plain names: no "@" is put in front of one anywhere in the app', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'@\$|@\{').hasMatch(lines[i])) offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });
}
