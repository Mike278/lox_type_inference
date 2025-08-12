
import 'package:collection/collection.dart';
import 'package:lox/expr.dart';
import 'package:lox/token.dart';
import 'package:lox/utils.dart';

class LoxRuntimeException implements Exception {
  final Token token;
  final String message;
  LoxRuntimeException(this.token, this.message);

  @override
  String toString() {
    return 'LoxRuntimeException{token: $token, message: $message}';
  }

}
class _Return {
  final Object? returnValue;
  _Return(this.returnValue);
}

typedef LoxFunction = ({
  int arity,
  Object? Function(List<Object?> args) impl,
});
typedef LoxRecord = Map<String, Object?>;

class LoxTag {
  final Token tag;
  final Object? payload;
  LoxTag({required this.tag, required this.payload});

  @override
  String toString() => switch (payload) {
    final payload? => '.${tag.lexeme}($payload)',
    _ => '.${tag.lexeme}',
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is LoxTag && runtimeType == other.runtimeType &&
              tag == other.tag && payload == other.payload;

  @override
  int get hashCode => tag.hashCode ^ payload.hashCode;
}

typedef RuntimeIO = ({
  void Function(Object?) print,
});

typedef LoxAssertion = void Function(Token keyword, String source, Object?);

void defaultLoxAssert(Token keyword, String source, Object? value) {
  switch (value) {
    case true: return;
    case false: throw LoxRuntimeException(keyword, 'Assertion failed: $source');
    default: throw LoxRuntimeException(
      keyword,
      'Assertion failed: value is not a bool. `$source` evaluates to a `${value.runtimeType}`'
    );
  }
}

class LoxRuntime {
  
  final LoxAssertion runAssert;
  final RuntimeIO io;
  final ResolveImport import;

  LoxRuntime(this.runAssert, this.io, this.import);
  
  Env interpret(List<Statement> statements, Env env) =>
    statements.fold(env, execute);
  
  Env execute(Env env, Statement statement) {
    switch (statement) {
      case PrintStatement(:final expr):
        io.print(eval(expr, env));
      case AssertStatement(:final keyword, :final source, :final expr):
        runAssert(keyword, source, eval(expr, env));
      case ExpressionStatement(:final expr):
        eval(expr, env);
      case LetDeclaration(:final pattern, :final initializer):
        return handleAssignment(env, pattern, initializer);
      case Block(:final statements):
        var newEnv = Env(env);
        for (final statement in statements) {
          newEnv = execute(newEnv, statement);
        }
      case IfStatement(:final keyword, :final condition, :final thenBranch, :final elseBranch):
        final result = evalAs<bool>(condition, keyword, env);
        if (result) {
          env = execute(env, thenBranch);
        } else {
          if (elseBranch != null) {
            env = execute(env, elseBranch);
          }
        }
    }
    return env;
  }

  Object? eval(Expr expr, Env env) {
    return switch (expr) {
      Return(:final expr) =>
        throw _Return(expr == null ? null : eval(expr, env)),
      Literal(:final value) => value,
      ListLiteral(elements:final values) => [
        for (final x in values) ...switch (x) {
          ExpressionListElement(:final expr) => [eval(expr, env)],
          SpreadListElement(:final expr, :final dotdot) => evalAs<List<Object?>>(expr, dotdot, env),
        },
      ],
      Grouping(:final expr) => eval(expr, env),
      UnaryBang(:final expr, :final operator) => !evalAs<bool>(expr, operator, env),
      UnaryMinus(:final expr, :final operator) => -evalAs<num>(expr, operator, env),
      Binary(:final left, :final operator, :final right) => switch (operator.type) {
        .minus         => evalAs<num>(left, operator, env) - evalAs<num>(right, operator, env),
        .plus          => evalAs<num>(left, operator, env) + evalAs<num>(right, operator, env),
        .slash         => evalAs<num>(left, operator, env) / evalAs<num>(right, operator, env),
        .star          => evalAs<num>(left, operator, env) * evalAs<num>(right, operator, env),
        .greater       => evalAs<num>(left, operator, env) > evalAs<num>(right, operator, env),
        .greaterEqual  => evalAs<num>(left, operator, env) >= evalAs<num>(right, operator, env),
        .less          => evalAs<num>(left, operator, env) < evalAs<num>(right, operator, env),
        .lessEqual     => evalAs<num>(left, operator, env) <= evalAs<num>(right, operator, env),
        .equalEqual    => DeepCollectionEquality().equals(eval(left, env), eval(right, env)),
        .bangEqual     => eval(left, env) != eval(right, env),
        .pipeline      => handleInvocation(right, ExpressionArgs([left]), operator, env),
        final type => throw StateError('bug: unhandled binary operator $type'),
      },
      Variable(:final name) => env[name],
      Call(:final callee, :final args, :final closingParen) => handleInvocation(callee, args, closingParen, env),
      LogicalAnd(:final left, :final keyword, :final right) => evalAs<bool>(left, keyword, env) && evalAs<bool>(right, keyword, env),
      LogicalOr(:final left, :final keyword, :final right) => evalAs<bool>(left, keyword, env) || evalAs<bool>(right, keyword, env),
      Ternary(:final questionMark, :final condition, :final ifTrue, :final ifFalse) =>
        evalAs<bool>(condition, questionMark, env)
          ? eval(ifTrue, env)
          : eval(ifFalse, env),
      Record(:final fields) => {
        for (final (field, expr) in fields.pairs())
          field.lexeme: eval(expr, env),
      },
      RecordGet(:final record, :final name) =>
        accessRecordField(evalAs(record, name, env), name, env),
      RecordUpdate(:final dotdot, :final record, :final newFields) => {
        ...evalAs<LoxRecord>(record, dotdot, env),
        for (final (label, value) in newFields.pairs())
          label.lexeme: eval(value, env),
      },
      Lambda(:final params, :final body) => newLoxFunction(() => env, params, body),
      TagConstructor(:final tag, :final payload?) => LoxTag(tag: tag, payload: eval(payload, env)),
      TagConstructor(:final tag, payload: null) => LoxTag(tag: tag, payload: null),
      TagMatch() => evalMatch(expr, env),
      Import(:final keyword, :final path) => instantiateImport(keyword, path),
    };
  }

  Object? accessRecordField(LoxRecord record, Token name, Env env) {
    if (record.containsKey(name.lexeme)) {
      return record[name.lexeme];
    }
    throw LoxRuntimeException(name, "Record doesn't have a field named ${name.lexeme}");
  }

  Object? evalMatch(
    final TagMatch match,
    final Env env,
  ) {
    final TagMatch(
      :keyword,
      tag: target,
      :cases,
      :defaultCase,
      braces: (_, closingBrace),
    ) = match;
    final LoxTag actual = evalAs(target, keyword, env);
    for (final TagMatchCase(:tag, :payload, :result) in cases) {
      if (tag.lexeme == actual.tag.lexeme) {
        if (payload != null) {
          return eval(result, env.defining(payload, actual.payload));
        }
        return eval(result, env);
      }
    }
    if (defaultCase case DefaultMatchCase(:final variable, :final result)?) {
      return eval(result, env.defining(variable, actual));
    }
    throw LoxRuntimeException(closingBrace, 'No match was found');
  }
  
  T evalAs<T extends Object>(Expr expr, Token errorOnToken, Env env) {
    try {
      return eval(expr, env) as T;
    }
    on LoxRuntimeException { rethrow; }
    catch (e) {
      throw LoxRuntimeException(errorOnToken, '$e');
    }
  }

  Env define(Env env, Token name, Expr initializer) {
    if (initializer case Lambda(:final body, :final params)) {
      late final Env lazyEnv;
      lazyEnv = env.defining(name, newLoxFunction(() => lazyEnv, params, body));
      return lazyEnv;
    }
    return env.defining(name, eval(initializer, env));
  }

  Env handleAssignment(Env env, Pattern pattern, Expr initializer) =>
    switch (pattern) {
      Identifier(:final name) =>
        define(env, name, initializer),

      RecordDestructure(:final openBrace) =>
        destructureRecord(
          pattern,
          evalAs(initializer, openBrace, env),
          env,
        ),
    };

  Env destructureRecord(RecordDestructure pattern, LoxRecord record, Env env) {
    for (final field in pattern.elements) {
      final fieldValue = accessRecordField(record, field.name, env);
      env = switch (field.pattern) {
        null => env.defining(field.name, fieldValue),

        Identifier(name: final newName) =>
          env.defining(newName, fieldValue),

        RecordDestructure nested =>
          destructureRecord(nested, fieldValue as LoxRecord, env),
      };
    }
    return env;
  }

  Object? handleInvocation(
    Expr callee,
    CallArgs args,
    Token closingParen,
    Env env,
  ) {
    final (:arity, :impl) = evalAs<LoxFunction>(callee, closingParen, env);
    final argCount = switch (args) {
      ArgsWithPlaceholder(:final before, :final after) =>
          before.length + after.length + 1, // +1 for placeholder
  
      ExpressionArgs(:final exprs) =>
          exprs.length,
    };
    if (argCount != arity) {
      throw LoxRuntimeException(closingParen, 'Expected $arity arguments but got $argCount');
    }

    try {
      return switch (args) {
        ExpressionArgs(:final exprs) =>
            impl([ for (final arg in exprs) eval(arg, env) ]),
        ArgsWithPlaceholder(:final before, :final after) => (
            arity: 1,
            impl: (args) => impl([
              for (final arg in before) eval(arg, env),
              ...args,
              for (final arg in after) eval(arg, env),
            ]),
          ),
      };
    } on _ExceptionFromBuiltin catch (e) {
      throw LoxRuntimeException(closingParen, e.message);
    }
  }
  
  LoxFunction newLoxFunction(
    Env Function() getEnv,
    List<Pattern> params,
    LambdaBody body,
  ) =>
    (
      arity: params.length,
      impl: (List<Object?> args) {
        final enclosing = getEnv();
        final instantiatedParameters = {
          for (final (param, arg) in params.zipWith(args, makePair))
            ...switch (param) {
              Identifier(:final name) =>
                { name.lexeme: arg },
              RecordDestructure pattern =>
                destructureRecord(pattern, arg, enclosing).state,
            }
        };
        final newEnv = Env(enclosing, instantiatedParameters);
        try {
          switch (body) {
            case ArrowExpression(:final body):
              return eval(body, newEnv);
            case FunctionBody(body: Block(:final statements)):
              final _ = interpret(statements, newEnv);
          }
        } on _Return catch (r) {
          return r.returnValue;
        }
        return null; // void
      },
    );

  LoxRecord instantiateImport(Token importKeyword, ImportPath path) {
    final Exports exports;
    try {
      exports = import(path);
    } catch (e) {
      throw LoxRuntimeException(importKeyword, "Failed to import from $path: $e");
    }

    final module = exports.pairs().fold(Env.global(), (moduleEnv, pair) {
      final (pattern, initializer) = pair;
      return handleAssignment(moduleEnv, pattern, initializer);
    });

    return {
      for (final (name, value) in module.state.pairs())
        if (!builtins.containsKey(name)) // Don't export globals
          name: value,
    };
  }
}

final builtins = UnmodifiableMapView({
  'clock': clock,
  'List': {
    'first': first,
    'rest': rest,
    'empty': empty,
  },
  'String': {
    'concat': concat,
  },
});

class _ExceptionFromBuiltin implements Exception {
  final String message;
  _ExceptionFromBuiltin(this.message);
}

final LoxFunction clock = (
  arity: 0,
  impl: (args) => DateTime.now().millisecondsSinceEpoch / 1000,
);
final LoxFunction first = (
  arity: 1,
  impl: (args) => switch (args.single as List) {
    [final x, ...] => x,
    [] => throw _ExceptionFromBuiltin('List is empty'),
  },
);
final LoxFunction rest = (
  arity: 1,
  impl: (args) => switch (args.single as List) {
    [final _, ...final rest] => rest,
    [] => [],
  },
);
final LoxFunction empty = (
  arity: 1,
  impl: (args) => (args.single as List).isEmpty,
);
final LoxFunction concat = (
  arity: 2,
  impl: (args) => args.join(),
);



class Env {
  final UnmodifiableMapView<String, Object?> state;
  final Env? _enclosing;
  Env.global() : state = builtins, _enclosing = null;
  Env(this._enclosing, [Map<String, Object?>? values]) : state = UnmodifiableMapView({...?values});

  Env defining(Token name, Object? value) {
    final key = name.lexeme;
    if (state.containsKey(key)) {
      throw LoxRuntimeException(name, "The name '${name.lexeme}' is already defined.");
    }
    return Env(_enclosing, {
      ...state,
      key: value,
    });
  }

  Object? operator[](Token name) {
    final key = name.lexeme;
    if (state.containsKey(key)) {
      return state[key];
    }
    if (_enclosing case final env?) {
      return env[name];
    }
    return throw LoxRuntimeException(name, "Undefined variable '${name.lexeme}'.");
  }
}