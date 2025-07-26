// ignore_for_file: non_constant_identifier_names
// ignore_for_file: constant_identifier_names

import 'package:lox/expr.dart';
import 'package:lox/hindley_milner_api.dart';
import 'package:lox/token.dart';
import 'package:lox/utils.dart';

class TypeInference {
  final ResolveImport import;
  TypeInference(this.import);

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

  Map<String, LoxType> inferStatement(Map<String, LoxType> env, int level, Statement statement, {
    required LoxType Function()? expectedReturnType
  }) {
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
        unify(type, expectedReturnType());

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
        final type = inferExpr(env, level, condition);
        unify(type, LoxType.bool);
        env = inferStatement(env, level, thenBranch, expectedReturnType: expectedReturnType);
        if (elseBranch != null) {
          env = inferStatement(env, level, elseBranch, expectedReturnType: expectedReturnType);
        }
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
      Grouping()       => inferExpr(env, level, expr.expr),
      Record()         => inferRecord(env, level, expr),
      RecordGet()      => inferRecordGet(env, level, expr),
      RecordUpdate()   => inferRecordUpdate(env, level, expr),
      ListLiteral()    => inferList(env, level, expr),
      TagConstructor() => inferTagConstructor(env, level, expr),
      TagMatch()       => inferTagMatch(env, level, expr),
      Ternary()        => inferTernary(env, level, expr),
      Import()         => inferImport(env, level, expr),
      UnaryMinus()     => inferUnaryOperation(env, level, expr),
      UnaryBang()      => inferUnaryOperation(env, level, expr),
      Binary(operator: Token(type: .PIPELINE)) => inferPipeline(env, level, expr),
      Binary(:final left, :final right, operator: final keyword)
      || LogicalOr(:final left, :final right, :final keyword)
      || LogicalAnd(:final left, :final right, :final keyword) =>
          inferBinaryOperation(
            env,
            level,
            left: left,
            right: right,
            operator: keyword,
            expr: expr,
          ),
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


  LoxType inferPipeline(Map<String, LoxType> env, int level, Binary expr) {
    final argType = inferExpr(env, level, expr.left);
    final functionType = inferExpr(env, level, expr.right);

    final evaluatesToType = LoxType.fresh(level);
    final expectedFunctionType = LoxType.function(
      from: [argType],
      to: evaluatesToType,
    );
    unify(
      functionType,
      expectedFunctionType,
    );
    return setType(expr, evaluatesToType);
  }

  LoxType inferUnaryOperation(Map<String, LoxType> env, int level, Unary expr) {

    final LoxType expectedOperationType = switch (expr) {
      UnaryMinus() => .function(from: [.num], to: .num),
      UnaryBang() => .function(from: [.bool], to: .bool),
    };

    final evaluatesToType = LoxType.fresh(level);
    final actualOperationType = LoxType.function(
      from: [
        inferExpr(env, level, expr.expr),
      ],
      to: evaluatesToType,
    );

    unify(
      expectedOperationType,
      actualOperationType,
    );
    return setType(expr, evaluatesToType);
  }

  LoxType inferBinaryOperation(Map<String, LoxType> env, int level, {
    required Expr left,
    required Expr right,
    required Token operator,
    required Expr expr,
  }) {

    final evaluatesToType = LoxType.fresh(level);
    final expectedOperationType = LoxType.function(
      from: [
        inferExpr(env, level, left),
        inferExpr(env, level, right),
      ],
      to: evaluatesToType,
    );

    final actualOperationType = inferExpr(env, level, Variable(operator));

    unify(
      expectedOperationType,
      actualOperationType,
    );
    return setType(expr, evaluatesToType);
  }

  LoxType inferTernary(Map<String, LoxType> env, int level, Ternary expr) {
    final evaluatesToType = LoxType.fresh(level);
    final expectedOperationType = LoxType.function(
      from: [
        inferExpr(env, level, expr.condition),
        inferExpr(env, level, expr.ifTrue),
        inferExpr(env, level, expr.ifFalse),
      ],
      to: evaluatesToType,
    );

    final actualOperationType = inferExpr(env, level, Variable(expr.questionMark));

    unify(
      expectedOperationType,
      actualOperationType,
    );
    return setType(expr, evaluatesToType);
  }

  LoxType inferRecord(Map<String, LoxType> env, int level, Record expr) {
    final actualType = LoxType.record({
      for (final (label, value) in expr.fields.pairs())
        label.lexeme: inferExpr(env, level, value),
    });
    return setType(expr, actualType);
  }

  LoxType inferRecordGet(Map<String, LoxType> env, int level, RecordGet expr) {
    final actualRecordType = inferExpr(env, level, expr.record);
    final expectedTailType = LoxType.fresh(level);
    final expectedFieldType = LoxType.fresh(level);
    final expectedRecordType = LoxType(
      TyRowExtend(
        newEntry: (expr.name.lexeme, expectedFieldType),
        row: expectedTailType,
      )
    );
    unify(expectedRecordType, actualRecordType);
    return setType(expr, expectedFieldType);
  }

  LoxType inferRecordUpdate(Map<String, LoxType> env, int level, RecordUpdate expr) {
    final actualRecordType = inferExpr(env, level, expr.record);
    final expectedRecordType = LoxType.fresh(level);
    final updatedRecordType = LoxType.recordUpdate(expectedRecordType, {
      for (final (label, value) in expr.newFields.pairs())
        label.lexeme: inferExpr(env, level, value),
    });
    unify(expectedRecordType, actualRecordType);
    return setType(expr, updatedRecordType);
  }

  LoxType inferImport(Map<String, LoxType> env, int level, Import expr) {
    final exports = import(expr.path);
    final module = exports.pairs().fold({...loxStandardLibraryEnv}, (moduleEnv, pair) {
      final (name, initializer) = pair;
      return inferLet(moduleEnv, 0, LetDeclaration(name, initializer));
    });
    final type = instantiate(level, LoxType.record({
      for (final (name, value) in module.pairs())
        if (!loxStandardLibraryEnv.containsKey(name)) // Don't export globals
          name: value,
    }));
    return setType(expr, LoxType(type));
  }

  LoxType inferList(Map<String, LoxType> env, int level, ListLiteral expr) {
    final elementType = LoxType.fresh(level);
    for (final element in expr.elements) {
      switch (element) {
        case ExpressionListElement(:final expr):
          final type = inferExpr(env, level, expr);
          unify(elementType, type);
        case SpreadListElement(:final expr):
          final type = inferExpr(env, level, expr);
          unify(LoxType.list(of: elementType), type);
      }
    }
    return setType(expr, .list(of: elementType));
  }

  LoxType inferTagConstructor(Map<String, LoxType> env, int level, TagConstructor expr) {
    final expectedPayloadType = expr.payload == null
        ? LoxType.unit
        : LoxType.fresh(level);

    final expectedVariantType = LoxType(
      TyVariant(
        TyRowExtend(
          newEntry: (expr.tag.lexeme, expectedPayloadType),
          row: LoxType.fresh(level),
        ),
      ),
    );

    if (expr.payload case final payload?) {
      unify(
        expectedPayloadType,
        inferExpr(env, level, payload),
      );
    }

    return setType(expr, expectedVariantType);
  }

  LoxType inferTagMatch(Map<String, LoxType> env, int level, TagMatch expr) {
    final LoxType expectedReturnType;
    LoxType casesRow;
    if (expr.defaultCase case (:var variable, arrow: _, :var result)) {
      final defaultType = LoxType.fresh(level);
      final resultEnv = {
        ...env,
        variable.lexeme: LoxType.variant(defaultType),
      };
      expectedReturnType = inferExpr(resultEnv, level, result);
      casesRow = defaultType;
    } else {
      expectedReturnType = .fresh(level);
      casesRow = .emptyRecord;
    }

    for (final (:tag, :payload, arrow: _, :result) in expr.cases) {
      if (payload == null) {
        final payloadType = LoxType.unit;
        final resultType = inferExpr(env, level, result);
        unify(expectedReturnType, resultType);
        casesRow = LoxType(TyRowExtend(
          newEntry: (tag.lexeme, payloadType),
          row: casesRow,
        ));
      } else {
        final payloadType = LoxType.fresh(level);
        final resultEnv = {
          ...env,
          payload.lexeme: payloadType,
        };
        final resultType = inferExpr(resultEnv, level, result);
        unify(expectedReturnType, resultType);
        casesRow = LoxType(TyRowExtend(
          newEntry: (tag.lexeme, payloadType),
          row: casesRow,
        ));
      }
    }

    final expectedVariantType = LoxType.variant(casesRow);
    final actualVariantType = inferExpr(env, level, expr.tag);
    unify(expectedVariantType, actualVariantType);
    return setType(expr, expectedReturnType);
  }

  LoxType inferFunction(Map<String, LoxType> env, int level, Lambda function) =>
    switch (function.body) {
      ArrowExpression(:final body) => inferArrowFunction(env, level, function, body),
      FunctionBody(:final body)    => inferBlockFunction(env, level, function, body),
    };

  LoxType inferArrowFunction(Map<String, LoxType> env, int level, Lambda function, Expr body) {
    final parameterTypes = typeVariablesForFunctionParameters(function.params, level);
    final returnType = inferExpr({...env, ...parameterTypes}, level, body);
    final functionType = LoxType.function(
      from: parameterTypes.values.toList(),
      to: returnType,
    );
    return setType(function, functionType);
  }

  LoxType inferBlockFunction(Map<String, LoxType> env, int level, Lambda function, Block body) {
    final parameters = typeVariablesForFunctionParameters(function.params, level);

    env = {
      ...env,
      ...parameters,
    };

    final returnType = LoxType.fresh(level);
    var hasReturnStatement = false;
    for (final statement in body.statements) {
      env = inferStatement(env, level, statement, expectedReturnType: () {
        hasReturnStatement = true;
        return returnType;
      });
    }

    final functionType = LoxType.function(
      from: parameters.values.toList(),
      to: hasReturnStatement ? returnType : .unit,
    );
    return setType(function, functionType);
  }

  Map<String, LoxType> typeVariablesForFunctionParameters(List<Token> params, int level) {
    if (params.isEmpty) {
      return { '_' : .fresh(level) };
    }
    return {
      for (final param in params)
        param.lexeme: .fresh(level)
    };
  }

  LoxType inferFunctionCall(Map<String, LoxType> env, int level, Call call) {
    final List<Expr> args;
    switch (call.args) {
      case ExpressionArgs(:final exprs):
        args = exprs;
      case ArgsWithPlaceholder args:
        return inferPartialFunctionCall(env, level, call, args);
    }

    final argTypes = args.isEmpty ? [LoxType.unit] : [
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
    final functionBody = Call(
      call.callee,
      ExpressionArgs([
        ...args.before,
        Variable(args.placeholder),
        ...args.after,
      ]),
      call.closingParen,
    );
    final function = Lambda(
        [args.placeholder],
        ArrowExpression(
          Token(.ARROW, '->', null, args.placeholder.line, args.placeholder.offset),
          functionBody,
        ),
    );
    final type = inferArrowFunction(env, level, function, functionBody);
    return setType(call, type);
  }

}

// [Ty] wrapper to enable dot shorthands for referencing lox-specific types
extension type LoxType(Ty inner) implements Ty {
  static final bool        = LoxType(TyFunctionApplication('Bool', []));
  static final num         = LoxType(TyFunctionApplication('Num', []));
  static final string      = LoxType(TyFunctionApplication('String', []));
  static final unit        = LoxType(TyFunctionApplication('Unit', []));
  static final emptyList   = LoxType(TyFunctionApplication('List', [a]));
  static final emptyRecord = LoxType(TyRowEmpty());
  static final list        = ({required LoxType of}) => LoxType(TyFunctionApplication('List', [of]));

  static final record = (Map<String, LoxType> fields) => LoxType(
    fields.fold(
      emptyRecord,
      (row, label, type) => TyRowExtend(
        newEntry: (label, type),
        row: row,
      )
    )
  );

  static final recordUpdate = (LoxType record, Map<String, LoxType> newFields) => LoxType(
    newFields.fold(
      record,
      (row, label, type) => TyRowExtend(
        newEntry: (label, type),
        row: row,
      )
    )
  );

  static final variant = (LoxType type) => LoxType(TyVariant(type));

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

final a = LoxType.freshGeneric();
final b = LoxType.freshGeneric();
final c = LoxType.freshGeneric();


final loxStandardLibraryEnv = <String, LoxType>{
  for (final symbol in {'+', '-', '*', '/'})   symbol : .function(from: [.num, .num], to: .num),
  for (final symbol in {'or', 'and'})          symbol : .function(from: [.bool, .bool], to: .bool),
  for (final symbol in {'>', '>=', '<', '<='}) symbol : .function(from: [.num, .num], to: .bool),
  for (final symbol in {'!=', '=='})           symbol : .function(from: [a, a], to: .bool),
  '?': .function(from: [.bool, a, a], to: a),
  'List' : .record({
    'first': .function(from: [.list(of: a)], to: a),
    'rest': .function(from: [.list(of: b)], to: .list(of: b)),
    'empty': .function(from: [.list(of: c)], to: .bool),
  }),
};

void normalizeProgramTypeVariableIds(List<Statement> statements) {
  for (final statement in statements) {
    for (final expr in statement.allExpressions()) {
      if (expr.type case final type?) {
        expr.type = LoxType(normalizeTypeVariableIds(type));
      }
    }
  }
}