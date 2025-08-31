import 'dart:io';

import 'package:lox/coordinator.dart';
import 'package:lox/hindley_milner_lox.dart';
import 'package:lox/interpreter.dart';
import 'package:lox/mark_types.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

import '../bin/lox.dart' show dartIOReadFile;
import 'test_utils.dart';


void main() {
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
  final output = [];
  final relativeToDir = dirname(file.path);
  final source = Source(dartIOReadFile(file.path), path: file.path);
  final (statements, resolveImport) = parseSourceAndResolveImports(
    relativeToDir,
    source,
    dartIOReadFile,
  );

  try {
    TypeInference(resolveImport).inferProgramTypes(statements);
    final (marks, errorOutput: _) = markTypes(relativeToDir, source, dartIOReadFile);
    final fmt = (CodePosition pos) => [pos.line, pos.offset].join(':');
    output.add('___ TYPES ___');
    for (final (span, :display, isError: _) in marks) {
      final location = '${fmt(span.from)} - ${fmt(span.to)}'.padRight(14);
      output.add('$location $display');
    }
  } catch (e) {
    output.add('___ Type checking failed ___');
    output.add('$e');
    output.add('___ Continuing with execution ___');
  }

  output.add('___ OUTPUT ___');
  try {
    LoxRuntime(
      testAssertion,
      (print: output.add),
      resolveImport,
    ).interpret(
      statements,
      Env.global(),
    );
  } catch (e, s) {
    output.add(e);
    print(s);
  }
  output.add('');
  output.add('');

  return output;
}
