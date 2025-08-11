import 'dart:io';

import 'package:lox/coordinator.dart';
import 'package:lox/hindley_milner_lox.dart';
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

    final allPrints = <String>[];
    for (final file in exampleFiles) {
      allPrints.add('====== ${basename(file.path)} =====');
      final prints = eval(file);
      allPrints.addAll(prints.map((x) => '$x'));
    }

    File(
      join(testDirectory, 'expected_examples_output.txt'),
    ).writeAsString(
      allPrints.join('\n'),
    );
  });
}

List<Object?> eval(File file) {
  final prints = [];
  final relativeToDir = dirname(file.path);
  final (statements, resolveImport) = parseSourceAndResolveImports(
    relativeToDir,
    Source(dartIOReadFile(file.path), path: file.path),
    dartIOReadFile,
  );

  try {
    TypeInference(resolveImport).inferProgramTypes(statements);
  } catch (e) {
    prints.add('___ Type checking failed ___');
    prints.add('$e');
    prints.add('___ Continuing with execution ___');
  }

  LoxRuntime(
    testAssertion,
    (print: prints.add),
    resolveImport,
  ).interpret(
    statements,
    Env.global(),
  );

  return prints;
}
