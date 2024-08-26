
import 'package:lox/src/expr.dart';
import 'package:lox/src/scanner.dart';

import 'hindley_milner_lambda_calculus.dart';

LambdaCalculusExpression toLambdaCalculus(Expr loxExpression) => switch (loxExpression) {

    StringLiteral()                   => Lit(string_t),
    NumberLiteral()                   => Lit(num_t),
    NilLiteral()                      => Lit(unit_t),
    FalseLiteral() || TrueLiteral()   => Lit(bool_t),
    ListLiteral(elements: [])         => Lit(emptyList),

    Variable(name: Token(lexeme: final name)) =>
        Var(name),

    Lambda(:final params, body: ArrowExpression(:final body)) =>
        toAbs(params, body),

    Call(:final callee, args: ExpressionArgs(exprs: final args)) =>
        toApp(callee, args),

    LogicalAnd(:final left, :final right, :final keyword)
    || LogicalOr(:final left, :final right, :final keyword)
    || Binary(:final left, :final right, operator: final keyword) =>
        toApp(Variable(keyword), [left, right]),

    UnaryMinus(:final operator, :final expr) =>
        toApp(Variable(operator), [NumberLiteral(0), expr]),

    UnaryBang(:final operator, :final expr) =>
        toApp(Variable(operator), [expr]),

    Ternary(:final condition, :final ifTrue, :final ifFalse, :final questionMark) =>
        toApp(Variable(questionMark), [condition, ifTrue, ifFalse]),

    Grouping(:final expr) =>
        toLambdaCalculus(expr),

    Lambda(body: FunctionBody())
    || Call(args: ArgsWithPlaceholder())
    || ListLiteral(elements: [_, ...])
    || Record()
    || FieldAccess() =>
        throw 'unsupported $loxExpression',
  }
;

Abs toAbs(List<Token> params, Expr body) {
  final lcBody = toLambdaCalculus(body);
  return switch (params.reversed.map((x) => x.lexeme).toList()) {
    [] => Abs('_', lcBody),
    [final one] => Abs(one, lcBody),
    [final first, ...final rest] => rest.fold(
      Abs(first, lcBody),
      (body, param) => Abs(param, body),
    ),
  };
}

App toApp(Expr callee, List<Expr> args) {
  final lcFunc = toLambdaCalculus(callee);
  return switch (args.map(toLambdaCalculus).toList()) {
    [] => App(func: lcFunc, arg: Lit(unit_t)),
    [final one] => App(func: lcFunc, arg: one),
    [final first, ...final rest] => rest.fold(
      App(func: lcFunc, arg: first),
      (app, arg) => App(func: app, arg: arg),
    ),
  };
}
