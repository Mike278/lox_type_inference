// ignore_for_file: slash_for_doc_comments
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: constant_identifier_names

import 'package:lox/expr.dart';
import 'package:lox/hindley_milner_api.dart';
import 'package:lox/scanner.dart';
import 'package:lox/utils.dart';

import 'hindley_milner_lambda_calculus.dart';

var _i = 0;
Token _synthesizeNewIdentifier(int line, int offset) {
  final id = 'x#${_i++}';
  return Token(TokenType.IDENTIFIER, id, id, line, offset);
}

Map<Expr, MonoType> runInference(List<Statement> statements) {
  TypeVariable.counter = 0;
  final context = {...loxStandardLibraryContext};
  final expr = transformStatements(statements);
  final (sub, :overallType, :subExpressionTypes) = w(expr, context);
  final typeOf = {
    for (final (expr, lc) in _exprLog.pairs())
      if (subExpressionTypes[lc] case final type?)
        expr: type,
  };
  _exprLog.clear();
  return typeOf;
}

LambdaCalculusExpression transformStatements(List<Statement> statements) {
  if (statements.isEmpty) return Lit(unit_t);
  final [first, ...rest] = statements;

  return switch (first) {
    ReturnStatement(:final expr?) =>
        toLambdaCalculus(expr),

    ReturnStatement(expr: null) =>
        toLambdaCalculus(NilLiteral()),

    PrintStatement(:final expr) ||
    AssertStatement(:final expr) ||
    ExpressionStatement(:final expr) =>
        rest.isEmpty
          ? toLambdaCalculus(expr)
          : _continue(
              toLambdaCalculus(expr),
              Abs('_', transformStatements(rest)),
            ),

    LetDeclaration(:final name, :final initializer) =>
      Let(
        name.lexeme,
        toLambdaCalculus(initializer),
        rest.isEmpty
          ? Var(name.lexeme)
          : transformStatements(rest),
      ),

    IfStatement(
      :final condition,
      :final thenBranch,
      :final elseBranch,
    ) =>
        App(func: App(func: App(func: Var('?'),
            arg: toLambdaCalculus(condition)),
            arg: transformStatements([
              if (thenBranch case Block(:final statements)) ...statements
              else thenBranch,
              ...rest,
            ])),
            arg: transformStatements([
              if (elseBranch case Block(:final statements)) ...statements
              else if (elseBranch != null) elseBranch,
              ...rest,
            ])),

    Block(statements: []) => transformStatements([]),
    Block(:final statements) =>
      rest.isEmpty
        ? transformStatements(statements)
        : _continue(
            transformStatements(statements),
            Abs('_', transformStatements(rest)),
          ),
  };
}

final _exprLog = <Expr, LambdaCalculusExpression>{};
LambdaCalculusExpression toLambdaCalculus(Expr loxExpression) {
  final lc = _toLambdaCalculus(loxExpression);
  _exprLog[loxExpression] = lc;
  return lc;
}

LambdaCalculusExpression _toLambdaCalculus(Expr loxExpression) => switch (loxExpression) {

    StringLiteral()       => Lit(string_t),
    NumberLiteral()       => Lit(num_t),
    NilLiteral()          => Lit(unit_t),
    FalseLiteral() || TrueLiteral()   => Lit(bool_t),
    ListLiteral(elements: [])         => Lit(emptyList_t),

    Variable(name: Token(lexeme: final name)) =>
        Var(name),

    Lambda(:final params, body: ArrowExpression(:final body)) =>
        toAbs(params, body),

    Call(
      :final callee,
      args: ArgsWithPlaceholder(:final before, :final after),
      :final closingParen,
    ) =>
        switch (_synthesizeNewIdentifier(closingParen.line, closingParen.offset)) {
          final param => toAbs(
              [param],
              Call(
                callee,
                ExpressionArgs([...before, Variable(param), ...after]),
                closingParen,
              ),
            )
        },

    Call(:final callee, args: ExpressionArgs(exprs: final args)) =>
        toApp(callee, args),

    Binary(:final left, :final right, operator: Token(type: TokenType.PIPELINE)) =>
        toApp(right, [left]),

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

    Lambda(:final params, body: FunctionBody(body: Block(:final statements, :final closeBrace))) =>
      _toAbs(
        [for (final p in params) p.lexeme],
        transformStatements([
          ...statements,
          if (!endsWithReturn(statements))
            ReturnStatement(closeBrace, NilLiteral()),
        ]),
      ),
  }
;

bool endsWithReturn(List<Statement> statements) => switch (statements) {
  [..., ReturnStatement()] => true,
  [..., Block(:final statements)] => endsWithReturn(statements),
  _ => false,
};

Abs toAbs(List<Token> params, Expr body) =>
  _toAbs([for (final p in params) p.lexeme], toLambdaCalculus(body));

Abs _toAbs(List<String> params, LambdaCalculusExpression body) =>
  switch (params.reversed.toList()) {
    [] => Abs('_', body),
    [final one] => Abs(one, body),
    [final first, ...final rest] => rest.fold(
      Abs(first, body),
      (body, param) => Abs(param, body),
    ),
  };

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

App _continue(LambdaCalculusExpression m, LambdaCalculusExpression f) => App(
  func: App(func: Var('#continuation'), arg: m),
  arg: f,
);


const bool_t = TypeFunctionApplication('Bool', []);
const num_t = TypeFunctionApplication('Num', []);
const string_t = TypeFunctionApplication('String', []);
const unit_t = TypeFunctionApplication('Unit', []);
final list_t = (MonoType of) => TypeFunctionApplication('List', [of]);
final function_t = (MonoType from, MonoType to) => TypeFunctionApplication('Function', [from, to]);
final var_t = TypeVariable.new;
final forall = TypeQuantifier.new;
final emptyList_t = forall('a', list_t(var_t('a')));
final record_empty_t = TypeRowEmpty();
final record_t = (Map<String, MonoType> fields) => fields.fold<MonoType>(
    record_empty_t,
    (row, label, type) => TypeRowExtend(
      newEntry: (label, type),
      row: row,
    )
);

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
  '#continuation': forall('a', forall('b', function_t(a, function_t(function_t(a, b), b)))),
};

typedef DisplayTypeVariable = String Function(int index);

String displayIndexed(int i) => 't$i';
String displayAlpha(int i) => String.fromCharCode(97 + i % 26) * (i ~/ 26 + 1);

MonoType normalizeTypeVariableIds(
  MonoType t, [
  DisplayTypeVariable display = displayIndexed,
]) {
  final namesSorted =
    collectTypeVariables({}, t)
      .where((name) => extractTypeVariableId(name) != null)
      .toList();

  String lookup(String name) =>
    namesSorted.contains(name)
      ? display(namesSorted.indexOf(name))
      : name;

  return rename(t, lookup);
}

MonoType rename(MonoType t, String Function(String) lookup) => switch (t) {
  TypeVariable(:final name) => TypeVariable(lookup(name)),
  TypeFunctionApplication(:final name, :final monoTypes) => TypeFunctionApplication(
    lookup(name),
    [ for (final t in monoTypes) rename(t, lookup) ]
  ),
  TypeRowEmpty() => t,
  TypeRowExtend(:final label, :final type, :final row) => TypeRowExtend(
    newEntry: (label, rename(type, lookup)),
    row: rename(row, lookup),
  ),
};

Set<String> collectTypeVariables(Set<String> state, MonoType t) => {
  ...state,
  ...switch (t) {
    TypeVariable(:final name) => {name},
    TypeFunctionApplication(:final name, :final monoTypes) => {
      name,
      for (final t in monoTypes)
        ...collectTypeVariables(state, t),
    },
    TypeRowEmpty() => { },
    TypeRowExtend(:final type, :final row) => {
      ...collectTypeVariables(state, row),
      ...collectTypeVariables(state, type),
    }
  }
};

int? extractTypeVariableId(String s) =>
  s.startsWith('t') ? int.parse(s.substring(1)) : null;
