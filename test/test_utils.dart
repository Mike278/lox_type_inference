
import 'package:lox/src/expr.dart';
import 'package:lox/src/parser.dart';
import 'package:lox/src/scanner.dart';
import 'package:test/test.dart';

Expr parseExpression(String source) {
  if (!source.endsWith(';')) source = '$source;';
  final (tokens, hadError: _) = scanTokens(source, fail);
  final (statements, hadError: _) = Parser(tokens, fail).parse();
  final expr = (statements.single as ExpressionStatement).expr;
  return expr;
}

List<Statement> parse(String source) {
  final (tokens, hadError: _) = scanTokens(source, fail);
  final (statements, hadError: _) = Parser(tokens, fail).parse();
  return statements;
}
