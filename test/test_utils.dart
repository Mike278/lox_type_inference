
import 'package:lox/expr.dart';
import 'package:lox/hindley_milner_api.dart';
import 'package:lox/hindley_milner_lambda_calculus.dart';
import 'package:lox/lox_lambda_calculus.dart';
import 'package:lox/parser.dart';
import 'package:lox/scanner.dart';
import 'package:test/test.dart';

Expr parseExpression(String source) {
  if (!source.endsWith(';')) source = '$source;';
  final statements = parse(source);
  final expr = (statements.single as ExpressionStatement).expr;
  return expr;
}

List<Statement> parse(String source) {
  final (tokens, hadError: _) = scanTokens(source, fail);
  final (statements, hadError: _) = Parser(tokens, fail).parse();
  return statements;
}

Ty inferSource(String source) {
  if (!source.contains(';')) source = '$source;';
  final program = parse(source);
  final lambdaCalculus = transformStatements(program);
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