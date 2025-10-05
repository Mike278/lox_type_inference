// ignore_for_file: non_constant_identifier_names
// ignore_for_file: constant_identifier_names

import 'package:lox/expr.dart';
import 'package:lox/hindley_milner_api.dart';
import 'package:lox/token.dart';
import 'package:lox/utils.dart';

class TypeInference {
  final ResolveImport import;
  final _returnStack = <_CurrentFunction>[];
  TypeInference(this.import);

  void inferProgramTypes(List<Statement> statements) {
    statements = statements;
    TyVariable.counter = 0;
    var globalEnv = loxStandardLibraryEnv;
    final level = 0;
    for (final statement in statements) {
      globalEnv = inferStatement(globalEnv, level, statement);
    }
    for (final statement in statements) {
      for (final expr in statement.allExpressions()) {
        if (expr.type case final type?) {
          expr.type = LoxType(generalize(-1, type));
        }
      }
      final allPatterns = statement.allPatterns().toList();
      for (final pat in allPatterns) {
        switch (pat) {
          case Identifier():
            if (pat.type case final type?) {
              pat.type = LoxType(generalize(-1, type));
            }
          case RecordDestructure(:final elements):
            for (final e in elements) {
              if (e.type case final type?) {
                e.type = LoxType(generalize(-1, type));
              }
            }
          case TagPattern():
            if (pat.type case final type?) {
              pat.type = LoxType(generalize(-1, type));
            }
        }
      }
    }
  }

  Map<String, LoxType> inferStatement(Map<String, LoxType> env, int level, Statement statement) {
    switch (statement) {

      case ExpressionStatement(:final expr):
        final _ = inferExpr(env, level, expr);

      case LetDeclaration():
        env = inferLet(env, level, statement);

      case IfStatement(
        :final condition,
        :final thenBranch,
        :final elseBranch,
      ):
        final type = inferExpr(env, level, condition);
        unify(type, LoxType.bool);
        for (final statement in thenBranch) env = inferStatement(env, level, statement);
        for (final statement in elseBranch) env = inferStatement(env, level, statement);
    }

    return env;
  }

  Map<String, LoxType> inferLet(Map<String, LoxType> env, int level, LetDeclaration let) =>
    switch (let.pattern) {
      Identifier ident =>
          inferIdentifierPattern(env, level, ident, let.initializer),
      RecordDestructure pattern =>
          inferRecordPattern(env, level, pattern, let.initializer),
      TagPattern() =>
          throw TagPatternInIrrefutablePosition(),
    };

  Map<String, LoxType> inferRecordPattern(Map<String, LoxType> env, int level, RecordDestructure pattern, Expr record) {
    for (final field in pattern.elements) {
      final syntheticRecordGet = RecordGet(record, field.name);
      field.copyTypeOf(syntheticRecordGet);
      env = switch (field.pattern) {
        Identifier ident =>
            inferIdentifierPattern(env, level, ident, syntheticRecordGet),

        null =>
            inferAssignment(env, level, field.name, syntheticRecordGet),

        RecordDestructure nested =>
            inferRecordPattern(env, level, nested, syntheticRecordGet),

        TagPattern() =>
            throw TagPatternInIrrefutablePosition(),
      };
    }
    return env;
  }

  Map<String, LoxType> inferIdentifierPattern(Map<String, LoxType> env, int level, Identifier pattern, Expr subExpr) {
    env = inferAssignment(env, level, pattern.name, subExpr);
    pattern.copyTypeOf(subExpr);
    return env;
  }

  Map<String, LoxType> inferAssignment(Map<String, LoxType> env, int level, Token ident, Expr initializer) {
    final name = ident.lexeme;
    final nextLevel = level+1;
    final maybeRecursive = LoxType.fresh(nextLevel);
    final maybeRecursiveEnv = {
      ...env,
      // [initializer] might reference [name], so add it to the env with a
      // fresh type variable and let it get resolved normally
      name: maybeRecursive,
    };
    final type = inferExpr(maybeRecursiveEnv, nextLevel, initializer);

    // tie together the self reference (if any)
    unify(maybeRecursive, type);

    final generalizedType = LoxType(generalize(level, type));
    return {
      ...env,
      name: generalizedType,
    };
  }

  LoxType inferExpr(Map<String, LoxType> env, int level, Expr expr) {
    try {
      return switch (expr) {
        Print(:final expr) ||
        Assertion(:final expr) => inferExpr(env, level, expr),
        Literal()        => inferLiteral(env, level, expr),
        Variable()       => inferVariable(env, level, expr),
        Call()           => inferFunctionCall(env, level, expr),
        Lambda()         => inferFunction(env, level, expr),
        Return()         => inferReturn(env, level, expr),
        Grouping()       => inferExpr(env, level, expr.expr),
        Record()         => inferRecord(env, level, expr),
        RecordGet()      => inferRecordGet(env, level, expr),
        RecordUpdate()   => inferRecordUpdate(env, level, expr),
        ListLiteral()    => inferList(env, level, expr),
        TagConstructor() => inferTagConstructor(env, level, expr),
        TagMatch()       => inferTagMatch(env, level, expr),
        TagCastOk()      => inferTagCast(env, level, expr),
        IfExpression()   => inferIfExpression(env, level, expr),
        Import()         => inferImport(env, level, expr),
        UnaryMinus()     => inferUnaryOperation(env, level, expr),
        UnaryBang()      => inferUnaryOperation(env, level, expr),
        BlockExpr()      => inferBlockExpression(env, level, expr),
        Binary(operator: Token(type: .pipeline)) => inferPipeline(env, level, expr),
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
    }
    on TypeCheckException catch (e) {
      throw (expr, e);
    }
  }


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

  LoxType inferIfExpression(Map<String, LoxType> env, int level, IfExpression expr) {
    final evaluatesToType = LoxType.fresh(level);
    final expectedOperationType = LoxType.function(
      from: [
        inferExpr(env, level, expr.condition),
        inferExpr(env, level, expr.ifTrue),
        if (expr.ifFalse case final ifFalse?)
          inferExpr(env, level, ifFalse)
        else
          .unit,
      ],
      to: evaluatesToType,
    );

    final actualOperationType = inferExpr(env, level, Variable(expr.ifKeyword));

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
      final (pattern, initializer) = pair;
      return inferLet(moduleEnv, 0, LetDeclaration(expr.keyword, pattern, initializer));
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
    if (expr.cases case [..., TagMatchCase(pattern: Identifier ident, :final result)]) {
      final defaultType = LoxType.fresh(level);
      final defaultPatternType = LoxType.variant(defaultType);
      final resultEnv = {
        ...env,
        ident.name.lexeme: defaultPatternType,
      };
      expectedReturnType = inferExpr(resultEnv, level, result);
      casesRow = defaultType;
      ident.type = defaultPatternType;
    } else {
      expectedReturnType = .fresh(level);
      casesRow = .emptyRecord;
    }

    for (final (i, TagMatchCase(:pattern, arrow: _, :result)) in expr.cases.indexed) {
      switch (pattern) {
        case TagPattern(:final tag, :final payload):
          final resultEnv = {...env};
          final LoxType payloadType;
          switch (payload) {
            case null:
              payloadType = LoxType.unit;
            case Identifier(:final name):
              final type = LoxType.fresh(level);
              resultEnv[name.lexeme] = type;
              payloadType = type;
              payload.type = type;
            case RecordDestructure():
              payloadType = _recordPattern(payload, resultEnv, level);
            case TagPattern():
              throw MatchingNestedTagPatternsUnsupported();
          }
          final resultType = inferExpr(resultEnv, level, result);
          unify(expectedReturnType, resultType);
          casesRow = LoxType(TyRowExtend(
            newEntry: (tag.lexeme, payloadType),
            row: casesRow,
          ));
          pattern.type = .variant(LoxType(TyRowExtend(
            newEntry: (tag.lexeme, payloadType),
            row: LoxType.emptyRecord,
          )));
        case Identifier():
          final isLast = i == expr.cases.length - 1;
          if (!isLast) throw DefaultCaseMustBeLast();
        case RecordDestructure():
          throw NonTagPatternInMatch();
      }
    }

    final expectedVariantType = LoxType.variant(casesRow);
    final actualVariantType = inferExpr(env, level, expr.tag);
    unify(expectedVariantType, actualVariantType);
    return setType(expr, expectedReturnType);
  }

  LoxType _recordPattern(RecordDestructure pattern, Map<String, LoxType> payloadEnv, int level) {
    final fields = <String, LoxType>{};
    for (final element in pattern.elements) {
      final LoxType type;
      switch (element.pattern) {
        case null:
          type = .fresh(level);
          payloadEnv[element.name.lexeme] = type;
        case Identifier ident:
          type = .fresh(level);
          payloadEnv[ident.name.lexeme] = type;
          ident.type = type;
        case RecordDestructure pattern:
          type = _recordPattern(pattern, payloadEnv, level);
        case TagPattern():
          throw MatchingNestedTagPatternsUnsupported();
      }
      element.type = type;
      fields[element.name.lexeme] = type;
    }
    return .record(fields, tail: .fresh(level));
  }

  LoxType inferTagCast(Map<String, LoxType> env, int level, TagCastOk expr) {
    final token = (TokenType type, String lexeme) => Token(type, lexeme, null, 0, 0, 0);
    final match = TagMatch(
      token(.match, 'match'),
      expr.expr,
      (
        token(.openBrace, '{'),
        token(.closeBrace, '}'),
      ),
      [
        (
          pattern: TagPattern(token(.identifier, ('ok')), Identifier(token(.identifier, '#'))),
          arrow: token(.arrow, '->'),
          result: Variable(token(.identifier, '#')),
        ),
        (
          pattern: TagPattern(token(.identifier, ('err')), Identifier(token(.identifier, '#'))),
          arrow: token(.arrow, '->'),
          result: expr.fallback ?? Return(token(.return_, 'return'), TagConstructor(token(.identifier, 'err'), Variable(token(.identifier, '#')))),
        ),
      ],
    );
    final type = inferTagMatch(env, level, match);
    return setType(expr, type);
  }

  LoxType inferFunction(Map<String, LoxType> env, int level, Lambda function) =>
    switch (function.body) {
      ArrowExpression(:final body) => inferArrowFunction(env, level, function, body),
      FunctionBody(:final body)    => inferBlockFunction(env, level, function, body),
    };

  LoxType inferArrowFunction(Map<String, LoxType> env, int level, Lambda function, Expr body) {
    final (:parameterTypes, :parametersEnv) = setupFunctionParameters(function.params, level);
    final expectedReturnType = LoxType.fresh(level);
    onEnterFunctionBody(expectedReturnType: expectedReturnType);
    final actualReturnType = inferExpr({...env, ...parametersEnv}, level, body);
    unify(expectedReturnType, actualReturnType);
    onExitFunctionBody();
    final functionType = LoxType.function(
      from: parameterTypes,
      to: actualReturnType,
    );
    return setType(function, functionType);
  }

  LoxType inferBlockFunction(Map<String, LoxType> env, int level, Lambda function, List<Statement> body) {
    final (:parameterTypes, :parametersEnv) = setupFunctionParameters(function.params, level);

    env = {
      ...env,
      ...parametersEnv,
    };

    final returnType = LoxType.fresh(level);
    onEnterFunctionBody(expectedReturnType: returnType);
    for (final statement in body) {
      env = inferStatement(env, level, statement);
    }
    final anyReturnExpressions = _getCurrentFunction().anyReturnExpressions;
    onExitFunctionBody();

    final functionType = LoxType.function(
      from: parameterTypes,
      to: anyReturnExpressions ? returnType : .unit,
    );
    return setType(function, functionType);
  }

  /// Returns:
  ///     parameterTypes: the types of the function's parameters
  ///     parametersEnv: variables available to the function body
  ///
  /// For example given the function
  ///     let fn = \a, {b: c, z} -> a + c + (z ? 1 : 2);
  /// parameterTypes:
  ///     - #0: Num
  ///     - #1: {b: Num, z: Bool}
  /// parametersEnv:
  ///     - a: Num
  ///     - c: Num
  ///     - z: Bool
  ({
    List<LoxType> parameterTypes,       // the function has parameters of these types
    Map<String, LoxType> parametersEnv, // variables of these types are available to the function body
  }) setupFunctionParameters(List<Pattern> params, int level) {
    if (params.isEmpty) {
      final nop = LoxType.fresh(level);
      return (
        parameterTypes: [nop],
        parametersEnv: { '_' : nop },
      );
    }

    final result = (
      parameterTypes: <LoxType>[],
      parametersEnv: <String, LoxType>{},
    );

    LoxType destructure(RecordDestructure pattern) {
      final fields = <String, LoxType>{};
      for (final element in pattern.elements) {
        final LoxType type;
        switch (element.pattern) {
          case null:
            type = .fresh(level);
            result.parametersEnv[element.name.lexeme] = type;
          case Identifier ident:
            type = .fresh(level);
            result.parametersEnv[ident.name.lexeme] = type;
            ident.type = type;
          case RecordDestructure pattern:
            type = destructure(pattern);
          case TagPattern():
            throw TagPatternInIrrefutablePosition();
        }
        element.type = type;
        fields[element.name.lexeme] = type;
      }
      return .record(fields, tail: .fresh(level));
    }

    for (final param in params) {
      switch (param) {
        case Identifier(:final name):
          final type = LoxType.fresh(level);
          result.parametersEnv[name.lexeme] = type;
          result.parameterTypes.add(type);
          param.type = type;
        case RecordDestructure():
          result.parameterTypes.add(destructure(param));
        case TagPattern():
            throw TagPatternInIrrefutablePosition();
      }
    }

    return result;
  }

  LoxType inferReturn(Map<String, LoxType> env, int level, Return expr) {
    final returnType = switch (expr) {
      Return(:final expr?) => inferExpr(env, level, expr),
      Return() => LoxType.unit,
    };
    final current = _getCurrentFunction();
    current.anyReturnExpressions = true;
    unify(current.expectedReturnType, returnType);
    return setType(expr, .fresh(level));
  }

  void onEnterFunctionBody({required LoxType expectedReturnType}) {
    _returnStack.add(.new(
      expectedReturnType,
      anyReturnExpressions: false,
    ));
  }

  void onExitFunctionBody() {
    _returnStack.removeLast();
  }

  _CurrentFunction _getCurrentFunction() =>
    switch (_returnStack) {
      [] => throw TopLevelReturn(),
      [..., final last] => last,
    };

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
        [Identifier(args.placeholder)],
        ArrowExpression(
          Token(
            .arrow,
            '->',
            null,
            args.placeholder.line,
            args.placeholder.offset,
            args.placeholder.absoluteOffset,
          ),
          functionBody,
        ),
    );
    final type = inferArrowFunction(env, level, function, functionBody);
    return setType(call, type);
  }

  LoxType inferBlockExpression(Map<String, LoxType> env, int level, BlockExpr expr) {
    env = {...env};
    for (final statement in expr.statements.skipLast()) {
      env = inferStatement(env, level, statement);
    }
    final type = switch (expr.statements.last) {
      ExpressionStatement(:final expr) => inferExpr(env, level, expr),
      IfStatement() ||
      LetDeclaration() =>
        throw BlockMustEndWithExpr(),
    };
    return setType(expr, type);
  }

}

class _CurrentFunction {
  final LoxType expectedReturnType;
  bool anyReturnExpressions;
  _CurrentFunction(
    this.expectedReturnType, {
    required this.anyReturnExpressions
  });
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

  static final record = (Map<String, LoxType> fields, {LoxType? tail}) => LoxType(
    fields.fold(
      tail ?? emptyRecord,
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
  'if': .function(from: [.bool, a, a], to: a),
  'List' : .record({
    'first': .function(from: [.list(of: a)], to: a),
    'rest': .function(from: [.list(of: b)], to: .list(of: b)),
    'empty': .function(from: [.list(of: c)], to: .bool),
  }),
  'String' : .record({
    'concat': .function(from: [.string, .string], to: .string),
    'split': .function(from: [.string, .string], to: .list(of: .string)),
  }),
  'clock': .function(from: [a], to: .num),
};

void normalizeProgramTypeVariableIds(List<Statement> statements) {
  // normalize per top-level statement?
  for (final statement in statements) {
    final allTypeVariables = <int>{};

    for (final pat in statement.allPatterns()) {
      switch (pat) {
        case Identifier():
          if (pat.type case final type?) {
            allTypeVariables.addAll(collectTypeVariables(allTypeVariables, type));
          }
        case RecordDestructure(:final elements):
          for (final e in elements) {
            if (e.type case final type?) {
              allTypeVariables.addAll(collectTypeVariables(allTypeVariables, type));
            }
          }
        case TagPattern():
          if (pat.type case final type?) {
            allTypeVariables.addAll(collectTypeVariables(allTypeVariables, type));
          }
      }
    }

    for (final expr in statement.allExpressions()) {
      if (expr.type case final type?) {
        allTypeVariables.addAll(collectTypeVariables(allTypeVariables, type));
      }
    }


    final namesSorted = allTypeVariables.toList();
    int lookup(int name) =>
      namesSorted.contains(name)
        ? namesSorted.indexOf(name)
        : name;

    for (final expr in statement.allExpressions()) {
      if (expr.type case final type?) {
        expr.type = LoxType(rename(type, lookup));
      }
    }
    for (final pat in statement.allPatterns()) {
      switch (pat) {
        case Identifier():
          if (pat.type case final type?) {
            pat.type = LoxType(rename(type, lookup));
          }
        case RecordDestructure(:final elements):
          for (final e in elements) {
            if (e.type case final type?) {
              e.type = LoxType(rename(type, lookup));
            }
          }
        case TagPattern():
          if (pat.type case final type?) {
            pat.type = LoxType(rename(type, lookup));
          }
      }
    }
  }
}