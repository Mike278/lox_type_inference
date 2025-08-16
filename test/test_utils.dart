
import 'dart:io';

import 'package:lox/coordinator.dart';
import 'package:lox/expr.dart';
import 'package:lox/hindley_milner_lox.dart';
import 'package:lox/interpreter.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

Expr parseExpression(String source) {
  if (!source.endsWith(';')) source = '$source;';
  final statements = parse(Source.memory(source));
  final expr = (statements.single as ExpressionStatement).expr;
  return expr;
}

final ReadFile noImports = (_) => fail('no import resolver');

List<Statement> inferSource(String source, [ReadFile? readFile]) {
  if (!source.contains(';')) source = '$source;';
  readFile ??= noImports;
  final (statements, resolveImport) = parseSourceAndResolveImports(
    '',
    Source.memory(source),
    readFile,
  );
  TypeInference(resolveImport).inferProgramTypes(statements);
  normalizeProgramTypeVariableIds(statements);
  return statements;
}

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

Never unexpectedImport(String path) => fail('unexpected import $path');

Never unexpectedPrint(x) => fail('unexpected print: $x');

void runSource(
  String source, {
  bool checkTypes = true,
  ReadFile import = unexpectedImport,
  RuntimeIO io = const (print: unexpectedPrint),
}) {
    run(
    '',
    Source.memory(source),
    Env.global(),
    testAssertion,
    io,
    unexpectedImport,
    checkTypes: true,
  );
}