import 'dart:io';

import 'package:lox/coordinator.dart';
import 'package:lox/hindley_milner_api.dart';
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

    final expectedErrors = {
      'make_counter.lox': isA<RecursiveRowTypes>(),
    };

    final allPrints = <String>[];
    for (final file in exampleFiles) {
      try {
        allPrints.add('====== ${basename(file.path)} =====');
        final (env, :prints) = eval(file);
        allPrints.addAll(prints.map((x) => '$x'));
      } catch (e, s) {
        if (expectedErrors[basename(file.path)] case final matcher?) {
          expect(e, matcher);
          allPrints.add(matcher.describe(StringDescription()).toString());
        } else {
          fail('failed on $file\n$e\n$s');
        }
      }
    }

    expect(
      allPrints,
      File(join(testDirectory, 'expected_examples_output.txt'))
          .readAsLinesSync(),
      reason: 'updated content:\n${allPrints.join('\n')}'
    );
  });
}

(Env, {List<Object?> prints}) eval(File file) {
  final prints = [];
  final env = runFile(
    checkTypes: true,
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
