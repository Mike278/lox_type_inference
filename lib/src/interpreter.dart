
import 'package:lox/src/expr.dart';
import 'package:lox/src/lox_base.dart';

class LoxRuntimeException implements Exception {
  final Expr expr; // todo line number etc
  final String message;
  LoxRuntimeException(this.expr, this.message);
}

class Interpreter {

  void interpret(Expr expr) {
    try {
      final value = eval(expr);
      print(value);
    } on LoxRuntimeException catch (e) {
      print('Error while evaluating ${display(e.expr)}');
      print(e.message);
      hadRuntimeError = true;
    }
  }

  Object? eval(Expr expr) {
    try {
      return switch (expr) {
        Literal(:final value) => value,
        Grouping(:final expr) => eval(expr),
        UnaryBang(:final expr) => !(eval(expr) as bool),
        UnaryMinus(:final expr) => -(eval(expr) as num),
        Binary(:final left, :final operator, :final right) => switch (operator.type) {
          TokenType.MINUS => evalAs<num>(left) - evalAs<num>(right),
          TokenType.PLUS => evalAs<num>(left) + evalAs<num>(right),
          TokenType.SLASH => evalAs<num>(left) / evalAs<num>(right),
          TokenType.STAR => evalAs<num>(left) * evalAs<num>(right),
          TokenType.GREATER => evalAs<num>(left) > evalAs<num>(right),
          TokenType.GREATER_EQUAL => evalAs<num>(left) >= evalAs<num>(right),
          TokenType.LESS => evalAs<num>(left) < evalAs<num>(right),
          TokenType.LESS_EQUAL => evalAs<num>(left) <= evalAs<num>(right),
          TokenType.EQUAL_EQUAL => eval(left) == eval(right),
          TokenType.BANG_EQUAL => eval(left) != eval(right),
          final type => throw StateError('bug: unhandled binary operator $type'),
        },
      };
    }
    on LoxRuntimeException { rethrow; }
    catch (e) {
      throw LoxRuntimeException(expr, '$e');
    }
  }

  T evalAs<T extends Object>(Expr expr) => eval(expr) as T;
}