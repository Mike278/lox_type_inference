import 'dart:io';

import 'package:lox/coordinator.dart';
import 'package:lox/interpreter.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';


final testDirectory = join(
  Directory.current.path,
  Directory.current.path.endsWith('test') ? '' : 'test',
);

void main() {
  test('examples dir', () {
    final exampleFiles = Directory(join(testDirectory, '..', 'examples'))
        .listSync()
        .whereType<File>();

    final allPrints = <String>[];
    for (final file in exampleFiles) {
      try {
        final (env, :prints) = eval(file);
        allPrints.add('====== ${basename(file.path)} =====');
        allPrints.addAll(prints.map((x) => '$x'));
      } catch (e, s) {
        fail('failed on $file\n$e\n$s');
      }
    }

    expect(
      allPrints,
      File(join(testDirectory, 'expected_examples_output.txt'))
          .readAsLinesSync(),
    );
  });
}

(Env, {List<Object?> prints}) eval(File file) {
  final prints = [];
  final env = runFile(
    file.path,
    Env.global(),
    (keyword, source, value) =>
      expect(
        value,
        isTrue,
        reason: 'lox `assert` failed: $source',
      ),
    (print: prints.add),
    (path) => Source(File(path).readAsStringSync()),
  );
  return (env, prints: prints);
}
