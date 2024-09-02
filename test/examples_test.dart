import 'dart:io';

import 'package:lox/src/env.dart';
import 'package:lox/src/interpreter.dart';
import 'package:lox/src/parser.dart';
import 'package:lox/src/scanner.dart';
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
      final source = file.readAsStringSync();
      final (env, :prints, :runtimeErrors) = evalSource(source);
      expect(runtimeErrors, isEmpty);
      allPrints.addAll(prints.map((x) => '$x'));
    }

    expect(
      allPrints,
      File(join(testDirectory, 'expected_examples_output.txt'))
          .readAsLinesSync(),
    );
  });
}

(Env, {List<Object?> prints, List<String> runtimeErrors}) evalSource(String source) {
  final (tokens, hadError: _) = scanTokens(source, fail);
  final (statements, hadError: _) = Parser(tokens, fail).parse();
  final errors = <String>[];
  final prints = [];
  final (env, :hadRuntimeError) = LoxRuntime(
    errors.add,
    (keyword, source, value) => expect(
      value,
      isTrue,
      reason: 'lox `assert` failed: $source',
    ),
    (print: prints.add),
  ).interpret(
    statements,
    Env.global(),
  );
  return (env, runtimeErrors: errors, prints: prints);
}
