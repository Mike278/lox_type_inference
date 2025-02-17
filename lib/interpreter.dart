
import 'package:collection/collection.dart';
import 'package:lox/env.dart';
import 'package:lox/expr.dart';
import 'package:lox/scanner.dart';
import 'package:lox/utils.dart';

class LoxRuntimeException implements Exception {
  final Token? token;
  final String message;
  LoxRuntimeException(this.token, this.message);
}
class Return {
  final Object? returnValue;
  Return(this.returnValue);
}

typedef LoxFunction = ({
  int arity,
  Object? Function(List<Object?> args) impl,
});

typedef LoxTag = ({
  Token tag,
  Object? payload,
});

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
  
  final ErrorReporter reportError;
  final LoxAssertion runAssert;
  final RuntimeIO io;

  LoxRuntime(this.reportError, this.runAssert, this.io);
  
  
  (Env, {bool hadRuntimeError}) interpret(List<Statement> statements, Env env) {
    var hadRuntimeError = false;
    try {
      for (final s in statements) {
        env = execute(s, env);
      }
    } on LoxRuntimeException catch (e) {
      if (e.token case final token?) {
        reportError(formatError(token.line, token.offset, ' at $token', e.message));
      }
      hadRuntimeError = true;
    }
    return (env, hadRuntimeError: hadRuntimeError);
  }
  
  Env execute(Statement statement, Env env) {
    switch (statement) {
      case PrintStatement(:final expr):
        io.print(eval(expr, env));
      case AssertStatement(:final keyword, :final source, :final expr):
        runAssert(keyword, source, eval(expr, env));
      case ExpressionStatement(:final expr):
        eval(expr, env);
      case LetDeclaration(:final name, :final initializer):
        if (initializer case Lambda(:final body, :final params)) {
          late final Env lazyEnv;
        lazyEnv = env.defining(name, newLoxFunction(() => lazyEnv, params, body));
          return lazyEnv;
        }
        return env.defining(name, eval(initializer, env));
      case Block(:final statements):
        var newEnv = Env(env);
        for (final statement in statements) {
          newEnv = execute(statement, newEnv);
        }
      case ReturnStatement(:final expr):
        throw Return(expr == null ? null : eval(expr, env));
      case IfStatement(:final keyword, :final condition, :final thenBranch, :final elseBranch):
        final result = evalAs<bool>(condition, keyword, env);
        if (result) {
          env = execute(thenBranch, env);
        } else {
          if (elseBranch != null) {
            env = execute(elseBranch, env);
          }
        }
    }
    return env;
  }

  Object? eval(Expr expr, Env env) {
    return switch (expr) {
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
        TokenType.MINUS         => evalAs<num>(left, operator, env) - evalAs<num>(right, operator, env),
        TokenType.PLUS          => evalAs<num>(left, operator, env) + evalAs<num>(right, operator, env),
        TokenType.SLASH         => evalAs<num>(left, operator, env) / evalAs<num>(right, operator, env),
        TokenType.STAR          => evalAs<num>(left, operator, env) * evalAs<num>(right, operator, env),
        TokenType.GREATER       => evalAs<num>(left, operator, env) > evalAs<num>(right, operator, env),
        TokenType.GREATER_EQUAL => evalAs<num>(left, operator, env) >= evalAs<num>(right, operator, env),
        TokenType.LESS          => evalAs<num>(left, operator, env) < evalAs<num>(right, operator, env),
        TokenType.LESS_EQUAL    => evalAs<num>(left, operator, env) <= evalAs<num>(right, operator, env),
        TokenType.EQUAL_EQUAL   => DeepCollectionEquality().equals(eval(left, env), eval(right, env)),
        TokenType.BANG_EQUAL    => eval(left, env) != eval(right, env),
        TokenType.PIPELINE      => handleInvocation(right, ExpressionArgs([left]), operator, env),
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
        switch (evalAs<Map<String, Object?>>(record, name, env)) {
          final map when map.containsKey(name.lexeme) => map[name.lexeme],
          _ => throw LoxRuntimeException(name, "Record doesn't have a field named ${name.lexeme}")
        },
      RecordUpdate(:final dotdot, :final record, :final newFields) => {
        ...evalAs<Map<String, Object?>>(record, dotdot, env),
        for (final (label, value) in newFields.pairs())
          label.lexeme: eval(value, env),
      },
      Lambda(:final params, :final body) => newLoxFunction(() => env, params, body),
      TagConstructor(:final tag, :final payload?) => (tag: tag, payload: eval(payload, env)),
      TagConstructor(:final tag, payload: null) => (tag: tag, payload: null),
      TagMatch() => evalMatch(expr, env),
    };
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
  }
  
  LoxFunction newLoxFunction(
    Env Function() getEnv,
    List<Token> params,
    LambdaBody body,
  ) =>
    (
      arity: params.length,
      impl: (List<Object?> args) {
        var newEnv = Env(getEnv(), {
          for (final (param, arg) in params.zipWith(args, makePair))
            param.lexeme: arg,
        });
        try {
          switch (body) {
            case ArrowExpression(:final body):
              return eval(body, newEnv);
            case FunctionBody(body: Block(:final statements)):
              for (final statement in statements) {
                newEnv = execute(statement, newEnv);
              }
          }
        } on Return catch (r) {
          return r.returnValue;
        }
        return null; // void
      },
    );
}