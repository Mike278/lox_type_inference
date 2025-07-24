// ignore_for_file: non_constant_identifier_names
// ignore_for_file: constant_identifier_names

import 'package:lox/expr.dart';
import 'package:lox/hindley_milner_api.dart';
import 'package:lox/utils.dart';

void inferProgramTypes(List<Statement> statements) {
  statements = statements.desugar();
  TyVariable.counter = 0;
  var globalEnv = loxStandardLibraryEnv;
  final level = 0;
  for (final statement in statements) {
    globalEnv = inferStatement(globalEnv, level, statement, expectedReturnType: null);
  }
  for (final statement in statements) {
    for (final expr in statement.allExpressions()) {
      if (expr.type case final type?) {
        expr.type = LoxType(generalize(-1, type));
      }
    }
  }
}

Map<String, LoxType> inferStatement(Map<String, LoxType> env, int level, Statement statement, {required LoxType? expectedReturnType}) {
  switch (statement) {
    case Destructuring():
      throw StateError('bug; destructuring shouldve been desugared');

    case ReturnStatement(:final expr):
      if (expectedReturnType == null) {
        throw TopLevelReturn();
      }
      final type = expr == null
          ? LoxType.unit
          : inferExpr(env, level, expr);
      unify(type, expectedReturnType);

    case ExpressionStatement(:final expr):
    case PrintStatement(:final expr):
    case AssertStatement(:final expr):
      final _ = inferExpr(env, level, expr);

    case LetDeclaration():
      env = inferLet(env, level, statement);

    case Block(:final statements):
      var localEnv = {...env};
      for (final statement in statements) {
        localEnv = inferStatement(localEnv, level, statement, expectedReturnType: expectedReturnType);
      }

    case IfStatement(
      :final condition,
      :final thenBranch,
      :final elseBranch,
    ):
      throw UnimplementedError();

  }

  return env;
}

Map<String, LoxType> inferLet(Map<String, LoxType> env, int level, LetDeclaration let) {
  final name = let.name.lexeme;
  final expr = let.initializer;
  final nextLevel = level+1;
  final maybeRecursive = LoxType.fresh(nextLevel);
  final maybeRecursiveEnv = {
    ...env,
    // [initializer] might reference [name], so add it to the env with a
    // fresh type variable and let it get resolved normally
    name: maybeRecursive,
  };
  final type = inferExpr(maybeRecursiveEnv, nextLevel, expr);

  // tie together the self reference (if any)
  unify(maybeRecursive, type);

  final generalizedType = LoxType(generalize(level, type));
  return {
    ...env,
    name: generalizedType,
  };
}

LoxType inferExpr(Map<String, LoxType> env, int level, Expr expr) =>
  switch (expr) {
    Literal()        => inferLiteral(env, level, expr),
    Variable()       => inferVariable(env, level, expr),
    Call()           => inferFunctionCall(env, level, expr),
    Lambda()         => inferFunction(env, level, expr),
    Binary()         => throw UnimplementedError(),
    LogicalAnd()     => throw UnimplementedError(),
    LogicalOr()      => throw UnimplementedError(),
    Grouping()       => throw UnimplementedError(),
    Ternary()        => throw UnimplementedError(),
    Record()         => throw UnimplementedError(),
    RecordGet()      => throw UnimplementedError(),
    RecordUpdate()   => throw UnimplementedError(),
    ListLiteral()    => throw UnimplementedError(),
    TagConstructor() => throw UnimplementedError(),
    TagMatch()       => throw UnimplementedError(),
    Import()         => throw UnimplementedError(),
    UnaryMinus()     => throw UnimplementedError(),
    UnaryBang()      => throw UnimplementedError()
  };

LoxType setType(Expr expr, LoxType type) {
  expr.type = type;
  return type;
}

LoxType inferLiteral(Map<String, LoxType> env, int level, Literal literal) {
  final LoxType type = switch (literal) {
    StringLiteral() => .string,
    NumberLiteral() => .num,
    FalseLiteral() => .bool,
    TrueLiteral() => .bool,
    NilLiteral() => .unit,
  };
  final instance = LoxType(instantiate(level, type));
  return setType(literal, instance);
}

LoxType inferVariable(Map<String, LoxType> env, int level, Variable variable) {
  final name = variable.name.lexeme;
  final type = env[name];
  if (type == null) {
    throw UndefinedVariable(name);
  } else {
    final instance = LoxType(instantiate(level, type));
    return setType(variable, instance);
  }
}

LoxType inferFunction(Map<String, LoxType> env, int level, Lambda function) => 
  switch (function.body) {
    ArrowExpression(:final body) => inferArrowFunction(env, level, function, body),
    FunctionBody(:final body)    => inferBlockFunction(env, level, function, body),
  };

LoxType inferArrowFunction(Map<String, LoxType> env, int level, Lambda function, Expr body) {
  final parameterTypes = {
    for (final param in function.params)
      param.lexeme: LoxType.fresh(level)
  };
  final returnType = inferExpr({...env, ...parameterTypes}, level, body);
  final functionType = LoxType.function(
    from: parameterTypes.values.toList(),
    to: returnType,
  );
  return setType(function, functionType);
}

LoxType inferBlockFunction(Map<String, LoxType> env, int level, Lambda function, Block body) {
  final parameters = {
    for (final param in function.params)
      param.lexeme: LoxType.fresh(level)
  };
  
  env = {
    ...env,
    ...parameters,
  };

  final returnType = LoxType.fresh(level);
  for (final statement in body.statements) {
    env = inferStatement(env, level, statement, expectedReturnType: returnType);
  }
  
  final functionType = LoxType.function(
    from: parameters.values.toList(),
    to: returnType,
  );
  return setType(function, functionType);
}

LoxType inferFunctionCall(Map<String, LoxType> env, int level, Call call) {
  final List<Expr> args;
  switch (call.args) {
    case ExpressionArgs(:final exprs):
      args = exprs;
    case ArgsWithPlaceholder args:
      return inferPartialFunctionCall(env, level, call, args);
  }
  
  final argTypes = [
    for (final expr in args)
      inferExpr(env, level, expr)
  ];
  final evaluatesToType = LoxType.fresh(level);
  final expectedFunctionType = LoxType.function(
    from: argTypes,
    to: evaluatesToType,
  );
  final actualFunctionType = inferExpr(env, level, call.callee);
  unify(
    actualFunctionType,
    expectedFunctionType,
  );
  return setType(call, evaluatesToType);
}

LoxType inferPartialFunctionCall(Map<String, LoxType> env, int level, Call call, ArgsWithPlaceholder args) {
  throw UnimplementedError();
}

// [Ty] wrapper to enable dot shorthands for referencing lox-specific types
extension type LoxType(Ty inner) implements Ty {
  static final bool        = LoxType(TyFunctionApplication('Bool', []));
  static final num         = LoxType(TyFunctionApplication('Num', []));
  static final string      = LoxType(TyFunctionApplication('String', []));
  static final unit        = LoxType(TyFunctionApplication('Unit', []));
  static final emptyList   = LoxType(TyFunctionApplication('List', [a]));
  static final emptyRecord = LoxType(TyRowEmpty());
  static final list        = (LoxType of) => LoxType(TyFunctionApplication('List', [of]));

  static final record = (Map<String, LoxType> fields) => LoxType(
    fields.fold(
      emptyRecord,
      (row, label, type) => TyRowExtend(
        newEntry: (label, type),
        row: row,
      )
    )
  );

  static final function = ({
    required List<LoxType> from,
    required LoxType to,
  }) {
    final [first, ...rest] = from.reversed.toList();
    return LoxType(rest.fold(
      TyFunctionApplication('Function', [first, to]),
      (state, param) => TyFunctionApplication('Function', [param, state]),
    ));
  };

  static final freshGeneric = () => LoxType(TyVariable.freshGeneric());
  static final fresh = (int level) => LoxType(TyVariable.fresh(level));
}

final a = LoxType(TyVariable.freshGeneric());
final b = LoxType(TyVariable.freshGeneric());
final c = LoxType(TyVariable.freshGeneric());


final loxStandardLibraryEnv = <String, LoxType>{
  for (final symbol in {'+', '-', '*', '/'})   symbol : .function(from: [.num, .num], to: .num),
  for (final symbol in {'or', 'and'})          symbol : .function(from: [.bool, .bool], to: .bool),
  for (final symbol in {'>', '>=', '<', '<='}) symbol : .function(from: [.num, .num], to: .bool),
  for (final symbol in {'!=', '=='})           symbol : .function(from: [a, a], to: .bool),
  '#-': .function(from: [.num], to: .num),
  '!': .function(from: [.bool], to: .bool),
  '?': .function(from: [.bool, a, a], to: a),
  '[]': .emptyList,
  'nil': .unit,
  'true': .bool,
  'false': .bool,
  'List#Add': .function(from: [.list(a), a], to: .list(a)),
  'List#Concat': .function(from: [.list(a), .list(a)], to: .list(a)),
  'List' : .record({
    'first': .function(from: [.list(a)], to: a),
    'rest': .function(from: [.list(b)], to: .list(b)),
    'empty': .function(from: [.list(c)], to: .bool),
  }),
  '#continuation': .function(from: [a, .function(from: [a], to: b)], to: b),
};