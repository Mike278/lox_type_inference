
import 'package:lox/src/env.dart';
import 'package:lox/src/expr.dart';
import 'package:lox/src/lox_base.dart';
import 'package:lox/src/utils.dart';

class LoxRuntimeException implements Exception {
  final Token token;
  final String message;
  LoxRuntimeException(this.token, this.message);
}

class Interpreter {

  final Env env;
  Interpreter(this.env);

  void interpret(List<Statement> statements) {
    try {
      for (final s in statements) {
        execute(s);
      }
    } on LoxRuntimeException catch (e) {
      print('Error while evaluating ${e.token} on line ${e.token.line}');
      print(e.message);
      hadRuntimeError = true;
    }
  }

  void execute(Statement statement) {
    switch (statement) {
      case PrintStatement(:final expr):
        print(eval(expr));
      case ExpressionStatement(:final expr):
        eval(expr);
      case VariableDeclaration(:final name, :final initializer):
        env[name] = initializer?.run(eval);
    }
  }

  Object? eval(Expr expr) {
    return switch (expr) {
      Literal(:final value) => value,
      Grouping(:final expr) => eval(expr),
      UnaryBang(:final expr, :final operator) => !evalAs<bool>(expr, operator),
      UnaryMinus(:final expr, :final operator) => -evalAs<num>(expr, operator),
      Binary(:final left, :final operator, :final right) => switch (operator.type) {
        TokenType.MINUS         => evalAs<num>(left, operator) - evalAs<num>(right, operator),
        TokenType.PLUS          => evalAs<num>(left, operator) + evalAs<num>(right, operator),
        TokenType.SLASH         => evalAs<num>(left, operator) / evalAs<num>(right, operator),
        TokenType.STAR          => evalAs<num>(left, operator) * evalAs<num>(right, operator),
        TokenType.GREATER       => evalAs<num>(left, operator) > evalAs<num>(right, operator),
        TokenType.GREATER_EQUAL => evalAs<num>(left, operator) >= evalAs<num>(right, operator),
        TokenType.LESS          => evalAs<num>(left, operator) < evalAs<num>(right, operator),
        TokenType.LESS_EQUAL    => evalAs<num>(left, operator) <= evalAs<num>(right, operator),
        TokenType.EQUAL_EQUAL   => eval(left) == eval(right),
        TokenType.BANG_EQUAL    => eval(left) != eval(right),
        final type => throw StateError('bug: unhandled binary operator $type'),
      },
      Variable(:final name) => env[name],
    };
  }

  T evalAs<T extends Object>(Expr expr, Token errorOnToken) {
    try {
      return eval(expr) as T;
    }
    on LoxRuntimeException { rethrow; }
    catch (e) {
      throw LoxRuntimeException(errorOnToken, '$e');
    }
  }
}