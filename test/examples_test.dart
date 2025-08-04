import 'dart:io';

import 'package:lox/coordinator.dart';
import 'package:lox/hindley_milner_api.dart';
import 'package:lox/interpreter.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

import '../bin/lox.dart' show dartIOReadFile;
import '../tryit/web/sample.dart' show sample;

final testDirectory = join(
  Directory.current.path,
  Directory.current.path.endsWith('test') ? '' : 'test',
);

final LoxAssertion testAssertion = (keyword, source, value) =>
  expect(
    value,
    isTrue,
    reason: 'lox `assert` failed: $source',
  );

void main() {
  test('tryit', () {
    final output = [];
    run(
      '',
      Source.memory(sample),
      Env.global(),
      testAssertion,
      (print: (x) {
        output.add(x.toString());
      }),
      (_) => fail('unexpected import'),
      checkTypes: true,
    );
    expect(output, [
      '[alice, bob, john, charlie, devin]',
      '{name: Bob Vance, company: Vance Refrigeration}',
      'Vance Refrigeration',
      'Bob Vance',
      '.Refrigeration',
      '0',
      '5',
      '-2',
      '2',
      '0',
      '51',
    ]);
  });
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
    testAssertion,
    (print: prints.add),
    dartIOReadFile,
  );
  return (env, prints: prints);
}
