
import 'package:lox/src/expr.dart';
import 'package:lox/src/hindley_milner_api.dart';
import 'package:lox/src/scanner.dart';
import 'package:lox/src/utils.dart';

import 'hindley_milner_lambda_calculus.dart';

LambdaCalculusExpression toLambdaCalculus(Expr loxExpression) => switch (loxExpression) {

    StringLiteral()                   => Lit(string_t),
    NumberLiteral()                   => Lit(num_t),
    NilLiteral()                      => Lit(unit_t),
    FalseLiteral() || TrueLiteral()   => Lit(bool_t),
    ListLiteral(elements: [])         => Lit(emptyList_t),

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

    ListLiteral(:final elements, :final closingBracket) =>
        toList(elements, closingBracket),

    Record(:final fields) =>
        fields.fold(
          RecordEmpty(),
          (record, label, field) => RecordExtension(
            label.lexeme,
            toLambdaCalculus(field),
            record,
          ),
        ),
    RecordGet(:final record, :final name) =>
        RecordSelection(
          name.lexeme,
          toLambdaCalculus(record),
        ),

    RecordUpdate(:final record, :final newFields) =>
      newFields.fold(
        toLambdaCalculus(record),
        (record, label, field) => RecordExtension(
          label.lexeme,
          toLambdaCalculus(field),
          record,
        ),
      ),

    Lambda(body: FunctionBody(body: Block())) ||
    Call(args: ArgsWithPlaceholder()) =>
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

LambdaCalculusExpression toLet(List<LetDeclaration> statements) {
  final body = Var(statements.last.name.lexeme);
  final lets = [
    for (final statement in statements.reversed) (
      name: statement.name.lexeme,
      expr: toLambdaCalculus(statement.initializer),
    )
  ];
  return switch (lets) {
    [] => body,
    [(:final name, :final expr)] => Let(name, expr, body),
    [(:final name, :final expr), ...final rest] =>
      rest.fold(
        Let(name, expr, body),
        (let, statement) => Let(
          statement.name,
          statement.expr,
          let,
        ),
      ),
  };
}

LambdaCalculusExpression toList(
  List<ListElement> elements,
  Token closingBracket,
) =>
    // Normalize to list of lists, then concat them all:
    // [1, ..[2, 3], 4]  ->  [[1], [2, 3], [4]]  ->  [1, 2, 3, 4]
    elements
      .map(normalizeListElement)
      .fold(
        Var('[]'),
        (list, element) =>
          // ((List#Concat list) element)
          App(func: App(func: Var('List#Concat'), arg: list), arg: element),
      );

LambdaCalculusExpression normalizeListElement(ListElement element) =>
  switch (element) {
    SpreadListElement(:final expr) => toLambdaCalculus(expr),
    ExpressionListElement(:final expr) => App(
      func: App(func: Var('List#Add'), arg: Var('[]')),
      arg: toLambdaCalculus(expr),
    ),
  };


final a = var_t('a');
final b = var_t('b');
final c = var_t('c');

final Context loxStandardLibraryContext = {
  for (final symbol in {'+', '-', '*', '/'})   symbol : function_t(num_t, function_t(num_t, num_t)),
  for (final symbol in {'or', 'and'})          symbol : function_t(bool_t, function_t(bool_t, bool_t)),
  for (final symbol in {'>', '>=', '<', '<='}) symbol : function_t(num_t, function_t(num_t, bool_t)),
  for (final symbol in {'!=', '=='})           symbol : forall('a', function_t(a, function_t(a, bool_t))),
  '!': function_t(bool_t, bool_t),
  '?': forall('a', function_t(bool_t, function_t(a, function_t(a, a)))),
  '[]': emptyList_t,
  'nil': unit_t,
  'true': bool_t,
  'false': bool_t,
  'List#Add': forall('a', function_t(list_t(a), function_t(a, list_t(a)))),
  'List#Concat': forall('a', function_t(list_t(a), function_t(list_t(a), list_t(a)))),
  'List' : forall('a', forall('b', forall('c', record_t({
    'first': function_t(list_t(a), a),
    'rest': function_t(list_t(b), list_t(b)),
    'empty': function_t(list_t(c), bool_t),
  })))),
};