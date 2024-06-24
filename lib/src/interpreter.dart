
import 'package:lox/src/env.dart';
import 'package:lox/src/expr.dart';
import 'package:lox/src/lox_base.dart';
import 'package:lox/src/utils.dart';

class LoxRuntimeException implements Exception {
  final Token token;
  final String message;
  LoxRuntimeException(this.token, this.message);
}
class Return {
  final Object? returnValue;
  Return(this.returnValue);
}

Env interpret(List<Statement> statements, Env env) {
  try {
    for (final s in statements) {
      env = execute(s, env);
    }
  } on LoxRuntimeException catch (e) {
    print('Error while evaluating ${e.token} on line ${e.token.line}');
    print(e.message);
    hadRuntimeError = true;
  }
  return env;
}

Env execute(Statement statement, Env env) {
  switch (statement) {
    case PrintStatement(:final expr):
      print(eval(expr, env));
    case ExpressionStatement(:final expr):
      eval(expr, env);
    case VariableDeclaration(:final name, :final initializer):
      env = env.defining(name, initializer == null ? null : eval(initializer, env));
    case FunctionDeclaration(:final name, :final params, :final body):
      env = env.defining(name, (
        arity: params.length,
        impl: (List<Object?> args) {
          var newEnv = Env(env, {
            for (final (param, arg) in params.zipWith(args, makePair))
              param.lexeme: arg,
          });
          try {
            for (final statement in body) {
              newEnv = execute(statement, newEnv);
            }
          } on Return catch (r) {
            return r.returnValue;
          }
          return null; // void
        },
      ));
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
      TokenType.EQUAL_EQUAL   => eval(left, env) == eval(right, env),
      TokenType.BANG_EQUAL    => eval(left, env) != eval(right, env),
      final type => throw StateError('bug: unhandled binary operator $type'),
    },
    Variable(:final name) => env[name],
    Call(:final callee, :final args, :final closingParen) => handleInvocation(callee, args, closingParen, env),
    LogicalAnd(:final left, :final keyword, :final right) => evalAs<bool>(left, keyword, env) && evalAs<bool>(right, keyword, env),
    LogicalOr(:final left, :final keyword, :final right) => evalAs<bool>(left, keyword, env) || evalAs<bool>(right, keyword, env),
  };
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
  List<Expr> args,
  Token closingParen,
  Env env,
) {
  final (:arity, :impl) = evalAs<LoxFunction>(callee, closingParen, env);
  if (args.length != arity) {
    throw LoxRuntimeException(closingParen, 'Expected $arity arguments but got ${args.length}');
  }
  final evaluatedArgs = [ for (final arg in args) eval(arg, env) ];
  return impl(evaluatedArgs);
}

typedef LoxFunction = ({
  int arity,
  Object? Function(List<Object?> args) impl,
});
