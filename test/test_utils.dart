
import 'package:lox/coordinator.dart';
import 'package:lox/expr.dart';
import 'package:lox/hindley_milner_api.dart';
import 'package:lox/hindley_milner_lambda_calculus.dart';
import 'package:lox/lox_lambda_calculus.dart';
import 'package:test/test.dart';

Expr parseExpression(String source) {
  if (!source.endsWith(';')) source = '$source;';
  final statements = parse(Source(source));
  final expr = (statements.single as ExpressionStatement).expr;
  return expr;
}

final ReadFile noImports = (_) => fail('no import resolver');

Ty inferSource(String source, [ReadFile? readFile]) {
  if (!source.contains(';')) source = '$source;';
  readFile ??= noImports;
  final (statements, resolveImport) = parseSourceAndResolveImports(
    '',
    Source(source),
    readFile,
  );
  final lambdaCalculus = transformStatements(statements, resolveImport);
  return infer(lambdaCalculus);
}

Ty infer(LambdaCalculusExpression expr) {
  TyVariable.counter = 0;
  final (:overallType, :subExpressionTypes) = algorithmW(expr, newDefaultContext());
  final normalized = normalizeTypeVariableIds(overallType);
  return normalized;
}

Map<String, Ty> newDefaultContext() => {
  ...loxStandardLibraryContext,
};