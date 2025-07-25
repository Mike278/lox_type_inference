
import 'package:lox/coordinator.dart';
import 'package:lox/expr.dart';
import 'package:lox/hindley_milner_api.dart';
import 'package:lox/hindley_milner_lox.dart';
import 'package:test/test.dart';

Expr parseExpression(String source) {
  if (!source.endsWith(';')) source = '$source;';
  final statements = parse(Source(source));
  final expr = (statements.single as ExpressionStatement).expr;
  return expr;
}

final ReadFile noImports = (_) => fail('no import resolver');

List<Statement> inferSource(String source, [ReadFile? readFile]) {
  if (!source.contains(';')) source = '$source;';
  readFile ??= noImports;
  final (statements, resolveImport) = parseSourceAndResolveImports(
    '',
    Source(source),
    readFile,
  );
  inferProgramTypes(statements);
  for (final statement in statements) {
    for (final expr in statement.allExpressions()) {
      if (expr.type case final type?) {
        expr.type = LoxType(normalizeTypeVariableIds(type));
      }
    }
  }
  return statements;
}
